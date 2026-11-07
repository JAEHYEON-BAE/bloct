import {randomID} from './id.ts';
import {Fragment, type Node as PMNode} from '@tiptap/pm/model';
import {EditorState, TextSelection, type Transaction, type Plugin} from '@tiptap/pm/state';
import {history, undo, redo, closeHistory} from '@tiptap/pm/history';
import {sinkListItem, liftListItem, splitListItem} from '@tiptap/pm/schema-list';
import {importMarkdown, type ImportedDocument} from './importer.ts';
import {schema} from './schema.ts';
import {serialize} from './serializer.ts';

export interface BlockReference {
  readonly documentId: string;
  readonly generation: number;
  readonly revision: number;
  readonly blockId: string;
}
export type BlockCommand =
  | {type: 'replaceText'; from: number; to: number; text: string}
  | {type: 'setType'; kind: 'paragraph' | 'heading'; level?: number}
  | {type: 'split'; offset: number}
  | {type: 'join' | 'indent' | 'outdent' | 'duplicate' | 'delete'}
  | {type: 'setChecked'; checked: boolean}
  | {type: 'move'; target: BlockReference; after?: boolean};

interface Entry {node: PMNode; pos: number; parent: PMNode; parentPos: number; index: number}

// Headless adapter over the real engine, not an independently editable block
// store. A future EditorView must dispatch through the same transaction path.
export class BlockSession {
  readonly documentId = randomID();
  #generation = 0;
  #revision = 0;
  #imported: ImportedDocument;
  #state: EditorState;
  #saved: string;
  #references = new WeakSet<object>();
  #snapshots = new WeakSet<object>();
  #savedRevision = 0;
  #savedDoc: PMNode | null;
  #snapshotDocs = new WeakMap<object, PMNode>();

