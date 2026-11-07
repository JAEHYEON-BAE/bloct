import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {Node as PMNode} from '@tiptap/pm/model';
import {BlockSession, type BlockCommand} from '../src/session.ts';
import {importMarkdown} from '../src/importer.ts';
import {semantics} from '../src/serializer.ts';

function nodes(s: BlockSession, type: string) {
  const all: PMNode[] = [];
  s.doc.descendants(n => {if (n.type.name === type) all.push(n);});
  return all;
}
function execute(s: BlockSession, node: PMNode, command: BlockCommand) {
  assert.equal(s.execute(s.reference(node.attrs.id), command), true, command.type);
  s.doc.check();
  const ids: string[] = [];
  s.doc.descendants(n => {if (n.attrs.id) ids.push(n.attrs.id);});
  assert.equal(new Set(ids).size, ids.length, 'IDs must remain unique');
  const markdown = s.markdown();
  assert.deepEqual(semantics(importMarkdown(markdown).doc), semantics(s.doc));
  return markdown;
}
function oneCharacter(before: string, after: string) {
  assert.equal(before.length, after.length);
  const positions = Array.from({length: before.length}, (_, i) => i).filter(i => before[i] !== after[i]);
  assert.equal(positions.length, 1);
  assert.match(before.slice(positions[0] - 1, positions[0] + 2), /^\[[ xX]\]$/);
}

test('editing an image URL preserves caption Markdown, dimensions and unrelated source',()=>{
  const source='![image](old.png){width=64 align=center}\n*[Figure **caption**]*\n\nUnrelated **text**';
  const session=new BlockSession(source),image=session.doc.firstChild!;
  session.dispatch(session.state.tr.setNodeMarkup(0,undefined,{...image.attrs,src:'new.png'}));
  const snapshot=session.snapshot(),reopened=importMarkdown(snapshot.markdown).doc;
  assert.equal(reopened.firstChild!.attrs.src,'new.png');
  assert.equal(reopened.firstChild!.attrs.imageAttrs,'width=64 align=center');
  assert.equal(reopened.firstChild!.attrs.caption,'Figure **caption**');
  assert.ok(snapshot.markdown.endsWith('Unrelated **text**'));
  assert.deepEqual(semantics(reopened),semantics(session.doc));
  assert.equal(session.undo(),true);
  assert.equal(session.markdown(),source);
});

test('B10: paragraph split/join preserve identity, selection, source and history', () => {
  const source = '__untouched__\n\n한글😀문장\n\n~~~js\nx\n~~~~\n';
  const s = new BlockSession(source);
  const original = s.doc;
  const paragraph = nodes(s, 'paragraph')[1];
  s.setSelection(s.reference(paragraph.attrs.id), 4);
  const selection = s.selection;
  execute(s, paragraph, {type: 'split', offset: 4});
  const parts = nodes(s, 'paragraph');
  assert.equal(parts[1].attrs.id, paragraph.attrs.id);
  assert.notEqual(parts[2].attrs.id, paragraph.attrs.id);
  assert.match(s.markdown(), /^__untouched__\n\n/);
  assert.match(s.markdown(), /~~~js\nx\n~~~~\n$/);
  const split = s.doc;
  assert.equal(s.undo(), true);
  assert.ok(s.doc.eq(original));
  assert.deepEqual(s.selection, selection);
  assert.equal(s.dirty, false);
  assert.equal(s.redo(), true);
  assert.ok(s.doc.eq(split));
  execute(s, nodes(s, 'paragraph')[2], {type: 'join'});
  assert.equal(nodes(s, 'paragraph')[1].attrs.id, paragraph.attrs.id);
  assert.equal(s.markdown(), source);
});

