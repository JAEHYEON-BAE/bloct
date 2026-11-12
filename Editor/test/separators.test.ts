import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {Node as PMNode} from '@tiptap/pm/model';
import {BlockSession} from '../src/session.ts';
import {importMarkdown} from '../src/importer.ts';
import {schema} from '../src/schema.ts';
import {semantics} from '../src/serializer.ts';

// New neighbours get a blank line only where Markdown needs one to keep them
// apart (IMPLEMENTATION_PLAN.md, F5 contract 2).

function saved(s: BlockSession) {
  const markdown = s.markdown();
  assert.deepEqual(semantics(importMarkdown(markdown).doc), semantics(s.doc));
  return markdown;
}
// Enter at the end of the last block, as the editor's splitBlock does.
function enter(s: BlockSession) {
  s.dispatch(s.state.tr.split(s.doc.content.size - 1, 1, [{type: schema.nodes.paragraph}]));
}
function type(s: BlockSession, text: string) {
  s.dispatch(s.state.tr.insertText(text, s.doc.content.size - 1));
}
// A block as the editor creates it: no identity, source or separator yet.
function fresh(markdown: string) {
  const node = importMarkdown(markdown).doc.firstChild!;
  return node.type.create({...node.attrs, id: null, source: null, before: ''}, node.content);
}
function append(s: BlockSession, ...blocks: PMNode[]) {
  s.dispatch(s.state.tr.insert(s.doc.content.size, blocks));
}

test('Enter after a heading writes the next line directly below it', () => {
  const s = new BlockSession('# Title');
  enter(s); type(s, 'Body');
  assert.equal(saved(s), '# Title\nBody');
  enter(s); type(s, 'More');
  assert.equal(saved(s), '# Title\nBody\n\nMore');
  while (s.undo());
  assert.equal(s.markdown(), '# Title');
});

test('a block typed under text is separated according to the type it becomes', () => {
  const made = (kind: (s: BlockSession, pos: number, node: PMNode) => void) => {
    const s = new BlockSession('Text');
    enter(s); type(s, 'x');
    const node = s.doc.lastChild!, pos = s.doc.content.size - node.nodeSize;
    assert.equal(node.attrs.before, '\n\n');
    kind(s, pos, node);
    return saved(s);
  };
  assert.equal(made((s, pos, node) => s.dispatch(
    s.state.tr.setNodeMarkup(pos, schema.nodes.heading, {...node.attrs, level: 2}))), 'Text\n## x');
  assert.equal(made((s, pos, node) => s.dispatch(s.state.tr.replaceWith(pos, pos + node.nodeSize,
    schema.nodes.bullet_list.create({before: node.attrs.before}, schema.nodes.list_item.create(node.attrs,
      schema.nodes.paragraph.create(null, node.content)))))), 'Text\n- x');
  assert.equal(made((s, pos, node) => s.dispatch(s.state.tr.replaceWith(pos, pos + node.nodeSize,
    schema.nodes.blockquote.create(node.attrs, schema.nodes.paragraph.create(null, node.content))))), 'Text\n> x');
  assert.equal(made((s, pos, node) => s.dispatch(
    s.state.tr.setNodeMarkup(pos, schema.nodes.code_block, {...node.attrs, language: ''}))), 'Text\n```\nx\n```');
  // `---` right under text would turn that text into a heading.
  assert.equal(made((s, pos, node) => s.dispatch(s.state.tr.replaceWith(pos, pos + node.nodeSize,
    schema.nodes.horizontal_rule.create(node.attrs)))), 'Text\n\n---');
});

const samples: Record<string, string> = {
  paragraph: 'text', heading: '## h', bullet_list: '- a\n- b', ordered_list: '1. a\n2. b',
  blockquote: '> q', code_block: '```\nc\n```', equation: '$$\nx\n$$', horizontal_rule: '---',
  table: '| a | b |\n| --- | --- |\n| c | d |', image_block: '![a](b.png)',
};
// Rows are the block above, columns the block below, in the order of `samples`.
const tight: Record<string, string> = {
  paragraph:       '.TTTTTT.T.',
  heading:         'TTTTTTTTTT',
  bullet_list:     '.T.TTTTT..',
  ordered_list:    '.TT.TTTT..',
  blockquote:      '.TTT.TTT..',
  code_block:      'TTTTTTTTTT',
  equation:        'TTTTTTTTTT',
  horizontal_rule: 'TTTTTTTTTT',
  table:           '.TTTTTTT..',
  image_block:     '.TTTTTT.T.',
};

