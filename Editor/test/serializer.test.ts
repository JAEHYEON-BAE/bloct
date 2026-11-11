import {test} from 'node:test';
import assert from 'node:assert/strict';
import type {Node as PMNode} from '@tiptap/pm/model';
import {BlockSession} from '../src/session.ts';
import {importMarkdown} from '../src/importer.ts';
import {schema} from '../src/schema.ts';
import {semantics} from '../src/serializer.ts';

// Position just inside the first text block, and its content size.
function firstText(s: BlockSession) {
  let found: {pos: number; node: PMNode} | undefined;
  s.doc.descendants((node, pos) => {if (!found && node.isTextblock) found = {pos: pos + 1, node};});
  return found!;
}
function saved(s: BlockSession) {
  const markdown = s.markdown();
  assert.deepEqual(semantics(importMarkdown(markdown).doc), semantics(s.doc), markdown);
  return markdown;
}
// Append one character to the first text block of existing Markdown.
function edited(source: string, text = 'Z') {
  const s = new BlockSession(source, source, true);
  const {pos, node} = firstText(s);
  s.dispatch(s.state.tr.insertText(text, pos + node.content.size));
  return saved(s);
}
// Type plain text into an empty document.
function typed(text: string) {
  const s = new BlockSession('', '', true);
  s.dispatch(s.state.tr.insertText(text, 1));
  return saved(s);
}
// Add a mark over [from, to) of the first text block.
function marked(source: string, from: number, to: number, mark: 'strong' | 'em' | 'code') {
  const s = new BlockSession(source, source, true);
  const {pos} = firstText(s);
  s.dispatch(s.state.tr.addMark(pos + from, pos + to, schema.marks[mark].create()));
  return saved(s);
}

test('ordinary punctuation is written as typed', () => {
  assert.equal(edited('e.g. version 1.0 (beta) - a+b! #tag\n'), 'e.g. version 1.0 (beta) - a+b! #tagZ\n');
  assert.equal(typed('snake_case and file_name.md'), 'snake_case and file_name.md');
  assert.equal(edited('## Release 1.0 (beta) #tag\n'), '## Release 1.0 (beta) #tagZ\n');
  assert.equal(edited('- **a** b\n- c (d)\n'), '- **a** bZ\n- c (d)\n');
});

test('characters are escaped only where they would start Markdown syntax', () => {
  assert.equal(typed('1. item'), '1\\. item');
  assert.equal(typed('- item'), '\\- item');
  assert.equal(typed('# heading'), '\\# heading');
  assert.equal(typed('2*3*4 and _x_'), '2\\*3\\*4 and \\_x\\_');
  assert.equal(typed('a <div> b <3 c'), 'a \\<div> b <3 c');
  assert.equal(typed('C:\\dir\\*file end\\'), 'C:\\dir\\\\\\*file end\\\\');
  // `&`, `~`, `[` and `$` are syntax only in certain surroundings.
  assert.equal(typed('R&D, Q&A and 10~20 or array[0] cost $5'), 'R&D, Q&A and 10~20 or array[0] cost $5');
  assert.equal(typed('use &nbsp; or &amp; here'), 'use \\&nbsp; or \\&amp; here');
  assert.equal(typed('a literal [link](target)'), 'a literal [link]\\(target)');
  assert.equal(typed('not math: $x$'), 'not math: \\$x\\$');
  assert.equal(typed('[label]: not-a-definition'), '\\[label]: not-a-definition');
  assert.equal(typed('~~~'), '\\~\\~\\~');
});

test('text the block parser keeps literal is written back unchanged', () => {
  // Strikethrough, footnotes and references to definitions in other blocks are
  // plain text to Bloct. Escaping them would break them for other renderers.
  assert.equal(edited('keep ~~old~~ text\n'), 'keep ~~old~~ textZ\n');
  assert.equal(edited('Text[^1] here.\n\n[^1]: note\n'), 'Text[^1] here.Z\n\n[^1]: note\n');
  assert.equal(edited('See [docs] for more.\n\n[docs]: https://example.com\n'), 'See [docs] for more.Z\n\n[docs]: https://example.com\n');
  assert.equal(edited('price $5 and $10\n'), 'price $5 and $10Z\n');
});

test('spaces beside formatting stay spaces', () => {
  assert.equal(edited('This is **bold** and *italic* text.\n'), 'This is **bold** and *italic* text.Z\n');
  // Bold applied to "word " (with its trailing space) closes before the space.
  assert.equal(marked('a word b\n', 2, 7, 'strong'), 'a **word** b\n');
  assert.equal(typed('  padded  '), '&#x20; padded &#x20;');
});

