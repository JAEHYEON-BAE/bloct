import {randomID} from '../model/id.ts';
import {EditorView, Decoration, DecorationSet, type NodeView} from '@tiptap/pm/view';
import {Plugin, Selection, TextSelection, NodeSelection, type Command, type EditorState, type Transaction} from '@tiptap/pm/state';
import {inputRules} from '@tiptap/pm/inputrules';
import {keymap} from '@tiptap/pm/keymap';
import {baseKeymap, chainCommands, exitCode, lift, liftEmptyBlock, newlineInCode, setBlockType, splitBlock, toggleMark, wrapIn} from '@tiptap/pm/commands';
import {wrapInList, splitListItem, sinkListItem, liftListItem} from '@tiptap/pm/schema-list';
import {undo, redo, closeHistory} from '@tiptap/pm/history';
import {Fragment, Slice, type Node as PMNode} from '@tiptap/pm/model';
import katex from 'katex';
import {BlockSession} from '../model/session.ts';
import {schema} from '../model/schema.ts';
import {imageBlockMarkdown} from '../model/serializer.ts';
import {rules, codeBoundary} from './input-rules.ts';
import {undoTypingRule, exitHeading, joinTextBoundary, afterRoot} from './keymap.ts';
import {inTable, arrowCell, nextCell, insertTableRow} from './table.ts';
import {inputHistory} from './input-history.ts';

export interface VisualOptions {
  savedMarkdown?: string;
  // The app enables one input line at EOF without changing the saved source.
  trailingParagraph?: boolean;
  onChange?: (dirty: boolean) => void;
  imageURL?: (source: string) => string | null;
  // The native host supplies the same sanitized renderer used before Aa.
  renderPreview?: (markdown: string) => string;
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
  #dialogHistory: ((forward: boolean) => void) | null = null;
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
      if ($from.parent.type === schema.nodes.table_cell) return nextCell(this.view,false,true);
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
      if (exitHeading(state,dispatch)) return true;
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
    return [inputRules({rules:rules()}), codeBoundary, keymap({
      'Mod-z':chainCommands(undoTypingRule,historyCommand(false)),
      'Shift-Mod-z':historyCommand(true), 'Mod-y':historyCommand(true),
      'Mod-b':toggleMark(schema.marks.strong), 'Mod-i':toggleMark(schema.marks.em),
      'Mod-e':toggleMark(schema.marks.code), Enter:enter, Backspace:backspace,
      Delete:deleteForward, 'Ctrl-d':deleteForward,
      'Shift-Enter':(state,dispatch) => {
        if(this.view?.composing) return false;
        if(state.selection.$from.parent.type===schema.nodes.heading) return enter(state,dispatch);
        if(state.selection.$from.parent.type===schema.nodes.code_block) return newlineInCode(state,dispatch);
        if(state.selection.$from.parent.type===schema.nodes.table_cell) return insertTableRow(this.view);
        dispatch?.(state.tr.replaceSelectionWith(schema.nodes.hard_break.create()).scrollIntoView()); return true;
      },
      'Mod-Enter':(state,dispatch) => exitCode(state,dispatch) || afterRoot(this.view),
      ArrowUp:() => arrowCell(this.view,'up'), ArrowDown:() => arrowCell(this.view,'down'),
      ArrowLeft:() => arrowCell(this.view,'left'), ArrowRight:() => arrowCell(this.view,'right'),
      Tab: (state,dispatch) => inTable(state) ? nextCell(this.view,false) : sinkListItem(schema.nodes.list_item)(state,dispatch),
      'Shift-Tab':(state,dispatch) => inTable(state) ? nextCell(this.view,true) : liftListItem(schema.nodes.list_item)(state,dispatch),
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
  // Block conversion entry point. No UI calls it since the formatting bar was
  // removed; the DOM tests drive it and the planned slash menu will use it.
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
      this.#dialogHistory=inputHistory(input);
      // WebKit can close a dialog with its default Escape action and still
      // report the key as unhandled to AppKit. Handle cancellation explicitly.
      dialog.addEventListener('keydown',event=>{
        if ((event.metaKey || event.ctrlKey) && !event.altKey
          && (event.key.toLowerCase()==='z' || (event.key.toLowerCase()==='y' && !event.shiftKey))) {
          event.preventDefault();event.stopPropagation();
          if (!event.isComposing && !view.composing) this.history(event.shiftKey || event.key.toLowerCase()==='y');
          return;
        }
        if(event.key!=='Escape' || event.isComposing || view.composing
          || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey)return;
        event.preventDefault();event.stopPropagation();dialog.close('cancel');
      });
      dialog.addEventListener('close',()=>{
        if(this.#dialog===dialog){this.#dialog=null;this.#dialogHistory=null;}
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
    if(this.hasOpenDialog){this.#dialogHistory?.(forward);return true;}
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
  destroy(){this.#dialog?.remove();this.#dialog=null;this.#dialogHistory=null;document.removeEventListener('mousedown',this.blankAreaMouseDown,true);this.view.destroy();this.status.remove();}
}

export function mountVisualEditor(host:HTMLElement,markdown:string,options:VisualOptions={}) {
  return new VisualEditor(host,markdown,options);
}