  constructor(markdown: string, savedMarkdown = markdown) {
    this.#imported = importMarkdown(markdown);
    this.#state = this.createState(this.#imported.doc);
    this.#saved = savedMarkdown;
    this.#savedDoc = savedMarkdown === markdown ? this.#state.doc : null;
  }
  private createState(doc: PMNode) {return EditorState.create({schema, doc, plugins: [history()]});}
  get doc() {return this.#state.doc;}
  get state() {return this.#state;}
  get changed() {return this.#savedDoc ? !this.doc.eq(this.#savedDoc) : this.dirty;}
  configure(plugins: Plugin[]) {
    this.#state = this.#state.reconfigure({plugins: [...this.#state.plugins, ...plugins]});
  }
  // EditorView sends native typing, composition and selection transactions here.
  // Continuous typing keeps the engine's normal history grouping.
  dispatch(tr: Transaction) {
    if (!tr.before.eq(this.doc)) throw new Error('Stale editor transaction');
    if (tr.docChanged && !tr.getMeta('bloctHistory')) normalize(tr, this.doc, /\r\n|\r|\n/.exec(this.#imported.original)?.[0] ?? '\n');
    const result = this.#state.applyTransaction(tr);
    result.state.doc.check();
    this.#state = result.state;
    if (result.transactions.some(t => t.docChanged)) this.#revision++;
  }
  get revision() {return this.#revision;}
  get generation() {return this.#generation;}
  get selection() {return this.#state.selection.toJSON();}
  get dirty() {
    try {return this.markdown() !== this.#saved;}
    catch {return true;} // An unexportable draft must never be treated as clean.
  }
  markdown() {return serialize(this.#imported, this.doc);}
  snapshot() {
    const snapshot = Object.freeze({documentId: this.documentId, generation: this.#generation,
      revision: this.#revision, markdown: this.markdown()});
    this.#snapshots.add(snapshot);
    this.#snapshotDocs.set(snapshot, this.doc);
    return snapshot;
  }

  // A delayed save acknowledges its own frozen text, never a newer draft.
  markSaved(snapshot: ReturnType<BlockSession['snapshot']>) {
    if (!snapshot || !this.#snapshots.has(snapshot) || snapshot.documentId !== this.documentId
        || snapshot.generation !== this.#generation || snapshot.revision > this.#revision
        || snapshot.revision < this.#savedRevision) return false;
    this.#snapshots.delete(snapshot);
    this.#saved = snapshot.markdown;
    this.#savedDoc = this.#snapshotDocs.get(snapshot)!;
    this.#savedRevision = snapshot.revision;
    return true;
  }
  setSavedBaseline(markdown: string) {
    this.#saved = markdown;
    this.#savedDoc = this.markdown() === markdown ? this.doc : null;
  }
  acceptExternal(markdown: string) {
    this.#imported = importMarkdown(markdown);
    this.#state = this.createState(this.#imported.doc);
    this.#saved = markdown;
    this.#savedDoc = this.#state.doc;
    this.#generation++;
    this.#revision++;
    this.#references = new WeakSet();
    this.#snapshots = new WeakSet();
    this.#savedRevision = this.#revision;
  }

  private index() {
    const entries = new Map<string, Entry>();
    const visit = (parent: PMNode, parentPos: number) => {
      parent.forEach((node, offset, index) => {
        const pos = parentPos + 1 + offset;
        if (node.attrs.id) entries.set(node.attrs.id, {node, pos, parent, parentPos, index});
        if (!node.isLeaf) visit(node, pos);
      });
    };
    visit(this.doc, -1);
    return entries;
  }
  reference(id: string): BlockReference {
    if (!this.index().has(id)) throw new Error('Unknown block');
    const reference = Object.freeze({documentId: this.documentId, generation: this.#generation,
      revision: this.#revision, blockId: id});
    this.#references.add(reference);
    return reference;
  }
  private resolve(reference: BlockReference) {
    if (!reference || !this.#references.has(reference) || reference.documentId !== this.documentId
        || reference.generation !== this.#generation || reference.revision !== this.#revision) return;
    return this.index().get(reference.blockId);
  }

  setSelection(reference: BlockReference, offset: number) {
    const entry = this.resolve(reference);
    if (!entry || !entry.node.isTextblock || !validOffset(entry.node, offset)) return false;
    this.#state = this.#state.apply(this.#state.tr.setSelection(TextSelection.create(this.doc, entry.pos + 1 + offset)));
    return true;
  }

  private apply(tr: Transaction) {
    tr.doc.check();
    this.#state = this.#state.apply(closeHistory(tr));
    if (tr.docChanged) this.#revision++;
  }
  undo() {
    return undo(this.#state, tr => {this.#state = this.#state.apply(tr); this.#revision++;});
  }
  redo() {
    return redo(this.#state, tr => {this.#state = this.#state.apply(tr); this.#revision++;});
  }

  execute(reference: BlockReference, command: BlockCommand): boolean {
    const entry = this.resolve(reference);
    if (!entry || !command || typeof command !== 'object') return false;
    const {node, pos, parent, parentPos, index} = entry;
    const eol = /\r\n|\r|\n/.exec(this.#imported.original)?.[0] ?? '\n';
    let tr = this.#state.tr;
    let structural = false;
    switch (command.type) {
      case 'replaceText':
        if (!['paragraph', 'heading', 'code_block'].includes(node.type.name)
            || typeof command.text !== 'string' || command.from > command.to
            || !validOffset(node, command.from) || !validOffset(node, command.to)
            || /[\r\n]/.test(command.text)) return false;
        tr.insertText(command.text, pos + 1 + command.from, pos + 1 + command.to);
        break;
      case 'setType':
        if (!['paragraph', 'heading'].includes(node.type.name) || (command.kind !== 'paragraph' && command.kind !== 'heading')) return false;
        if (command.kind === 'heading' && (parent.type !== schema.nodes.doc || !Number.isInteger(command.level)
            || command.level! < 1 || command.level! > 6 || hasBreak(node))) return false;
        tr.setNodeMarkup(pos, schema.nodes[command.kind], {...node.attrs,
          ...(command.kind === 'heading' ? {level: command.level} : {})});
        structural = true;
        break;
      case 'setChecked':
        if (node.type !== schema.nodes.list_item || node.attrs.checked == null || typeof command.checked !== 'boolean') return false;
        if (node.attrs.checked === command.checked) return true;
        tr.setNodeMarkup(pos, undefined, {...node.attrs, checked: command.checked});
        break;
      case 'split': {
        if (!['paragraph', 'heading'].includes(node.type.name) || !validOffset(node, command.offset)) return false;
        const at = pos + 1 + command.offset;
        tr.setSelection(TextSelection.create(tr.doc, at));
        if (parent.type === schema.nodes.list_item) {
          const working = this.#state.apply(tr);
          let split: Transaction | undefined;
          if (!splitListItem(schema.nodes.list_item)(working, next => {split = next;})) return false;
          tr = split!;
        } else if (parent.type === schema.nodes.doc) {
          if (node.type === schema.nodes.heading && command.offset === 0) {
            tr.insert(pos, schema.nodes.paragraph.create({id: randomID(), before: node.attrs.before}));
            tr.setNodeMarkup(pos + 2, undefined, {...node.attrs, before: eol + eol});
            tr.setSelection(TextSelection.create(tr.doc, pos + 1));
          } else {
            tr.split(at, 1, [{type: schema.nodes.paragraph,
              attrs: {id: randomID(), source: null, before: '\n\n'}}]);
            tr.setSelection(TextSelection.create(tr.doc, at + 2));
          }
        } else return false;
        structural = true;
        break;
      }
      case 'join': {
        if (parent.type !== schema.nodes.doc || node.type !== schema.nodes.paragraph || index === 0) return false;
        const previous = parent.child(index - 1);
        if (!['paragraph', 'heading'].includes(previous.type.name)
            || (previous.type.name === 'heading' && (hasBreak(previous) || hasBreak(node)))) return false;
        tr.join(pos);
        tr.setSelection(TextSelection.create(tr.doc, pos - 1));
        structural = true;
        break;
      }
      case 'indent': case 'outdent': {
        if (node.type !== schema.nodes.list_item) return false;
        tr.setSelection(TextSelection.create(tr.doc, pos + 2));
        const working = this.#state.apply(tr);
        let changed: Transaction | undefined;
        const op = command.type === 'indent' ? sinkListItem : liftListItem;
        if (!op(schema.nodes.list_item)(working, next => {changed = next;})) return false;
        tr = changed!;
        structural = true;
        break;
      }
      case 'duplicate': {
        if (parent.type !== schema.nodes.doc && node.type !== schema.nodes.list_item) return false;
        const cloned = clone(node);
        tr.insert(pos + node.nodeSize, cloned);
        structural = true;
        break;
      }
      case 'delete':
        if (parent.type === schema.nodes.doc) {
          tr.delete(pos, pos + node.nodeSize);
        } else if (node.type === schema.nodes.list_item) {
          if (parent.childCount === 1) {
            // Removing the last item owns its wrapper, never an invalid empty list.
            tr.delete(parentPos, parentPos + parent.nodeSize);
          } else tr.delete(pos, pos + node.nodeSize);
        } else return false;
        structural = true;
        break;
      case 'move': {
        const target = this.resolve(command.target);
        if (!target || target.parent !== parent || target.node === node
            || (parent.type !== schema.nodes.doc && node.type !== schema.nodes.list_item)) return false;
        const children: PMNode[] = [];
        parent.forEach(child => {if (child !== node) children.push(child);});
        const targetIndex = children.indexOf(target.node) + (command.after ? 1 : 0);
        children.splice(targetIndex, 0, node);
        tr.replaceWith(parentPos + 1, parentPos + 1 + parent.content.size, Fragment.from(children));
        restoreSelection(this.#state, tr);
        structural = true;
        break;
      }
      default: return false;
    }
    if (structural) normalize(tr, this.doc, eol);
    if (tr.doc.eq(this.doc)) return true;
    this.apply(tr);
    return true;
  }
}

function normalize(tr: Transaction, previous: PMNode, eol: string) {
  const seen = new Set<string>();
  tr.doc.descendants((node, pos) => {
    if (!('id' in node.attrs)) return;
    let attrs = node.attrs;
    if (!attrs.id || seen.has(attrs.id)) {
      attrs = {...attrs, id: randomID(), source: null,
        ...('taskOffset' in attrs ? {taskOffset: null, checked: attrs.checked == null ? null : false} : {})};
      tr.setNodeMarkup(pos, undefined, attrs);
    }
    seen.add(attrs.id);
  });
  const edges = new Map<string, {type: string; previous: string | null}>();
  let previousId: string | null = null;
  previous.forEach(node => {
    edges.set(node.attrs.id, {type: node.type.name, previous: previousId});
    previousId = node.attrs.id;
  });
  let previousNode: PMNode | undefined;
  tr.doc.forEach((node, pos, index) => {
    const lexicalBefore = node.attrs.source ? node.attrs.before : node.attrs.before.replace(/\r\n|\r|\n/g, eol);
    const old = edges.get(node.attrs.id);
    const sameEdge = old?.type === node.type.name && old.previous === previousNode?.attrs.id
      && edges.get(previousNode!.attrs.id)?.type === previousNode!.type.name;
    const before = index === 0 ? previous.firstChild!.attrs.before
      : (!sameEdge && !/\n[\t ]*\n/.test(lexicalBefore.replace(/\r\n|\r/g, '\n')))
        ? eol + eol : lexicalBefore || eol + eol;
    if (before !== node.attrs.before) tr.setNodeMarkup(pos, undefined, {...node.attrs, before});
    previousNode = node;
  });
}
function clone(node: PMNode): PMNode {
  if (node.isText) return node;
  const children: PMNode[] = [];
  node.forEach(child => children.push(clone(child)));
  const attrs = {...node.attrs};
  if ('id' in attrs) Object.assign(attrs, {id: randomID(), source: null, before: '\n\n'});
  if ('taskOffset' in attrs) attrs.taskOffset = null;
  return node.type.create(attrs, children, node.marks);
}
function validOffset(node: PMNode, offset: number) {
  if (!Number.isInteger(offset) || offset < 0 || offset > node.content.size) return false;
  // A programmatic edit must never cut an emoji's UTF-16 surrogate pair.
  const text = node.textBetween(0, node.content.size, '', '\uFFFC');
  return !(offset > 0 && /[\uD800-\uDBFF]/.test(text[offset - 1]) && /[\uDC00-\uDFFF]/.test(text[offset] ?? ''));
}
function hasBreak(node: PMNode) {
  let found = false;
  node.forEach(child => {if (['soft_break', 'hard_break'].includes(child.type.name)) found = true;});
  return found;
}
function restoreSelection(state: EditorState, tr: Transaction) {
  const { $anchor, $head } = state.selection;
  let anchor: number | undefined, head: number | undefined;
  tr.doc.descendants((node, pos) => {
    if (node.isTextblock && node.attrs.id === $anchor.parent.attrs.id) anchor = pos + 1 + $anchor.parentOffset;
    if (node.isTextblock && node.attrs.id === $head.parent.attrs.id) head = pos + 1 + $head.parentOffset;
  });
  if (anchor !== undefined && head !== undefined) tr.setSelection(TextSelection.create(tr.doc, anchor, head));
}