test('nested and overlapping formatting is written once and reads back', () => {
  assert.equal(edited('**bold *both* bold** tail\n'), '**bold *both* bold** tailZ\n');
  assert.equal(edited('**bold `code` more** tail\n'), '**bold `code` more** tailZ\n');
  assert.equal(edited('[**Bold** link](https://example.com) tail\n'), '[**Bold** link](https://example.com) tailZ\n');
  assert.equal(edited('**[Bold](https://example.com) x** tail\n'), '**[Bold](https://example.com) x** tailZ\n');
  assert.equal(edited('[`code` x](https://example.com) tail\n'), '[`code` x](https://example.com) tailZ\n');
  // Italic that starts inside bold and ends outside it cannot nest; it must still save.
  marked('**abc** def ghi\n', 2, 8, 'em');
  marked('**ab**cd\n', 1, 3, 'em');
});

test('formatting next to punctuation and Korean text still reads back as formatting', () => {
  // `**한글(영어)**은` is not bold in CommonMark. The letter after the closing
  // delimiter is written as a character reference so that it is.
  const output = marked('한글(영어)은 좋다\n', 0, 6, 'strong');
  assert.equal(output, '**한글(영어)**&#xC740; 좋다\n');
  const paragraph = importMarkdown(output).doc.firstChild!;
  assert.equal(paragraph.textContent, '한글(영어)은 좋다');
  assert.equal(paragraph.firstChild!.marks[0].type.name, 'strong');
});

test('URL and address text saves, and links keep the form they were written in', () => {
  assert.equal(typed('visit https://example.com now'), 'visit https://example.com now');
  assert.equal(typed('mail user@example.com now'), 'mail user@example.com now');
  assert.equal(typed('see www.example.com now'), 'see www.example.com now');
  assert.equal(edited('see https://example.com ok\n'), 'see https://example.com okZ\n');
  assert.equal(edited('see www.example.com ok\n'), 'see www.example.com okZ\n');
  assert.equal(edited('see <https://example.com> ok\n'), 'see <https://example.com> okZ\n');
  assert.equal(edited('[docs](https://example.com/a_b)\n'), '[docs](https://example.com/a_b)Z\n');
  assert.equal(edited('[a b](<x y.md> "t")\n'), '[a b](<x y.md> "t")Z\n');
});

test('a literal autolink is never widened by text typed against it', () => {
  // "b" typed directly after the link must not become part of its address.
  const source = 'https://example.com\n';
  const s = new BlockSession(source, source, true);
  const {pos, node} = firstText(s);
  s.dispatch(s.state.tr.insertText('b', pos + node.content.size));
  assert.equal(firstText(s).node.lastChild!.marks.length, 0);
  const output = saved(s);
  assert.equal(output, '<https://example.com>b\n');
  const reopened = importMarkdown(output).doc.firstChild!;
  assert.equal(reopened.firstChild!.marks[0].attrs.href, 'https://example.com');
  assert.equal(reopened.lastChild!.text, 'b');
});

test('a trailing line break and outer cell spaces do not block saving', () => {
  const s = new BlockSession('line\n', 'line\n', true);
  const {pos, node} = firstText(s);
  s.dispatch(s.state.tr.insert(pos + node.content.size, schema.nodes.hard_break.create()));
  assert.equal(saved(s), 'line\n');
  s.dispatch(s.state.tr.insertText('next', firstText(s).pos + firstText(s).node.content.size));
  assert.equal(saved(s), 'line\\\nnext\n');
  assert.equal(edited('| A | B |\n|---|---|\n| a | b |\n', ' '), '| A&#x20; | B |\n| --- | --- |\n| a | b |\n');
  assert.equal(edited('| a\\|b | `x\\|y` |\n|---|---|\n| c | d |\n'), '| a\\|bZ | `x\\|y` |\n| --- | --- |\n| c | d |\n');
});

test('a block that needs strict escaping does not change how other edited blocks are written', () => {
  const source = 'R&D costs\n\nsecond\n';
  const s = new BlockSession(source, source, true);
  const first = firstText(s);
  s.dispatch(s.state.tr.insertText(' $5', first.pos + first.node.content.size));
  const second = s.doc.child(1);
  let at = 0;
  s.doc.forEach((node, offset) => {if (node === second) at = offset + 1 + node.content.size;});
  s.dispatch(s.state.tr.insertText(' is $x$ literal', at));
  assert.equal(saved(s), 'R&D costs $5\n\nsecond is \\$x\\$ literal\n');
});

test('nested emphasis of one kind imports as a single mark', () => {
  for (const [source, text] of [['*a *b* c*', 'a b c'], ['**a **b** c**', 'a b c'], ['*a **b *c* d** e*', 'a b c d e']]) {
    const paragraph = importMarkdown(source).doc.firstChild!;
    paragraph.check();
    assert.equal(paragraph.textContent, text);
    new BlockSession(source, source, true);
  }
});
