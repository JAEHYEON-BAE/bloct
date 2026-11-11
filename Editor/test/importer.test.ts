import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import type {Node as PMNode} from '@tiptap/pm/model';
import {importMarkdown, type ImportedDocument} from '../src/importer.ts';
import {serialize} from '../src/serializer.ts';

function nodes(input: ImportedDocument | PMNode, type: string) {
  const found: PMNode[] = [];
  const doc = 'doc' in input ? input.doc : input;
  doc.descendants(n => {if (n.type.name === type) found.push(n);});
  return found;
}
function roundtrip(raw: string) {
  const imported = importMarkdown(raw);
  imported.doc.check();
  assert.equal(serialize(imported, imported.doc), raw);
  assert.deepEqual(importMarkdown(serialize(imported, imported.doc)).doc.toJSON().type, 'doc');
  for (const [id, node] of imported.blocks) {
    assert.match(id, /^[\da-f-]{36}$/);
    if (node.attrs.source) {
      const {from, to} = node.attrs.source;
      assert.ok(from >= 0 && to >= from && to <= raw.length, `${node.type.name} ${from}:${to}`);
    }
  }
  return imported;
}

test('B01: adjacent semantic blocks and independent list item IDs', () => {
  const source = '# H\n본문\n- A\n- B';
  const imported = roundtrip(source);
  assert.deepEqual(Array.from({length: imported.doc.childCount}, (_, i) => imported.doc.child(i).type.name),
    ['heading', 'paragraph', 'bullet_list']);
  const items = nodes(imported, 'list_item');
  assert.equal(items.length, 2);
  assert.notEqual(items[0].attrs.id, items[1].attrs.id);
  assert.deepEqual(items.map(n => n.textContent), ['A', 'B']);
  assert.deepEqual(items.map(n => source.slice(n.attrs.source.from, n.attrs.source.to)), ['- A', '- B']);
});

test('B02: physical soft lines and explicit hard breaks stay inside paragraphs', () => {
  for (const [source, type] of [['첫 줄\n둘째 줄', 'soft_break'], ['첫 줄\\\n둘째 줄', 'hard_break'], ['A  \nB', 'hard_break']]) {
    const imported = roundtrip(source);
    assert.equal(imported.doc.childCount, 1);
    assert.equal(nodes(imported, type).length, 1);
  }
});

test('B03: existing B/C policy fixture keeps list groups and separate indented code', () => {
  const fixture = readFileSync(new URL('../../Tests/fixtures/bug-16-block-context.md', import.meta.url), 'utf8');
  const imported = roundtrip(fixture);
  const ordered = nodes(imported, 'ordered_list');
  const continuous = ordered.find(n => n.firstChild!.textContent.startsWith('B-연속'))!;
  assert.equal(continuous.childCount, 3);
  assert.equal(continuous.attrs.start, 1);
  const separate = ordered.filter(n => n.firstChild!.textContent.startsWith('B-분리'));
  assert.equal(separate.length, 3);
  assert.ok(separate.every(n => n.childCount === 1 && n.attrs.start === 1 && /\n\n/.test(n.attrs.before)));
  assert.ok(nodes(imported, 'code_block').some(n => n.textContent.includes('C-분리 네 칸')));
  const continued = ordered.find(n => n.firstChild!.textContent.startsWith('C-연결'))!;
  assert.equal(continued.childCount, 2);
  assert.equal(nodes(continued, 'hard_break').length, 1);
});

test('B04: nested/quoted duplicate labels have exact parents and source spans', () => {
  const source = '- [ ] 중복\n  - [X] 중복\n\n> 1. [ ] 중복\n>    - [x] 중복';
  const imported = roundtrip(source);
  const items = nodes(imported, 'list_item');
  assert.equal(items.length, 4);
  assert.equal(new Set(items.map(n => n.attrs.id)).size, 4);
  assert.equal(nodes(imported.doc.child(0).firstChild!, 'bullet_list').length, 1);
  assert.equal(imported.doc.child(1).type.name, 'blockquote');
  assert.deepEqual(items.map(n => source[n.attrs.taskOffset]), [' ', 'X', ' ', 'x']);
});

