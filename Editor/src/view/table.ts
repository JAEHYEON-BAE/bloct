import {Selection, TextSelection, type EditorState} from '@tiptap/pm/state';
import {closeHistory} from '@tiptap/pm/history';
import type {EditorView} from '@tiptap/pm/view';
import {schema} from '../model/schema.ts';

// Moving between table cells and out of a table with the keyboard.

export function inTable(state:EditorState) {return state.selection.$from.parent.type===schema.nodes.table_cell;}
function tableContext(state:EditorState) {
  const {$from}=state.selection;
  if($from.parent.type!==schema.nodes.table_cell || $from.depth<3) return null;
  const depth=$from.depth-2, table=$from.node(depth);
  if(table.type!==schema.nodes.table) return null;
  return {$from,table,depth,row:$from.index(depth),column:$from.index(depth+1)};
}
function tableCellAt(state:EditorState,row:number,column:number) {
  const context=tableContext(state);
  if(!context || row<0 || row>=context.table.childCount) return null;
  const targetRow=context.table.child(row);
  if(column<0 || column>=targetRow.childCount) return null;
  let pos=context.$from.start(context.depth);
  for(let i=0;i<row;i++) pos+=context.table.child(i).nodeSize;
  pos++; // Row content starts after its opening token.
  for(let i=0;i<column;i++) pos+=targetRow.child(i).nodeSize;
  return {node:targetRow.child(column),pos:pos+1};
}
export function arrowCell(view:EditorView,direction:'up'|'down'|'left'|'right') {
  const state=view.state,context=tableContext(state);
  if(!context || !state.selection.empty || view.composing) return false;
  const vertical=direction==='up'||direction==='down';
  const backward=direction==='up'||direction==='left';
  // Keep ordinary character and wrapped-line movement inside the cell native.
  if(vertical ? !view.endOfTextblock(direction,state)
    : context.$from.parentOffset!==(backward?0:context.$from.parent.content.size)) return false;
  const target=tableCellAt(state,context.row+(vertical?(backward?-1:1):0),
    context.column+(vertical?0:(backward?-1:1)));
  // Vertical table edges exit to surrounding content. Horizontal edges
  // must not flatten cells into WebKit's linear text order.
  if(!target) {
    if(direction==='up' && context.row===0) return beforeTable(view);
    if(direction==='down' && context.row===context.table.childCount-1) return afterTable(view);
    return true;
  }
  let pos=target.pos+(vertical?Math.min(context.$from.parentOffset,target.node.content.size)
    :backward?target.node.content.size:0);
  const $target=state.doc.resolve(pos);
  if(/[\uD800-\uDBFF]$/.test($target.nodeBefore?.text??'') && /^[\uDC00-\uDFFF]/.test($target.nodeAfter?.text??'')) pos--;
  view.dispatch(state.tr.setSelection(TextSelection.create(state.doc,pos)).scrollIntoView());return true;
}
function beforeTable(view:EditorView) {
  const state=view.state,context=tableContext(state);
  if(!context) return false;
  const previous=Selection.findFrom(state.doc.resolve(context.$from.before(context.depth)),-1);
  if(previous) {
    view.dispatch(state.tr.setSelection(previous).scrollIntoView());return true;
  }
  // With no preceding content, provide an editable area above the first
  // top-level block (also avoids an unrepresentable empty nested paragraph).
  const at=context.$from.before(1);
  const tr=state.tr.insert(at,schema.nodes.paragraph.create());
  tr.setSelection(TextSelection.create(tr.doc,at+1));
  view.dispatch(closeHistory(tr).scrollIntoView());return true;
}
function afterTable(view:EditorView) {
  const state=view.state,context=tableContext(state);
  if(!context) return false;
  const next=Selection.findFrom(state.doc.resolve(context.$from.after(context.depth)),1);
  if(next) {
    view.dispatch(state.tr.setSelection(next).scrollIntoView());return true;
  }
  // At document end, provide an editable area after the last top-level
  // block, including when the final table is inside a container.
  const at=context.$from.after(1);
  const tr=state.tr.insert(at,schema.nodes.paragraph.create());
  tr.setSelection(TextSelection.create(tr.doc,at+1));
  view.dispatch(closeHistory(tr).scrollIntoView());return true;
}
export function nextCell(view:EditorView,back:boolean,nextRow=false) {
  const context=tableContext(view.state);
  if(!context || view.composing) return false;
  let {row,column}=context;
  if(nextRow) {row++;column=0;}
  else {
    column+=back?-1:1;
    if(column<0) {row--;column=row>=0?context.table.child(row).childCount-1:0;}
    else if(column>=context.table.child(row).childCount) {row++;column=0;}
  }
  const target=tableCellAt(view.state,row,column);
  if(!target) {
    if(back) return false;
    const at=context.$from.after(context.depth);
    const tr=view.state.tr.insert(at,schema.nodes.paragraph.create());
    tr.setSelection(TextSelection.create(tr.doc,at+1));
    view.dispatch(closeHistory(tr).scrollIntoView());return true;
  }
  view.dispatch(view.state.tr.setSelection(TextSelection.create(view.state.doc,target.pos)).scrollIntoView());return true;
}
export function insertTableRow(view:EditorView) {
  const context=tableContext(view.state);
  if(!context || view.composing) return false;
  const count=context.table.firstChild!.childCount;
  const row=schema.nodes.table_row.create(null,Array.from({length:count},()=>schema.nodes.table_cell.create()));
  const at=context.$from.after(context.depth+1);
  const tr=view.state.tr.insert(at,row);
  // Begin at the first cell of the new row, independent of the source column.
  tr.setSelection(TextSelection.create(tr.doc,at+2));
  view.dispatch(closeHistory(tr).scrollIntoView());return true;
}