test('B10: list split, indent and outdent use real schema-list transactions', () => {
  const source = '- [X] alpha\n- [ ] beta\n\n1. separate';
  const s = new BlockSession(source);
  const original = s.doc;
  const beta = nodes(s, 'list_item')[1];
  execute(s, beta, {type: 'indent'});
  assert.equal(nodes(s, 'bullet_list').length, 2);
  assert.equal(nodes(s, 'list_item')[1].attrs.id, beta.attrs.id);
  execute(s, nodes(s, 'list_item')[1], {type: 'outdent'});
  assert.equal(nodes(s, 'bullet_list').length, 1);
  assert.equal(nodes(s, 'ordered_list')[0].attrs.start, 1);
  assert.ok(s.undo()); assert.ok(s.undo());
  assert.ok(s.doc.eq(original));
  assert.equal(s.markdown(), source);
  const alpha = nodes(s, 'paragraph')[0];
  execute(s, alpha, {type: 'split', offset: 2});
  const items = nodes(s, 'list_item');
  assert.deepEqual(items.map(n => n.attrs.checked), [true, false, false, null]);
  assert.equal(items[0].textContent, 'al');
  assert.equal(items[1].textContent, 'pha');
});

test('B10: duplicate allocates descendant IDs; move preserves them; delete restores on Undo', () => {
  const source = '# H\n\n- A\n  - child\n\nTail';
  const s = new BlockSession(source);
  const list = nodes(s, 'bullet_list')[0];
  const originalIds = [list.attrs.id, list.firstChild!.attrs.id, list.firstChild!.firstChild!.attrs.id];
  execute(s, list, {type: 'duplicate'});
  const duplicate = s.doc.child(2);
  assert.ok(!originalIds.includes(duplicate.attrs.id));
  assert.ok(!originalIds.includes(duplicate.firstChild!.attrs.id));
  execute(s, duplicate, {type: 'move', target: s.reference(s.doc.firstChild!.attrs.id)});
  assert.equal(s.doc.firstChild!.attrs.id, duplicate.attrs.id);
  const moved = s.doc;
  execute(s, s.doc.firstChild!, {type: 'delete'});
  assert.equal(s.undo(), true);
  assert.ok(s.doc.eq(moved));
  assert.equal(s.redo(), true);
  assert.ok(!nodes(s, 'bullet_list').some(n => n.attrs.id === duplicate.attrs.id));
});

test('B10: type conversion and empty heading preserve ID and are separate Undo steps', () => {
  const s = new BlockSession('');
  const id = s.doc.firstChild!.attrs.id;
  assert.equal(s.dirty, false);
  execute(s, s.doc.firstChild!, {type: 'setType', kind: 'heading', level: 2});
  assert.equal(s.markdown(), '## ');
  assert.equal(s.doc.firstChild!.attrs.id, id);
  assert.equal(s.dirty, true);
  execute(s, s.doc.firstChild!, {type: 'replaceText', from: 0, to: 0, text: '제목'});
  assert.ok(s.undo());
  assert.equal(s.markdown(), '## ');
  assert.ok(s.undo());
  assert.equal(s.markdown(), '');
  assert.equal(s.dirty, false);
});

test('B10: splitting at a heading start preserves heading identity and creates a paragraph before it', () => {
  const s = new BlockSession('## 제목');
  const id = s.doc.firstChild!.attrs.id;
  execute(s, s.doc.firstChild!, {type: 'split', offset: 0});
  assert.equal(s.doc.child(1).attrs.id, id);
  assert.equal(s.doc.firstChild!.type.name, 'paragraph');
});

