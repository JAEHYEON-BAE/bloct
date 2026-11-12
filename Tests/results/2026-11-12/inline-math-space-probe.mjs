import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {importMarkdown} from '../../../Editor/src/model/importer.ts';
import {bloctMath} from '../../../Editor/src/model/math-syntax.ts';

const require = createRequire(new URL('../../../Editor/package.json', import.meta.url));
const {fromMarkdown} = await import(require.resolve('mdast-util-from-markdown'));
const {mathFromMarkdown} = await import(require.resolve('mdast-util-math'));
const {default: katex} = await import(require.resolve('katex'));
const value = String.raw`270{,}822 \text{ bps} \div 8 = 33{,}854 \text{ bps}`;
const cases = [
  ['both edge spaces', `$ ${value} $`, false],
  ['opening edge space', `$ ${value}$`, false],
  ['closing edge space', `$${value} $`, false],
  ['no edge spaces', `$${value}$`, true],
  ['internal spaces only', '$a + b$', true],
];
const results = cases.map(([name, source, expected]) => {
  const ast = fromMarkdown(source, {extensions: [bloctMath()], mdastExtensions: [mathFromMarkdown()]});
  const doc = importMarkdown(source).doc;
  const math = [];
  doc.descendants(node => {if (node.type.name === 'inline_math') math.push(node.attrs.value);});
  assert.equal(math.length > 0, expected, name);
  const parsed = ast.children[0].children[0];
  assert.equal(parsed.type, 'inlineMath', name);
  return {name, source, parserType: parsed.type, importedTypes: doc.firstChild.content.content.map(n => n.type.name), mathValues: math};
});
for (const tex of [value, ` ${value} `]) {
  const html = katex.renderToString(tex, {displayMode: false, throwOnError: true, trust: false, strict: 'error'});
  assert.ok(html.includes('class="katex"'));
}
console.log(JSON.stringify({date: '2026-11-12', scope: 'Current source importer and bundled KaTeX dependencies; no GUI or live typing test', results, katexWithAndWithoutEdgeSpaces: 'PASS'}, null, 2));
