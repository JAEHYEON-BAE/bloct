import {test} from 'node:test';
import assert from 'node:assert/strict';
import {BlockSession} from '../src/session.ts';
import {importMarkdown} from '../src/importer.ts';
import {schema} from '../src/schema.ts';
import {semantics} from '../src/serializer.ts';

// Seeded random inline content: Markdown punctuation, URL-like text, Korean,
// overlapping marks, links and inline atoms, placed in each kind of text block.
// Every draft must save and read back with the same meaning. Two things are
// left out because Markdown cannot hold them: a line break inside a heading or
// table cell, and a link address that starts with `<`.
const words = ['a', 'bold', '한글', '(영어)', 'x.', '"q"', ' ', ' ', ' ', '*', '_', '`', '[', ']', '(', ')', '!', '#',
  '-', '+', '.', '1.', '$', '~', '<', '>', '&amp;', '\\', '|', 'https://ex.com', 'www.ex.com', 'u@ex.com',
  'snake_case', ':', '=', '&', '^1'];
const bases = ['x\n', '# x\n', '- x\n', '> x\n', '| x | y |\n|---|---|\n| a | b |\n', '1. x\n   - y\n', '- [ ] x\n'];

for (const seed of [1, 2, 3]) {
  test(`random inline drafts save and read back (seed ${seed})`, () => {
    let state = seed;
    const random = () => (state = (state * 1664525 + 1013904223) >>> 0) / 2 ** 32;
    const pick = <T,>(list: T[]) => list[Math.floor(random() * list.length)];
    for (let round = 0; round < 700; round++) {
      const base = pick(bases);
      const s = new BlockSession(base, base, true);
      let pos = -1, size = 0;
      s.doc.descendants((node, at) => {if (pos < 0 && node.isTextblock) {pos = at + 1; size = node.content.size;}});
      const tr = s.state.tr.delete(pos, pos + size);
      let text = '';
      for (let i = 1 + Math.floor(random() * 7); i > 0; i--) text += pick(words);
      tr.insertText(text, pos);
      for (let i = Math.floor(random() * 4); i > 0; i--) {
        const a = Math.floor(random() * (text.length + 1)), b = Math.floor(random() * (text.length + 1));
        if (a === b) continue;
        const from = Math.min(a, b), to = Math.max(a, b);
        const kind = pick(['strong', 'em', 'code', 'link', 'strong', 'em']);
        const href = pick(['https://l.com', 'a b', 'x(y', text.slice(from, to)]).replace(/^</, 'lt');
        tr.addMark(pos + from, pos + to, kind === 'link'
          ? schema.marks.link.create({href, title: pick([null, null, 't "q"'])}) : schema.marks[kind].create());
      }
      if (random() < 0.2 && !/^[#|]/.test(base)) {
        tr.insert(pos + Math.floor(random() * (text.length + 1)), pick([schema.nodes.soft_break.create(),
          schema.nodes.hard_break.create(), schema.nodes.inline_math.create({value: 'x^2'}),
          schema.nodes.inline_image.create({src: 'a b.png', alt: 'al[t'})]));
      }
      try {s.dispatch(tr);} catch {continue;} // the schema rejected this combination
      let draft = '';
      s.doc.descendants(node => {if (!draft && node.isTextblock) draft = JSON.stringify(node.toJSON().content);});
      let markdown = '';
      assert.doesNotThrow(() => {markdown = s.markdown();}, `${JSON.stringify(base)} ${draft}`);
      assert.deepEqual(semantics(importMarkdown(markdown).doc), semantics(s.doc), draft);
    }
  });
}
