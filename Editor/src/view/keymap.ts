import {TextSelection, type Command} from '@tiptap/pm/state';
import {undoInputRule} from '@tiptap/pm/inputrules';
import {joinTextblockBackward, joinTextblockForward} from '@tiptap/pm/commands';
import {closeHistory} from '@tiptap/pm/history';
import type {EditorView} from '@tiptap/pm/view';
import type {Node as PMNode} from '@tiptap/pm/model';
import {schema} from '../model/schema.ts';

// Keyboard commands that need no editor instance state. The key bindings
// themselves are in VisualEditor.plugins() (visual-editor.ts).

// Both Return keys leave a heading. Keep its unselected text and container,
// while putting the caret in a separate plain paragraph. Empty headings become
// Text rather than leaving an unused Header placeholder behind.
export const exitHeading: Command = (state, dispatch) => {
  const {$from, $to} = state.selection;
  if (!(state.selection instanceof TextSelection) || $from.parent.type !== schema.nodes.heading
      || !$from.sameParent($to)) return false;
  if (dispatch) {
    const tr = state.tr.deleteSelection(), cursor = tr.selection.$from;
    if (!cursor.parent.content.size) {
      tr.setNodeMarkup(cursor.before(), schema.nodes.paragraph, cursor.parent.attrs);
    } else if (!cursor.parentOffset) {
      tr.insert(cursor.before(), schema.nodes.paragraph.create());
      tr.setSelection(TextSelection.create(tr.doc, cursor.before() + 1));
    } else {
      tr.split(cursor.pos, 1, [{type: schema.nodes.paragraph}]);
      tr.setSelection(TextSelection.create(tr.doc, cursor.pos + 2));
    }
    dispatch(closeHistory(tr).setStoredMarks([]).scrollIntoView());
  }
  return true;
};

// Inverting a structural rule can map the selection into the following block.
// The input-rules record retains the source insertion position before wrapping.
export const undoTypingRule: Command = (state, dispatch) => {
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
export const joinTextBoundary = (backward:boolean): Command => (state,dispatch) => {
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

export function afterRoot(view:EditorView) {
  const {$from}=view.state.selection;
  if(!$from.depth) return false;
  const at=$from.after(1);
  const tr=view.state.tr.insert(at,schema.nodes.paragraph.create());
  tr.setSelection(TextSelection.create(tr.doc,at+1));view.dispatch(closeHistory(tr));return true;
}