test('every pair of new blocks is stored as tightly as it reads back', () => {
  const types = Object.keys(samples);
  for (const above of types) for (const [column, below] of types.entries()) {
    const s = new BlockSession('Start');
    append(s, fresh(samples[above]), fresh(samples[below]));
    const gap = tight[above][column] === 'T' ? '\n' : '\n\n';
    const head = 'Start' + (tight.paragraph[types.indexOf(above)] === 'T' ? '\n' : '\n\n');
    assert.equal(saved(s), head + samples[above] + gap + samples[below], `${above} → ${below}`);
    // A tight pair must merge nowhere; a separated pair must need its blank line.
    const joined = semantics(importMarkdown(samples[above] + '\n' + samples[below]).doc);
    const apart = semantics(importMarkdown(samples[above] + '\n\n' + samples[below]).doc);
    assert.equal(JSON.stringify(joined) === JSON.stringify(apart), gap === '\n', `${above} → ${below} policy`);
  }
});

test('a pair whose content would merge gets its blank line back, and only that pair', () => {
  for (const [list, written] of [['3. c', '3. c'], ['- ', '- ']]) {
    const s = new BlockSession('# Title');
    append(s, fresh('Text'), fresh(list), fresh('## Next'));
    assert.equal(s.doc.child(2).attrs.before, '\n');
    assert.equal(saved(s), `# Title\nText\n\n${written}\n## Next`);
  }
});

test('blank lines and tight lines already in the file stay as written', () => {
  const source = '# Title\nIntro\n\n\n## Part\n\n- a\n- b\n\nEnd\n';
  const s = new BlockSession(source);
  s.dispatch(s.state.tr.insertText('!', 13)); // after "Intro"
  assert.equal(saved(s), source.replace('Intro', 'Intro!'));
  // Changing the type of a block the file separated with blank lines keeps them.
  let pos = 0;
  s.doc.forEach((node, offset) => {if (node.textContent === 'Part') pos = offset;});
  s.dispatch(s.state.tr.setNodeMarkup(pos, schema.nodes.paragraph, {...s.doc.nodeAt(pos)!.attrs, level: undefined}));
  assert.equal(saved(s), source.replace('Intro', 'Intro!').replace('## Part', 'Part'));
});

test('a tight pair from the file is separated when an edit would merge it', () => {
  const s = new BlockSession('# Title\nBody');
  s.dispatch(s.state.tr.setNodeMarkup(0, schema.nodes.paragraph, {...s.doc.firstChild!.attrs, level: undefined}));
  assert.equal(saved(s), 'Title\n\nBody');
  assert.equal(s.undo(), true);
  assert.equal(s.markdown(), '# Title\nBody');
});

test('the opening Text line follows the same separator rule', () => {
  for (const [source, output] of [
    ['# Title', '# Title\nAfter'], ['# Title\n', '# Title\nAfter'], ['# Title\r\n', '# Title\r\nAfter'],
    ['# Title\n\n\n', '# Title\n\n\nAfter'], ['Text\n', 'Text\n\nAfter'], ['- a\n', '- a\n\nAfter'],
    ['```\nc\n```\n', '```\nc\n```\nAfter'],
  ]) {
    const s = new BlockSession(source, source, true);
    assert.equal(s.markdown(), source); assert.equal(s.changed, false);
    type(s, 'After');
    assert.equal(saved(s), output, JSON.stringify(source));
    assert.equal(s.undo(), true); assert.equal(s.markdown(), source);
  }
});

test('an empty line between new blocks is one blank line where Markdown allows it', () => {
  const s = new BlockSession('# Title');
  enter(s); enter(s); type(s, 'Body');
  assert.equal(saved(s), '# Title\n\n\nBody');
  const t = new BlockSession('# Title');
  enter(t); enter(t);
  t.dispatch(t.state.tr.setNodeMarkup(t.doc.content.size - 2, schema.nodes.heading, {...t.doc.lastChild!.attrs, level: 2}));
  type(t, 'Next');
  assert.equal(saved(t), '# Title\n\n## Next');
});
