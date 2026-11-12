import {Plugin, TextSelection, type EditorState} from '@tiptap/pm/state';
import {InputRule} from '@tiptap/pm/inputrules';
import {closeHistory} from '@tiptap/pm/history';
import type {Node as PMNode} from '@tiptap/pm/model';
import {schema} from '../model/schema.ts';

// Typing rules: block markers + Space, inline marks, math, images and links.

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
// TeX typed between `$` delimiters. A line break inside it stays a line break
// of the TeX; any other inline node ends the match.
function mathText(doc:PMNode,from:number,to:number) {
  let plain=true;
  doc.nodesBetween(from,to,node=>{
    if(node.isInline && !node.isText && node.type!==schema.nodes.hard_break && node.type!==schema.nodes.soft_break)plain=false;
  });
  return plain?doc.textBetween(from,to,'\n','\n'):null;
}
function escapedDollar(state:EditorState,pos:number) {
  const $pos=state.doc.resolve(pos);
  const before=$pos.parent.textBetween(0,$pos.parentOffset);
  return ((/\\+$/.exec(before)?.[0].length ?? 0)%2)===1;
}

// Inline code ends where its span ends: a cursor right after one types
// ordinary text. An edit that began inside code (Mod-e typing, deleting within
// the span) stays code. Stored marks end a composition, so IME transactions
// are left alone; the cursor is already settled before one starts.
const typesCode = (state: EditorState) => {
  const {$from, $to, empty} = state.selection;
  return !!schema.marks.code.isInSet(state.storedMarks ?? (empty ? $from.marks() : $from.marksAcross($to)) ?? []);
};
export const codeBoundary = new Plugin({
  appendTransaction(transactions, old, state) {
    const {$cursor} = state.selection as TextSelection;
    if (!$cursor || state.storedMarks) return null;
    const before = $cursor.nodeBefore, after = $cursor.nodeAfter;
    if (!before || !schema.marks.code.isInSet(before.marks)
        || (after && schema.marks.code.isInSet(after.marks))) return null;
    if (transactions.some(tr => tr.getMeta('composition'))) return null;
    if (transactions.some(tr => tr.docChanged) && typesCode(old)) return null;
    return state.tr.setStoredMarks(schema.marks.code.removeFromSet($cursor.marks()));
  },
});

export function rules(): InputRule[] {
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
        .addMark(start + prefix, start + prefix + match[1].length, schema.marks.strong.create())
        .removeStoredMark(schema.marks.strong);
    },{inCodeMark:false}),
    new InputRule(/(?:^|\s)\*([^*]+)\*$/, (state, match, start, end) => {
      const prefix = match[0].startsWith(' ') ? 1 : 0;
      return state.tr.insertText(match[1], start + prefix, end)
        .addMark(start + prefix, start + prefix + match[1].length, schema.marks.em.create())
        .removeStoredMark(schema.marks.em);
    },{inCodeMark:false}),
    new InputRule(/`([^`]+)`$/, (state, match, start, end) => state.tr.insertText(match[1], start, end)
      .addMark(start, start + match[1].length, schema.marks.code.create())
      .removeStoredMark(schema.marks.code),{inCodeMark:false}),
    new InputRule(/\$\$$/, (state,match,start,end) => {
      const tr=state.tr.insertText(match[0],start,end);
      const cursor=start+match[0].length,$cursor=tr.doc.resolve(cursor);
      if(cursor!==$cursor.end())return null;
      const draft=displayDraft(tr.doc,cursor,true);
      const inner=draft && /^\$\$(?!\$)([\s\S]*?)\$\$$/.exec(draft.raw)?.[1];
      if(!draft || !inner?.trim() || /(?<!\\)\$\$/.test(inner))return null;
      // Keep the lines as typed, and the delimiters on the TeX lines when
      // they were typed there.
      const openLine=/^[\t \u00a0]*\n/.test(inner), closeLine=/\n[\t \u00a0]*$/.test(inner);
      let value=inner;
      if(openLine)value=value.replace(/^[\t \u00a0]*\n/,'');
      if(closeLine)value=value.replace(/\n[\t \u00a0]*$/,'');
      const first=tr.doc.nodeAt(draft.from)!;
      const equation=schema.nodes.equation.create({...first.attrs,value,openLine,closeLine});
      tr.replaceWith(draft.from,draft.to,[equation,schema.nodes.paragraph.create()]);
      return tr.setSelection(TextSelection.create(tr.doc,draft.from+equation.nodeSize+1));
    },{inCodeMark:false}),
    new InputRule(/\$\$([^$\n]+)\$\$$/, (state,match,start,end) => {
      if(!match[1].trim() || escapedDollar(state,start) || (start>0 && state.doc.textBetween(start-1,start)==='$'))return null;
      // The closing `$` being typed is not in the document yet.
      const inner=mathText(state.doc,start+2,end-1);
      if(inner==null)return null;
      // As the importer reads `$$ x $$`: one space each side is the delimiter's.
      const pad=/^ /.test(inner) && / $/.test(inner) && /[^ \n]/.test(inner);
      const value=pad?inner.slice(1,-1):inner;
      return state.tr.replaceWith(start,end,schema.nodes.inline_math.create({value,display:true,pad}));
    },{inCodeMark:false}),
    new InputRule(/\$([^$\n]+)\$$/, (state,match,start,end) => {
      if(escapedDollar(state,start) || (start>0 && state.doc.textBetween(start-1,start)==='$'))return null;
      const draft=displayDraft(state.doc,end);
      if(draft && !/(?<!\\)\$\$/.test(draft.raw.slice(2)))return null;
      if(/^\s|\s$/.test(match[1]))return null;
      const value=mathText(state.doc,start+1,end);
      if(value==null || /^\s|\s$/.test(value))return null;
      return state.tr.replaceWith(start,end,schema.nodes.inline_math.create({value}));
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