test('B05: code protects blank lines, longer fences, unclosed fences and indented syntax', () => {
  const cases = [
    '```js\n## H\n\n![x](a){width=2}\n$$x$$\n````\n\ntail',
    '~~~~\n```\n\n- [ ] literal\n~~~~~',
    '```\n\n## still code\n\n$$x$$',
    '    ## literal\n    $$x$$\n    ![a](b)',
    '> ```\n> ## literal\n>\n> $$x$$\n> ```',
  ];
  for (const source of cases) {
    const imported = roundtrip(source);
    assert.equal(nodes(imported, 'code_block').length, 1, source);
    for (const type of ['heading', 'equation', 'inline_math', 'image_block', 'inline_image', 'list_item']) {
      assert.equal(nodes(imported, type).length, 0, `${type}: ${source}`);
    }
  }
});

test('B06: block math protects blanks; code and currency never become equations', () => {
  const imported = roundtrip('$$\na+b\n\nc+d\n$$\n\n가격 $5 와 $10 표기\n\n`$x$` 그리고 $x+1$');
  assert.equal(nodes(imported, 'equation').length, 1);
  assert.equal(nodes(imported, 'inline_math').length, 1);
  assert.ok(nodes(imported, 'paragraph').some(n => n.textContent.includes('$5 와 $10')));
  assert.equal(nodes(roundtrip('$$\na\n\nb'), 'equation').length, 1);
});

test('B07: Setext precedence, GFM table, inline images and block image metadata', () => {
  const source = '제목\n---\n\n---\n\n| A | B |\n| :- | -: |\n| a\\|b | **c** |\n\n앞 ![alt](../a.png) 뒤\n\n![alt](../b.png){width=50% align=center}\n*[캡션]*';
  const imported = roundtrip(source);
  assert.equal(nodes(imported, 'heading')[0].attrs.level, 2);
  assert.equal(nodes(imported, 'horizontal_rule').length, 1);
  assert.equal(nodes(imported, 'table_row').length, 2);
  assert.equal(nodes(imported, 'table_cell')[2].textContent, 'a|b');
  assert.equal(nodes(imported, 'inline_image').length, 1);
  const image = nodes(imported, 'image_block')[0];
  assert.equal(image.attrs.src, '../b.png');
  assert.equal(image.attrs.imageAttrs, 'width=50% align=center');
  assert.equal(image.attrs.caption, '캡션');
});

test('B08: HTML, comments and reference syntax are accessible protected source', () => {
  const source = '<div>\nraw\n\nhtml</div>\n\n<!-- comment -->\n\n[정의]: /url\n\n[text][정의]\n\n앞 <kbd>K</kbd> 뒤';
  const imported = roundtrip(source);
  const protectedNodes = nodes(imported, 'raw_source');
  assert.ok(protectedNodes.length >= 5);
  assert.ok(protectedNodes.some(n => n.attrs.raw === '[정의]: /url'));
  assert.ok(protectedNodes.some(n => n.attrs.raw === '[text][정의]'));
  assert.ok(protectedNodes.some(n => n.attrs.raw.includes('<kbd>')));
});

test('B09: BOM, CRLF, CR, tabs, spaces and UTF-16 positions survive import', () => {
  const source = '\uFEFF# 한글 😀 e\u0301\r\n\r\n\t코드\r\n\r\n- [X] 중복  \r\n- [ ] 중복\r\n';
  const imported = roundtrip(source);
  const item = nodes(imported, 'list_item')[0];
  assert.equal(item.attrs.taskOffset, source.indexOf('[X]') + 1);
  assert.equal(imported.doc.attrs.bom, '\uFEFF');
  assert.equal(source.slice(imported.doc.firstChild!.attrs.source.from, imported.doc.firstChild!.attrs.source.to), '# 한글 😀 e\u0301');
  roundtrip('# A\r\r- B\r');
});

test('B12: empty input, whitespace gaps, trailing newlines and empty headings', () => {
  for (const source of ['', '\uFEFF', '\n\n', ' \t\r\n', 'A\n\n\nB\n\n', '## ', '## \r\n']) roundtrip(source);
  const empty = roundtrip('');
  assert.equal(empty.doc.childCount, 1);
  assert.equal(empty.doc.firstChild!.textContent, '');
  assert.equal(empty.doc.firstChild!.attrs.source, null);
  assert.equal(roundtrip('## ').doc.firstChild!.type.name, 'heading');
  assert.equal(roundtrip('A\n\n\nB\n\n').doc.child(1).attrs.before, '\n\n\n');
});

test('a changed tree is serialized instead of returning the initial source', () => {
  const imported = importMarkdown('A');
  assert.equal(serialize(imported, importMarkdown('B').doc), 'B');
});
