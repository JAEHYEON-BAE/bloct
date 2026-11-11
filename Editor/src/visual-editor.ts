import {randomID} from './id.ts';
import {EditorView, Decoration, DecorationSet, type NodeView} from '@tiptap/pm/view';
import {Plugin, Selection, TextSelection, NodeSelection, type Command, type EditorState, type Transaction} from '@tiptap/pm/state';
import {InputRule, inputRules, undoInputRule} from '@tiptap/pm/inputrules';
import {keymap} from '@tiptap/pm/keymap';
import {baseKeymap, chainCommands, exitCode, joinTextblockBackward, joinTextblockForward, lift, liftEmptyBlock, newlineInCode, setBlockType, splitBlock, toggleMark, wrapIn} from '@tiptap/pm/commands';
import {wrapInList, splitListItem, sinkListItem, liftListItem} from '@tiptap/pm/schema-list';
import {undo, redo, closeHistory} from '@tiptap/pm/history';
import {Fragment, Slice, type Node as PMNode} from '@tiptap/pm/model';
import katex from 'katex';
import {BlockSession} from './session.ts';
import {schema} from './schema.ts';
import {imageBlockMarkdown} from './serializer.ts';

export interface VisualOptions {
  savedMarkdown?: string;
  // The app enables one input line at EOF without changing the saved source.
  trailingParagraph?: boolean;
  onChange?: (dirty: boolean) => void;
  imageURL?: (source: string) => string | null;
  // The native host supplies the same sanitized renderer used before Aa.
  renderPreview?: (markdown: string) => string;
}

export const formats = [
  ['paragraph','Text'], ...[1,2,3,4,5,6].map(n => [`heading_${n}`, `Header ${n}`]),
  ['blockquote','Quote'], ['bullet_list','Bulleted list'], ['ordered_list','Numbered list'],
  ['task_list','To-do list'], ['code_block','Code'], ['horizontal_rule','Divider'],
  ['equation','Equation'], ['image_block','Image'], ['table','Table'],
];

// Inverting a structural rule can map the selection into the following block.
// The input-rules record retains the source insertion position before wrapping.
const undoTypingRule: Command = (state, dispatch) => {
  for (const plugin of state.plugins) {
    if (!(plugin.spec as {isInputRules?: boolean}).isInputRules) continue;
    const record = plugin.getState(state) as {from:number;text:string}|null;
    if (!record) continue;
    return undoInputRule(state, dispatch && (tr => {
      tr.setSelection(TextSelection.create(tr.doc, record.from + record.text.length));
      dispatch(tr.scrollIntoView());
    }));
  }
  return false;
};

// A plain Text block joins the preceding sentence, rather than becoming a new
// paragraph/item inside its quote/list. Both keys remove the same boundary.
const joinTextBoundary = (backward:boolean): Command => (state,dispatch) => {
  const {$from,empty}=state.selection;
  if(!empty)return false;
  const containers=['blockquote','bullet_list','ordered_list','list_item'];
  const textTypes=['paragraph','heading'];
  let previous:PMNode|null;
  if(backward) {
    if($from.depth!==1 || $from.parent.type!==schema.nodes.paragraph || $from.parentOffset!==0)return false;
    previous=state.doc.resolve($from.before()).nodeBefore;
  } else {
    if(!textTypes.includes($from.parent.type.name) || $from.parentOffset!==$from.parent.content.size)return false;
    // The cursor must be at the end of the entire preceding container, including
    // any nested list. Do not skip another item or a protected/isolating node.
    for(let depth=1;depth<$from.depth;depth++) {
      if(!containers.includes($from.node(depth).type.name)
          || $from.index(depth)!==$from.node(depth).childCount-1)return false;
    }
    if(state.doc.resolve($from.after(1)).nodeAfter?.type!==schema.nodes.paragraph)return false;
    previous=$from.node(1);
  }
  while(previous && !previous.isTextblock) {
    if(!containers.includes(previous.type.name))return false;
    previous=previous.lastChild;
  }
  if(!previous || !textTypes.includes(previous.type.name))return false;
  return (backward ? joinTextblockBackward : joinTextblockForward)(state,dispatch && (tr=>
    dispatch(closeHistory(tr).setStoredMarks(null).scrollIntoView())));
};

// Pending display math stays ordinary text until a nonempty pair is closed.
// Enter may have split its lines into adjacent paragraphs; never cross another
// block type, inline atom or formatting mark while collecting those lines.
function displayDraft(doc:PMNode, pos:number, closing=false) {
  const $pos=doc.resolve(pos);
  if($pos.depth!==1 || $pos.parent.type!==schema.nodes.paragraph)return null;
  const lines:string[]=[];
  let from=$pos.before();
  for(let index=$pos.index(0);index>=0;index--) {
    const node=doc.child(index);let plain=true;
    node.forEach(child=>{if(child.marks.length || !['text','soft_break','hard_break'].includes(child.type.name))plain=false;});
    if(node.type!==schema.nodes.paragraph || !plain)break;
    lines.unshift(node.textBetween(0,node.content.size,'\n','\n'));
    if(/^\$\$(?!\$)/.test(lines[0]) && !(closing && lines.length===1 && /^\$\$[ \t]*$/.test(lines[0])))
      return {from,to:$pos.after(),raw:lines.join('\n')};
    if(index)from-=doc.child(index-1).nodeSize;
  }
  return null;
}
function escapedDollar(state:EditorState,pos:number) {
  const $pos=state.doc.resolve(pos);
  const before=$pos.parent.textBetween(0,$pos.parentOffset);
  return ((/\\+$/.exec(before)?.[0].length ?? 0)%2)===1;
}