test('B10: invalid positions, surrogate splits, parent cycles and unsupported merges fail without changes', () => {
  const s = new BlockSession('😀abc\n\n- A\n  - B\n\n```\ncode\n```');
  const original = s.doc;
  const p = s.doc.firstChild!;
  assert.equal(s.execute(s.reference(p.attrs.id), {type: 'split', offset: 1}), false);
  assert.equal(s.execute(s.reference(p.attrs.id), {type: 'replaceText', from: -1, to: 0, text: 'x'}), false);
  assert.equal(s.execute(s.reference(p.attrs.id), {type: 'replaceText', from: 0, to: 0, text: 'a\nb'}), false);
  const list = nodes(s, 'bullet_list')[0], child = nodes(s, 'list_item')[1];
  assert.equal(s.execute(s.reference(list.attrs.id), {type: 'move', target: s.reference(child.attrs.id)}), false);
  assert.equal(s.execute(s.reference(nodes(s, 'code_block')[0].attrs.id), {type: 'join'}), false);
  assert.ok(s.doc.eq(original));
  assert.equal(s.revision, 0);
});

test('B11: exact one-character task patch across duplicate, quoted, nested and CRLF cases', () => {
  const sources = [
    '- [ ] same\n- [X] same', '> 1. [ ] same\n>    - [X] same',
    '\uFEFF# 😀\r\n\r\n- [X] 한글  \r\n  - [ ] 한글\r\n',
    '![i](a){width=20%}\n\n- [ ] same\n\n$$\nx\n\n y\n$$',
  ];
  for (const source of sources) {
    const s = new BlockSession(source);
    for (const id of nodes(s, 'list_item').map(n => n.attrs.id)) {
      const current = nodes(s, 'list_item').find(n => n.attrs.id === id)!;
      const before = s.markdown();
      const after = execute(s, current, {type: 'setChecked', checked: !current.attrs.checked});
      oneCharacter(before, after);
      assert.ok(s.undo());
      assert.equal(s.markdown(), before);
      assert.ok(s.redo());
      assert.equal(s.markdown(), after);
    }
  }
});

test('B11: line-count changes before a task rebase by tree identity, not an old source offset', () => {
  const s = new BlockSession('- [ ] alpha\n- [X] duplicate\n- [ ] duplicate\n\n__tail__');
  const targetId = nodes(s, 'list_item')[2].attrs.id;
  const stale = s.reference(targetId);
  execute(s, nodes(s, 'paragraph')[0], {type: 'split', offset: 2});
  const before = s.markdown();
  assert.equal(s.execute(stale, {type: 'setChecked', checked: true}), false);
  const target = nodes(s, 'list_item').find(n => n.attrs.id === targetId)!;
  const after = execute(s, target, {type: 'setChecked', checked: true});
  oneCharacter(before, after);
  assert.match(after, /- \[x\] duplicate\n\n__tail__$/);
});

test('B11: forged, cross-session and old-generation references cannot edit', () => {
  const s = new BlockSession('- [ ] task');
  const ref = s.reference(nodes(s, 'list_item')[0].attrs.id);
  assert.equal(s.execute({...ref}, {type: 'setChecked', checked: true}), false);
  assert.equal(new BlockSession('- [ ] task').execute(ref, {type: 'setChecked', checked: true}), false);
  s.acceptExternal('- [ ] external');
  assert.equal(s.execute(ref, {type: 'setChecked', checked: true}), false);
  assert.equal(s.markdown(), '- [ ] external');
  assert.equal(s.undo(), false);
});

test('B12: selection alone, deleting the last block and Save snapshots track actual content', () => {
  const s = new BlockSession('A');
  s.setSelection(s.reference(s.doc.firstChild!.attrs.id), 1);
  assert.equal(s.dirty, false);
  execute(s, s.doc.firstChild!, {type: 'replaceText', from: 1, to: 1, text: 'B'});
  const snapshot = s.snapshot();
  execute(s, s.doc.firstChild!, {type: 'replaceText', from: 2, to: 2, text: 'C'});
  assert.ok(s.markSaved(snapshot));
  assert.equal(s.dirty, true);
  assert.ok(s.undo());
  assert.equal(s.dirty, false);
  execute(s, s.doc.firstChild!, {type: 'delete'});
  assert.equal(s.doc.childCount, 1);
  assert.equal(s.doc.firstChild!.type.name, 'paragraph');
  assert.equal(s.markdown(), '');
});

test('source-preserving serializer keeps unrelated lexical styles after text edits', () => {
  const source = '\uFEFF__strong__\r\n\r\neditable\r\n\r\n1) [X] old  \r\n\r\n<!-- raw -->\r\n';
  const s = new BlockSession(source);
  const after = execute(s, nodes(s, 'paragraph')[1], {type: 'replaceText', from: 8, to: 8, text: ' 한글😀'});
  assert.equal(after, source.replace('editable', 'editable 한글😀'));
  assert.ok(s.undo());
  assert.equal(s.markdown(), source);
});

test('B10: moving selected content preserves its relative cursor and raw CRLF source', () => {
  const s = new BlockSession('first\r\n\r\n__second__\r\n\r\n<!-- x\r\ny -->\r\n');
  const second = s.doc.child(1), first = s.doc.firstChild!;
  s.setSelection(s.reference(second.attrs.id), 3);
  execute(s, second, {type: 'move', target: s.reference(first.attrs.id)});
  assert.equal(s.selection.anchor, 4);
  assert.match(s.markdown(), /^__second__\r\n\r\nfirst\r\n\r\n<!-- x\r\ny -->\r\n$/);
  assert.ok(s.undo());
  assert.equal(s.selection.anchor, first.nodeSize + 4);
});

test('save acknowledgements reject forged, consumed, older and previous-generation snapshots', () => {
  const s = new BlockSession('A');
  const old = s.snapshot();
  execute(s, s.doc.firstChild!, {type: 'replaceText', from: 1, to: 1, text: 'B'});
  const current = s.snapshot();
  assert.equal(s.markSaved({...current, markdown: 'forged'}), false);
  assert.ok(s.markSaved(current));
  assert.equal(s.markSaved(current), false);
  assert.equal(s.markSaved(old), false);
  const previous = s.snapshot();
  s.acceptExternal('external');
  assert.equal(s.markSaved(previous), false);
  assert.equal(s.dirty, false);
});

test('B10: changed adjacency widens only the affected source boundary', () => {
  const s = new BlockSession('# H\nbody\n\n__unchanged__');
  execute(s, s.doc.firstChild!, {type: 'setType', kind: 'paragraph'});
  assert.equal(s.markdown(), 'H\n\nbody\n\n__unchanged__');
  assert.ok(s.undo());
  assert.equal(s.markdown(), '# H\nbody\n\n__unchanged__');
});

test('unsupported mixed-source restructuring fails closed and Undo retains the exact source', () => {
  const source = '- [text][external]\n\nTail';
  const s = new BlockSession(source);
  const paragraph = nodes(s, 'paragraph')[0];
  assert.ok(s.execute(s.reference(paragraph.attrs.id), {type: 'replaceText', from: 0, to: 0, text: 'new'}));
  assert.throws(() => s.snapshot(), /protected raw source/);
  assert.equal(s.dirty, true);
  assert.ok(s.undo());
  assert.equal(s.markdown(), source);
  assert.equal(s.dirty, false);
});


test('a mode handoff imports an unsaved draft against the disk baseline', () => {
  const source = '# Saved';
  const s = new BlockSession('# Draft', source);
  assert.equal(s.changed, true);
  assert.equal(s.dirty, true);
  assert.equal(s.markdown(), '# Draft');
  const snapshot = s.snapshot();
  s.dispatch(s.state.tr.insertText(' later', s.doc.content.size - 1));
  assert.equal(s.markSaved(snapshot), true);
  assert.equal(s.changed, true);
  assert.equal(s.markdown(), '# Draft later');
  s.undo();
  assert.equal(s.changed, false);
  assert.equal(s.markdown(), '# Draft');
  s.acceptExternal(source);
  assert.equal(s.changed, false);
  s.setSavedBaseline('# Other saved');
  assert.equal(s.changed, true);
  s.setSavedBaseline(source);
  assert.equal(s.changed, false);
});