function rules(): InputRule[] {
  const blockRule = (pattern: RegExp, kind: string, attributes: (m: RegExpMatchArray) => object = () => ({})) =>
    new InputRule(pattern, (state, match, start, end) => {
      const $from = state.doc.resolve(start);
      if ($from.parent.type !== schema.nodes.paragraph || $from.parentOffset !== 0
          || end !== $from.end()) return null;
      const tr = closeHistory(state.tr.delete(start, end));
      if (kind === 'heading' || kind === 'code_block') return tr.setBlockType(start, start, schema.nodes[kind], {
        ...$from.parent.attrs, ...attributes(match),
      });
      if (kind === 'task' && $from.depth > 1 && $from.node(-1).type === schema.nodes.list_item) {
        const item = $from.node(-1);
        return tr.setNodeMarkup($from.before(-1), undefined, {...item.attrs, checked: /[xX]/.test(match[1])});
      }
      if ($from.depth !== 1) return null;
      const p = tr.doc.nodeAt($from.before())!;
      if (kind === 'blockquote') {
        tr.replaceWith($from.before(), $from.before() + p.nodeSize,
          schema.nodes.blockquote.create({...p.attrs}, schema.nodes.paragraph.create({id:null}, p.content)));
        return tr.setSelection(TextSelection.create(tr.doc,$from.before()+2));
      }
      if (kind === 'bullet_list' || kind === 'ordered_list' || kind === 'task') {
        const item = schema.nodes.list_item.create({...p.attrs, checked: kind === 'task' ? /[xX]/.test(match[1]) : null},
          schema.nodes.paragraph.create({id:null}, p.content));
        const list = schema.nodes[kind === 'ordered_list' ? kind : 'bullet_list'].create({
          before:p.attrs.before, ...attributes(match),
        }, item);
        tr.replaceWith($from.before(), $from.before() + p.nodeSize, list);
        return tr.setSelection(TextSelection.create(tr.doc, $from.before() + 3));
      }
      const node = schema.nodes[kind].create({...p.attrs});
      tr.replaceWith($from.before(), $from.before() + p.nodeSize, [node, schema.nodes.paragraph.create()]);
      return tr.setSelection(TextSelection.create(tr.doc, $from.before() + node.nodeSize + 1));
    },{inCodeMark:false});
  return [
    // WebKit's native DOM input can deliver a trailing Space as NBSP. Match it
    // only in marker syntax; preserve ordinary text and the exact Undo spelling.
    blockRule(/^(#{1,6})[ \u00a0]$/, 'heading', m => ({level:m[1].length})),
    blockRule(/^>[ \u00a0]$/, 'blockquote'),
    blockRule(/^(?:[-+*][ \u00a0])?\[([ \u00a0xX]?)\][ \u00a0]$/, 'task'),
    blockRule(/^([-+*])[ \u00a0]$/, 'bullet_list', m => ({marker:m[1]})),
    blockRule(/^(\d{1,9})([.)])[ \u00a0]$/, 'ordered_list', m => ({start:Number(m[1]),marker:m[2]})),
    blockRule(/^(?:```|~~~)([\w+-]*)[ \u00a0]$/, 'code_block', m => ({language:m[1]})),
    blockRule(/^(?:---|\*\*\*)[ \u00a0]$/, 'horizontal_rule'),
    new InputRule(/(?:^|\s)\*\*([^*]+)\*\*$/, (state, match, start, end) => {
      const prefix = match[0].startsWith(' ') ? 1 : 0;
      return state.tr.insertText(match[1], start + prefix, end)
        .addMark(start + prefix, start + prefix + match[1].length, schema.marks.strong.create());
    },{inCodeMark:false}),
    new InputRule(/(?:^|\s)\*([^*]+)\*$/, (state, match, start, end) => {
      const prefix = match[0].startsWith(' ') ? 1 : 0;
      return state.tr.insertText(match[1], start + prefix, end)
        .addMark(start + prefix, start + prefix + match[1].length, schema.marks.em.create());
    },{inCodeMark:false}),
    new InputRule(/`([^`]+)`$/, (state, match, start, end) => state.tr.insertText(match[1], start, end)
      .addMark(start, start + match[1].length, schema.marks.code.create())
      .removeStoredMark(schema.marks.code),{inCodeMark:false}),
    new InputRule(/\$\$$/, (state,match,start,end) => {
      const tr=state.tr.insertText(match[0],start,end);
      const cursor=start+match[0].length,$cursor=tr.doc.resolve(cursor);
      if(cursor!==$cursor.end())return null;
      const draft=displayDraft(tr.doc,cursor,true);
      const value=draft && /^\$\$(?!\$)([\s\S]*?)\$\$$/.exec(draft.raw)?.[1].trim();
      if(!draft || !value || /(?<!\\)\$\$/.test(value))return null;
      const first=tr.doc.nodeAt(draft.from)!;
      const equation=schema.nodes.equation.create({...first.attrs,value});
      tr.replaceWith(draft.from,draft.to,[equation,schema.nodes.paragraph.create()]);
      return tr.setSelection(TextSelection.create(tr.doc,draft.from+equation.nodeSize+1));
    },{inCodeMark:false}),
    new InputRule(/\$\$([^$\n]+)\$\$$/, (state,match,start,end) => {
      if(!match[1].trim() || escapedDollar(state,start) || (start>0 && state.doc.textBetween(start-1,start)==='$'))return null;
      return state.tr.replaceWith(start,end,schema.nodes.inline_math.create({value:match[1].trim(),display:true}));
    },{inCodeMark:false}),
    new InputRule(/\$([^$\n]+)\$$/, (state,match,start,end) => {
      if(escapedDollar(state,start) || (start>0 && state.doc.textBetween(start-1,start)==='$'))return null;
      const draft=displayDraft(state.doc,end);
      if(draft && !/(?<!\\)\$\$/.test(draft.raw.slice(2)))return null;
      if(/^\s|\s$/.test(match[1]))return null;
      return state.tr.replaceWith(start,end,schema.nodes.inline_math.create({value:match[1]}));
    },{inCodeMark:false}),
    new InputRule(/!\[([^\]]*)\]\(([^)\s]+)\)$/, (state,match,start,end) => {
      const $from=state.doc.resolve(start);
      const attrs={src:match[2],alt:match[1]};
      if($from.depth===1 && !$from.parentOffset && end===$from.end()) {
        const image=schema.nodes.image_block.create({...$from.parent.attrs,...attrs});
        const tr=state.tr.replaceWith($from.before(),$from.after(),[image,schema.nodes.paragraph.create()]);
        return tr.setSelection(TextSelection.create(tr.doc,$from.before()+image.nodeSize+1));
      }
      return state.tr.replaceWith(start,end,schema.nodes.inline_image.create(attrs));
    },{inCodeMark:false}),
    new InputRule(/\[([^\]]+)\]\(([^)\s]+)\)$/, (state,match,start,end) => {
      if(start>0 && state.doc.textBetween(start-1,start)==='!')return null;
      return state.tr.insertText(match[1],start,end).addMark(start,start+match[1].length,schema.marks.link.create({href:match[2]}));
    },{inCodeMark:false}),
  ];
}

export class VisualEditor {
  readonly session: BlockSession;
  readonly view: EditorView;
  readonly host: HTMLElement;
  readonly status: HTMLElement;
  #editable = true;
  #frozen = false;
  #search = '';
  #matches: {from:number;to:number}[] = [];
  #matchIndex = -1;
  #options: VisualOptions;
  #snapshots = new Map<string, ReturnType<BlockSession['snapshot']>>();
  #dialog: HTMLDialogElement | null = null;
  #surfaceEditors = new WeakMap<Node, () => void>();
  get hasOpenDialog() { return !!this.#dialog?.open; }

  constructor(host: HTMLElement, markdown: string, options: VisualOptions = {}) {
    this.host = host;
    this.#options = options;
    this.session = new BlockSession(markdown, options.savedMarkdown, options.trailingParagraph);
    this.status = document.createElement('div'); this.status.className='visual-status'; this.status.setAttribute('role','status');
    host.after(this.status);
    this.session.configure(this.plugins());
    this.view = new EditorView(host, {
      state:this.session.state,
      attributes: {role:'textbox','aria-label':'Document','aria-multiline':'true'},
      editable: () => this.#editable && !this.#frozen,
      dispatchTransaction: tr => this.dispatch(tr),
      handleKeyDown: (_view,event) => (event.key==='Enter'||event.key===' ') && this.activateSelectedMath(event),
      nodeViews: {
        list_item:(node,view,getPos) => this.taskView(node,view,getPos),
        equation:(node,view,getPos) => this.atomView(node,view,getPos),
        inline_math:(node,view,getPos) => this.atomView(node,view,getPos),
        image_block:(node,view,getPos) => this.atomView(node,view,getPos),
        inline_image:(node,view,getPos) => this.atomView(node,view,getPos),
        raw_source:(node,view,getPos) => this.atomView(node,view,getPos),
      },
      handlePaste:(view,event) => {
        const text = event.clipboardData?.getData('text/plain');
        if (!text) return false;
        // Markdown/plain text is pasted as text; it never runs typing rules.
        // HTML parsing is schema-only and cannot create bridge controls/IDs.
        if (event.clipboardData?.getData('text/html')) return false;
        const $from = view.state.selection.$from;
        if ($from.parent.type === schema.nodes.code_block) {
          view.dispatch(view.state.tr.insertText(text)); return true;
        }
        if($from.parent.type===schema.nodes.table_cell && /[\r\n]/.test(text)) {
          this.status.textContent='Use one line per table cell.';return true;
        }
        if(!/[\r\n]/.test(text)) {view.dispatch(view.state.tr.insertText(text).scrollIntoView());return true;}
        const paragraphs = text.replace(/\r\n|\r/g,'\n').split(/\n\n+/).map(part => {
          const content: PMNode[]=[];
          part.split('\n').forEach((line,i) => {if(i) content.push(schema.nodes.hard_break.create()); if(line) content.push(schema.text(line));});
          return schema.nodes.paragraph.create(null,content);
        });
        if (paragraphs.length === 1) {
          view.dispatch(view.state.tr.replaceSelection(new Slice(paragraphs[0].content,0,0)).scrollIntoView());
        } else {
          const slice=new Slice(Fragment.fromArray(paragraphs),1,1);
          view.dispatch(view.state.tr.replaceSelection(slice).scrollIntoView());
        }
        return true;
      },
    });
    document.addEventListener('mousedown', this.blankAreaMouseDown, true);
    this.notify();
  }

  private blankAreaMouseDown = (event: MouseEvent) => {
    if (!this.view.editable || this.view.composing || event.defaultPrevented
        || event.button !== 0 || event.detail > 1
        || event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return;
    const target = event.target;
    const article = this.host.closest('article.markdown-body');
    if (target !== this.view.dom && target !== this.host && target !== article
        && target !== document.body && target !== document.documentElement) return;
    if (!this.host.isConnected) return;
    const lastDOM = this.view.dom.lastElementChild;
    if (!lastDOM) return;
    let lastRect=lastDOM.getBoundingClientRect();
    if(!lastRect.height) {
      const range=document.createRange();range.selectNodeContents(lastDOM);
      lastRect=range.getBoundingClientRect();
    }
    if (event.clientY < lastRect.bottom) return;
    const rect = this.view.dom.getBoundingClientRect();
    if (event.clientX < rect.left || event.clientX > rect.right) return;

    // A single click opens one ordinary text line after any final block. Reuse
    // a trailing empty paragraph so repeated clicks never accumulate blank lines.
    const state = this.view.state, last = state.doc.lastChild!;
    const tr = state.tr;
    if (last.type === schema.nodes.paragraph && !last.content.size) {
      tr.setSelection(TextSelection.create(tr.doc, tr.doc.content.size - 1));
    } else {
      const at = tr.doc.content.size;
      tr.insert(at, schema.nodes.paragraph.create());
      tr.setSelection(TextSelection.create(tr.doc, at + 1));
    }
    tr.setStoredMarks([]);
    event.preventDefault();
    event.stopPropagation();
    this.view.dispatch(closeHistory(tr).scrollIntoView());
    this.view.focus();
  };

  private plugins(): Plugin[] {
    const historyCommand = (forward:boolean): Command => (state,dispatch) =>
      (forward ? redo : undo)(state,tr => dispatch?.(tr.setMeta('bloctHistory',true)));
    const enter: Command = (state,dispatch,view) => {
      const {$from,empty}=state.selection;
      if (this.view?.composing) return false;
      if ($from.parent.type === schema.nodes.table_cell) return this.nextCell(false,true);
      if ($from.parent.type === schema.nodes.code_block) return newlineInCode(state,dispatch);
      if (empty && $from.parent.type === schema.nodes.paragraph && /^(?:```|~~~)[\w+-]*$/.test($from.parent.textContent)) {
        const language=$from.parent.textContent.slice(3);
        const tr=state.tr.delete($from.start(),$from.end()).setBlockType($from.start(),$from.start(),schema.nodes.code_block,{...$from.parent.attrs,language});
        dispatch?.(closeHistory(tr)); return true;
      }
      if ($from.depth > 1 && $from.node(-1).type === schema.nodes.list_item) {
        if(!$from.parent.content.size && $from.node(-1).childCount>1) return true;
        return chainCommands(splitListItem(schema.nodes.list_item),liftListItem(schema.nodes.list_item))(state,dispatch,view);
      }
      if ($from.parent.type === schema.nodes.heading && $from.depth === 1 && empty && $from.parentOffset===0) {
        const tr=state.tr.insert($from.before(),schema.nodes.paragraph.create());
        tr.setSelection(TextSelection.create(tr.doc,$from.before()+1)); dispatch?.(closeHistory(tr)); return true;
      }
      if ($from.parent.type === schema.nodes.paragraph && !$from.parent.content.size && $from.depth>1) {
        return liftEmptyBlock(state,dispatch,view);
      }
      return splitBlock(state, tr => {
        const pos=tr.selection.$from.before();
        if(tr.selection.$from.parent.type===schema.nodes.heading) tr.setNodeMarkup(pos,schema.nodes.paragraph);
        dispatch?.(closeHistory(tr));
      },view);
    };
    const backspace: Command=(state,dispatch,view) => {
      if (this.view?.composing) return false;
      if (undoTypingRule(state,dispatch)) return true;
      const {$from,empty}=state.selection;
      if (empty && !$from.parentOffset && $from.parent.type===schema.nodes.heading) return setBlockType(schema.nodes.paragraph)(state,dispatch);
      if (empty && !$from.parentOffset && $from.depth>1 && $from.node(-1).type===schema.nodes.blockquote) return lift(state,dispatch);
      if (empty && !$from.parentOffset && $from.depth>1 && $from.node(-1).type===schema.nodes.list_item) return liftListItem(schema.nodes.list_item)(state,dispatch);
      // joinBackward may wrap this empty paragraph into the preceding quote or
      // list. Remove only the empty line and select the previous block's end.
      if (empty && $from.depth===1 && $from.parent.type===schema.nodes.paragraph && !$from.parent.content.size) {
        const at=$from.before();
        if (at && dispatch) {
          const tr=closeHistory(state.tr.delete(at,$from.after()));
          tr.setSelection(Selection.near(tr.doc.resolve(at),-1)).setStoredMarks(null);
          dispatch(tr.scrollIntoView());
        }
        return true;
      }
      if (joinTextBoundary(true)(state,dispatch)) return true;
      return baseKeymap.Backspace(state,dispatch,view);
    };
    const deleteForward: Command=(state,dispatch,view) => {
      if(this.view?.composing)return false;
      return joinTextBoundary(false)(state,dispatch) || baseKeymap.Delete(state,dispatch,view);
    };
    return [inputRules({rules:rules()}), keymap({
      'Mod-z':chainCommands(undoTypingRule,historyCommand(false)),
      'Shift-Mod-z':historyCommand(true), 'Mod-y':historyCommand(true),
      'Mod-b':toggleMark(schema.marks.strong), 'Mod-i':toggleMark(schema.marks.em),
      'Mod-e':toggleMark(schema.marks.code), Enter:enter, Backspace:backspace,
      Delete:deleteForward, 'Ctrl-d':deleteForward,
      'Shift-Enter':(state,dispatch) => {
        if(this.view?.composing) return false;
        if(state.selection.$from.parent.type===schema.nodes.heading) return enter(state,dispatch);
        if(state.selection.$from.parent.type===schema.nodes.code_block) return newlineInCode(state,dispatch);
        if(state.selection.$from.parent.type===schema.nodes.table_cell) return this.insertTableRow();
        dispatch?.(state.tr.replaceSelectionWith(schema.nodes.hard_break.create()).scrollIntoView()); return true;
      },
      'Mod-Enter':(state,dispatch) => exitCode(state,dispatch) || this.afterRoot(),
      ArrowUp:() => this.arrowCell('up'), ArrowDown:() => this.arrowCell('down'),
      ArrowLeft:() => this.arrowCell('left'), ArrowRight:() => this.arrowCell('right'),
      Tab: (state,dispatch) => this.inTable() ? this.nextCell(false) : sinkListItem(schema.nodes.list_item)(state,dispatch),
      'Shift-Tab':(state,dispatch) => this.inTable() ? this.nextCell(true) : liftListItem(schema.nodes.list_item)(state,dispatch),
    }),keymap(baseKeymap),new Plugin({props:{decorations:state => this.decorations(state)}})];
  }
  private dispatch(tr: Transaction) {
    if((this.#frozen || !this.#editable) && tr.docChanged) return;
    this.session.dispatch(tr);
    this.view.updateState(this.session.state);
    this.notify();
  }
  private notify() {
    this.#options.onChange?.(this.session.changed);
    // This optional hook belongs to the macOS host, not the editable DOM.
    (window as any)._mvBuildTOC?.();
  }
  private run(command:Command) {
    if(!this.#editable || this.#frozen) return false;
    const handled=command(this.session.state,tr => this.view.dispatch(tr),this.view);
    this.view.focus(); return handled;
  }
  format(kind:string) {
    this.status.textContent='';
    if (!this.#editable || this.#frozen) return false;
    const attrs=this.session.state.selection.$from.parent.attrs;
    if(kind==='paragraph') {
      if(this.session.state.selection.$from.depth===1 && this.session.state.selection.$from.parent.type===schema.nodes.paragraph) {this.view.focus();return true;}
      return this.run(chainCommands(lift,setBlockType(schema.nodes.paragraph,attrs)));
    }
    if(kind.startsWith('heading_')) return this.run(setBlockType(schema.nodes.heading,{...attrs,level:Number(kind.slice(8))}));
    if(kind==='blockquote') return this.run(wrapIn(schema.nodes.blockquote));
    if(kind==='code_block') return this.run(setBlockType(schema.nodes.code_block,attrs));
    if(['bullet_list','ordered_list','task_list'].includes(kind)) {
      return this.run((state,dispatch) => wrapInList(schema.nodes[kind==='ordered_list'?kind:'bullet_list'])(state,tr => {
        if(kind==='task_list') tr.doc.descendants((node,pos) => {
          if(node.type===schema.nodes.list_item && pos>=tr.selection.$from.before(1) && pos<tr.selection.$from.after(1)) {
            tr.setNodeMarkup(pos,undefined,{...node.attrs,checked:false});
          }
        });
        dispatch?.(tr);
      }));
    }
    let node: PMNode;
    if(kind==='table') {
      const row=() => schema.nodes.table_row.create(null,[schema.nodes.table_cell.create(),schema.nodes.table_cell.create()]);
      node=schema.nodes.table.create({align:[null,null]},[row(),row()]);
    } else if(['equation','image_block','horizontal_rule'].includes(kind)) node=schema.nodes[kind].create();
    else return false;
    const {$from}=this.session.state.selection;
    const top=$from.depth ? $from.node(1) : this.session.doc.firstChild!;
    const start=$from.depth ? $from.before(1) : 0;
    const replacing=top.type===schema.nodes.paragraph && !top.content.size;
    const at=replacing ? start : start+top.nodeSize;
    const tr=closeHistory(this.session.state.tr.replaceWith(at,replacing ? at+top.nodeSize : at,[node,schema.nodes.paragraph.create()]));
    tr.setSelection(node.type===schema.nodes.table ? TextSelection.create(tr.doc,at+3) : NodeSelection.create(tr.doc,at));
    this.view.dispatch(tr); this.view.focus(); return true;
  }
  private afterRoot() {
    const {$from}=this.session.state.selection;
    if(!$from.depth) return false;
    const at=$from.after(1);
    const tr=this.session.state.tr.insert(at,schema.nodes.paragraph.create());
    tr.setSelection(TextSelection.create(tr.doc,at+1));this.view.dispatch(closeHistory(tr));return true;
  }
  private inTable() {return this.session.state.selection.$from.parent.type===schema.nodes.table_cell;}
  private tableContext() {
    const {$from}=this.session.state.selection;
    if($from.parent.type!==schema.nodes.table_cell || $from.depth<3) return null;
    const depth=$from.depth-2, table=$from.node(depth);
    if(table.type!==schema.nodes.table) return null;
    return {$from,table,depth,row:$from.index(depth),column:$from.index(depth+1)};
  }
  private tableCellAt(row:number,column:number) {
    const context=this.tableContext();
    if(!context || row<0 || row>=context.table.childCount) return null;
    const targetRow=context.table.child(row);
    if(column<0 || column>=targetRow.childCount) return null;
    let pos=context.$from.start(context.depth);
    for(let i=0;i<row;i++) pos+=context.table.child(i).nodeSize;
    pos++; // Row content starts after its opening token.
    for(let i=0;i<column;i++) pos+=targetRow.child(i).nodeSize;
    return {node:targetRow.child(column),pos:pos+1};
  }
  private arrowCell(direction:'up'|'down'|'left'|'right') {
    const context=this.tableContext(),state=this.session.state;
    if(!context || !state.selection.empty || this.view.composing) return false;
    const vertical=direction==='up'||direction==='down';
    const backward=direction==='up'||direction==='left';
    // Keep ordinary character and wrapped-line movement inside the cell native.
    if(vertical ? !this.view.endOfTextblock(direction,state)
      : context.$from.parentOffset!==(backward?0:context.$from.parent.content.size)) return false;
    const target=this.tableCellAt(context.row+(vertical?(backward?-1:1):0),
      context.column+(vertical?0:(backward?-1:1)));
    // Vertical table edges exit to surrounding content. Horizontal edges
    // must not flatten cells into WebKit's linear text order.
    if(!target) {
      if(direction==='up' && context.row===0) return this.beforeTable();
      if(direction==='down' && context.row===context.table.childCount-1) return this.afterTable();
      return true;
    }
    let pos=target.pos+(vertical?Math.min(context.$from.parentOffset,target.node.content.size)
      :backward?target.node.content.size:0);
    const $target=state.doc.resolve(pos);
    if(/[\uD800-\uDBFF]$/.test($target.nodeBefore?.text??'') && /^[\uDC00-\uDFFF]/.test($target.nodeAfter?.text??'')) pos--;
    this.view.dispatch(state.tr.setSelection(TextSelection.create(state.doc,pos)).scrollIntoView());return true;
  }
  private beforeTable() {
    const context=this.tableContext(),state=this.session.state;
    if(!context) return false;
    const previous=Selection.findFrom(state.doc.resolve(context.$from.before(context.depth)),-1);
    if(previous) {
      this.view.dispatch(state.tr.setSelection(previous).scrollIntoView());return true;
    }
    // With no preceding content, provide an editable area above the first
    // top-level block (also avoids an unrepresentable empty nested paragraph).
    const at=context.$from.before(1);
    const tr=state.tr.insert(at,schema.nodes.paragraph.create());
    tr.setSelection(TextSelection.create(tr.doc,at+1));
    this.view.dispatch(closeHistory(tr).scrollIntoView());return true;
  }
  private afterTable() {
    const context=this.tableContext(),state=this.session.state;
    if(!context) return false;
    const next=Selection.findFrom(state.doc.resolve(context.$from.after(context.depth)),1);
    if(next) {
      this.view.dispatch(state.tr.setSelection(next).scrollIntoView());return true;
    }
    // At document end, provide an editable area after the last top-level
    // block, including when the final table is inside a container.
    const at=context.$from.after(1);
    const tr=state.tr.insert(at,schema.nodes.paragraph.create());
    tr.setSelection(TextSelection.create(tr.doc,at+1));
    this.view.dispatch(closeHistory(tr).scrollIntoView());return true;
  }
  private nextCell(back:boolean,nextRow=false) {
    const context=this.tableContext();
    if(!context || this.view.composing) return false;
    let {row,column}=context;
    if(nextRow) {row++;column=0;}
    else {
      column+=back?-1:1;
      if(column<0) {row--;column=row>=0?context.table.child(row).childCount-1:0;}
      else if(column>=context.table.child(row).childCount) {row++;column=0;}
    }
    const target=this.tableCellAt(row,column);
    if(!target) {
      if(back) return false;
      const at=context.$from.after(context.depth);
      const tr=this.session.state.tr.insert(at,schema.nodes.paragraph.create());
      tr.setSelection(TextSelection.create(tr.doc,at+1));
      this.view.dispatch(closeHistory(tr).scrollIntoView());return true;
    }
    this.view.dispatch(this.session.state.tr.setSelection(TextSelection.create(this.session.doc,target.pos)).scrollIntoView());return true;
  }
  private insertTableRow() {
    const context=this.tableContext();
    if(!context || this.view.composing) return false;
    const count=context.table.firstChild!.childCount;
    const row=schema.nodes.table_row.create(null,Array.from({length:count},()=>schema.nodes.table_cell.create()));
    const at=context.$from.after(context.depth+1);
    const tr=this.session.state.tr.insert(at,row);
    // Begin at the first cell of the new row, independent of the source column.
    tr.setSelection(TextSelection.create(tr.doc,at+2));
    this.view.dispatch(closeHistory(tr).scrollIntoView());return true;
  }
  private decorations(state:EditorState) {
    const decorations:Decoration[]=[];
    this.#matches=[];
    state.doc.descendants((node,pos) => {
      if(node.type===schema.nodes.table) {
        node.forEach((row,rowOffset,rowIndex)=>row.forEach((cell,cellOffset,column)=>{
          const align=node.attrs.align[column];
          const attrs:Record<string,string>={};
          if(['left','center','right'].includes(align))attrs.align=align;
          else if(rowIndex===0)attrs.style='text-align:center';
          if(rowIndex===0)attrs.role='columnheader';
          const at=pos+rowOffset+cellOffset+2;
          decorations.push(Decoration.node(at,at+cell.nodeSize,attrs));
        }));
      }
      if(node.attrs.id && node.isBlock) {
        const attrs:Record<string,string>={'data-block-id':node.attrs.id};
        if(node.type===schema.nodes.heading) attrs.id='block-'+node.attrs.id;
        if(!node.content.size && (node.type===schema.nodes.heading || node.type===schema.nodes.code_block)) {
          attrs['data-placeholder']=node.type===schema.nodes.heading ? `Header ${node.attrs.level}` : 'Code';
          attrs.class='is-empty';
        }
        decorations.push(Decoration.node(pos,pos+node.nodeSize,attrs));
      }
      if(this.#search && node.isText) {
        const text=node.text!.toLocaleLowerCase(),term=this.#search.toLocaleLowerCase();
        for(let i=text.indexOf(term);i>=0;i=text.indexOf(term,i+term.length)) {
          decorations.push(Decoration.inline(pos+i,pos+i+term.length,{class:'visual-match'}));
          this.#matches.push({from:pos+i,to:pos+i+term.length});
        }
      }
    });
    return DecorationSet.create(state.doc,decorations);
  }
  private taskView(node:PMNode,view:EditorView,getPos:()=>number|undefined):NodeView {
    const dom=document.createElement('li'), contentDOM=document.createElement('div');
    const checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.contentEditable='false';checkbox.setAttribute('aria-label','Toggle task');
    const paint=(current:PMNode) => {
      checkbox.hidden=current.attrs.checked==null; checkbox.checked=!!current.attrs.checked;
      checkbox.classList.toggle('mv-task-checkbox',current.attrs.checked!=null);
      dom.classList.toggle('task-item',current.attrs.checked!=null);
      checkbox.disabled=!view.editable;
    };
    checkbox.addEventListener('mousedown',e=>e.preventDefault());
    const toggle=()=>{
      const pos=getPos(); if(pos==null)return;
      const current=view.state.doc.nodeAt(pos)!;
      if(!view.editable){paint(current);return;}
      view.dispatch(closeHistory(view.state.tr.setNodeMarkup(pos,undefined,{...current.attrs,checked:!current.attrs.checked})));
    };
    checkbox.addEventListener('change',toggle);this.#surfaceEditors.set(checkbox,toggle);
    dom.append(checkbox,contentDOM);paint(node);
    return {dom,contentDOM,update:current=>{if(current.type!==schema.nodes.list_item)return false;paint(current);return true;},
      stopEvent:event=>event.target===checkbox};
  }
  private activateSelectedMath(event:KeyboardEvent) {
    if(event.shiftKey||event.metaKey||event.ctrlKey||event.altKey||event.isComposing||this.view.composing)return false;
    const {selection}=this.view.state;
    if(!(selection instanceof NodeSelection) ||
      (selection.node.type!==schema.nodes.equation && selection.node.type!==schema.nodes.inline_math))return false;
    // Arrow navigation keeps DOM focus in EditorView. Activate only the
    // engine-selected node's own editor, as a surface click would do.
    const dom=this.view.nodeDOM(selection.from);
    if(dom && !event.repeat)this.#surfaceEditors.get(dom)?.();
    return true;
  }
  private atomView(node:PMNode,view:EditorView,getPos:()=>number|undefined):NodeView {
    const isMath=node.type===schema.nodes.equation||node.type===schema.nodes.inline_math;
    const dom:HTMLElement=document.createElement(node.isInline?'span':'div');dom.className=isMath?'visual-math':'visual-atom';dom.contentEditable='false';
    const content=document.createElement('span'),button=document.createElement('button');button.type='button';button.textContent='Edit';
    const paint=(current:PMNode)=>{
      content.replaceChildren();
      if(current.type===schema.nodes.equation||current.type===schema.nodes.inline_math) {
        const display=!current.isInline||!!current.attrs.display;
        dom.classList.toggle('visual-math-display',display);
        if(current.attrs.value) content.innerHTML=katex.renderToString(current.attrs.value,{displayMode:display,throwOnError:false,trust:false,strict:'warn'});
        else content.textContent='Equation';
      } else if(current.type===schema.nodes.image_block||current.type===schema.nodes.inline_image) {
        dom.classList.add('visual-image');
        if(this.#options.renderPreview) {
          content.innerHTML=this.#options.renderPreview(imageBlockMarkdown(current.attrs));
          for(const child of Array.from(content.childNodes)) {
            if(child.nodeType===Node.TEXT_NODE && !child.textContent?.trim())child.remove();
          }
          if(current.isInline && content.childNodes.length===1 && content.firstElementChild?.tagName==='P') {
            content.replaceChildren(...content.firstElementChild.childNodes);
          }
          for(const image of content.querySelectorAll<HTMLImageElement>('img')) {
            image.dataset.source=current.attrs.src;
            const url=this.#options.imageURL?.(current.attrs.src);
            if(url)image.src=url;
          }
          return;
        }
        const url=this.#options.imageURL?.(current.attrs.src);
        if(url) {const image=document.createElement('img');image.src=url;image.alt=current.attrs.alt;image.dataset.source=current.attrs.src;content.append(image);}
        else content.textContent=current.attrs.alt||'Image';
        if(current.attrs.caption) {const caption=document.createElement('span');caption.textContent=current.attrs.caption;content.append(caption);}
      } else {
        dom.classList.toggle('visual-preview',!!this.#options.renderPreview);
        if(this.#options.renderPreview) {
          content.innerHTML=this.#options.renderPreview(current.attrs.raw);
          content.querySelectorAll<HTMLInputElement>('input').forEach(input=>{input.disabled=true;});
        } else content.textContent='Preserved content';
        button.textContent='View source';
      }
    };
    const openEditor=()=>{
      if(this.#dialog?.open || view.composing)return;
      const pos=getPos();if(pos==null)return;
      const current=view.state.doc.nodeAt(pos)!;
      if(this.#frozen)return;
      if(!this.#editable && current.type!==schema.nodes.raw_source)return;
      const dialog=document.createElement('dialog'),form=document.createElement('form');form.method='dialog';
      const label=document.createElement('label');label.textContent=current.type===schema.nodes.raw_source?'Preserved source':current.type.name.includes('image')?'Image URL':'Equation';
      const input=document.createElement('textarea'); input.value=current.attrs.raw??current.attrs.src??current.attrs.value??'';
      input.readOnly=current.type===schema.nodes.raw_source; label.append(input);form.append(label);
      const cancel=document.createElement('button');cancel.textContent='Cancel';cancel.value='cancel';form.append(cancel);
      if(!input.readOnly){const save=document.createElement('button');save.textContent='Apply';save.value='apply';form.append(save);}
      dialog.append(form);document.body.append(dialog);
      this.#dialog=dialog;
      // WebKit can close a dialog with its default Escape action and still
      // report the key as unhandled to AppKit. Handle cancellation explicitly.
      dialog.addEventListener('keydown',event=>{
        if(event.key!=='Escape' || event.isComposing || view.composing
          || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey)return;
        event.preventDefault();event.stopPropagation();dialog.close('cancel');
      });
      dialog.addEventListener('close',()=>{
        if(this.#dialog===dialog)this.#dialog=null;
        if(this.view.isDestroyed)return;
        this.status.textContent='';
        if(dialog.returnValue==='apply'&&!this.#frozen){
          const key=current.type.name.includes('image')?'src':'value';
          view.dispatch(closeHistory(view.state.tr.setNodeMarkup(pos,undefined,{...current.attrs,[key]:input.value})));
        }
        dialog.remove();view.focus();
      });dialog.showModal();input.focus();
    };
    this.#surfaceEditors.set(dom,openEditor);
    if(isMath || node.type!==schema.nodes.raw_source || this.#options.renderPreview) {
      dom.dataset.visualSurface=node.type.name;
      dom.setAttribute('role','button');dom.setAttribute('aria-label',isMath?'Edit equation':node.type===schema.nodes.raw_source?'View source':'Edit image');
      let pointerStart: {x:number;y:number}|undefined;
      dom.addEventListener('mousedown',event=>{pointerStart={x:event.clientX,y:event.clientY};});
      dom.addEventListener('click',event=>{
        const moved=pointerStart && (Math.abs(event.clientX-pointerStart.x)>4||Math.abs(event.clientY-pointerStart.y)>4);
        pointerStart=undefined;
        if(!moved){event.preventDefault();openEditor();}
      });
      dom.addEventListener('keydown',event=>{
        if(event.key==='Enter'||event.key===' ') {
          event.preventDefault();event.stopPropagation();
          if(!event.repeat)openEditor();
        }
      });
      dom.append(content);
    } else {
      button.addEventListener('click',openEditor);dom.append(content,button);
    }
    const update=(current:PMNode)=>{
      if(current.type!==node.type)return false;
      paint(current);
      if(isMath || dom.hasAttribute('role')){
        const enabled=this.#editable || current.type===schema.nodes.raw_source;
        dom.tabIndex=enabled?0:-1;dom.setAttribute('aria-disabled',String(!enabled));
      }
      return true;
    };
    update(node);
    return {dom,update,stopEvent:()=>true};
  }
  setEditable(value:boolean) {
    this.#editable=value;this.view.setProps({editable:()=>this.#editable&&!this.#frozen});
    for(const surface of this.view.dom.querySelectorAll<HTMLElement>('[data-visual-surface]')) {
      const enabled=value || surface.dataset.visualSurface==='raw_source';
      surface.tabIndex=enabled?0:-1;surface.setAttribute('aria-disabled',String(!enabled));
    }
    this.updateTaskAvailability();
  }
  private updateTaskAvailability() {
    for(const checkbox of this.view.dom.querySelectorAll<HTMLInputElement>('li.task-item > input.mv-task-checkbox'))checkbox.disabled=!this.view.editable;
  }
  history(forward:boolean) {
    if(this.#frozen || !this.#editable)return false;
    return (forward?redo:undo)(this.session.state,tr=>this.view.dispatch(tr.setMeta('bloctHistory',true)));
  }
  freezeIfClean() {
    const dirty=this.session.changed||this.view.composing||this.hasOpenDialog;
    if(!dirty){this.#frozen=true;this.view.setProps({editable:()=>false});this.updateTaskAvailability();}
    return dirty;
  }
  unfreeze() {this.#frozen=false;this.view.setProps({editable:()=>this.#editable});this.updateTaskAvailability();}
  async snapshot() {
    const deadline=Date.now()+1500;
    while(this.view.composing && Date.now()<deadline) await new Promise(r=>setTimeout(r,20));
    if(this.view.composing) throw new Error('Finish text composition before saving.');
    const snapshot=this.session.snapshot(),token=randomID();this.#snapshots.set(token,snapshot);
    return {text:snapshot.markdown,token,revision:snapshot.revision};
  }
  async handoff() {
    const snapshot=await this.snapshot();
    // Freeze in the same JS continuation as serialization, before native code
    // replaces the view. Keystrokes after this point cannot escape the snapshot.
    this.#frozen=true;this.view.setProps({editable:()=>false});
    return snapshot;
  }
  restoreDraft(markdown:string,savedMarkdown:string) {
    this.session.acceptExternal(markdown);
    this.session.setSavedBaseline(savedMarkdown);
    this.session.configure(this.plugins());
    this.view.updateState(this.session.state);this.#snapshots.clear();this.unfreeze();this.notify();
  }
  acknowledge(token:string,closing=false) {
    const snapshot=this.#snapshots.get(token);if(!snapshot)return false;
    this.#snapshots.delete(token);this.session.markSaved(snapshot);
    const clean=!this.session.changed&&!this.view.composing;
    if(closing&&clean){this.#frozen=true;this.view.setProps({editable:()=>false});}
    this.notify();return clean;
  }
  reload(markdown:string) {
    this.session.acceptExternal(markdown);this.session.configure(this.plugins());
    this.view.updateState(this.session.state);this.#snapshots.clear();this.unfreeze();this.notify();
  }
  search(term:string) {this.#search=term;this.#matchIndex=-1;this.view.updateState(this.session.state);}
  navigate(forward:boolean) {
    if(!this.#matches.length)return;
    this.#matchIndex=(this.#matchIndex+(forward?1:-1)+this.#matches.length)%this.#matches.length;
    const found=this.#matches[this.#matchIndex];this.view.domAtPos(found.from).node.parentElement?.scrollIntoView({block:'center'});
  }
  focus(){this.view.focus();}
  focusAtCoords(left:number,top:number) {
    if(!this.view.editable || this.view.composing)return;
    const target=document.elementFromPoint(left,top)?.closest('[data-visual-surface],input.mv-task-checkbox');
    const point=this.view.posAtCoords({left,top});
    const pos=point?.pos??this.view.state.doc.content.size;
    const selection=Selection.near(this.view.state.doc.resolve(pos),pos===this.view.state.doc.content.size?-1:1);
    this.view.dispatch(this.view.state.tr.setSelection(selection).setStoredMarks(null));
    this.view.focus();
    if(target && this.view.dom.contains(target))this.#surfaceEditors.get(target)?.();
  }
  destroy(){this.#dialog?.remove();this.#dialog=null;document.removeEventListener('mousedown',this.blankAreaMouseDown,true);this.view.destroy();this.status.remove();}
}

export function mountVisualEditor(host:HTMLElement,markdown:string,options:VisualOptions={}) {
  return new VisualEditor(host,markdown,options);
}
