import {Mark, type Node as PMNode} from '@tiptap/pm/model';
import {toMarkdown, type Options as MarkdownOptions} from 'mdast-util-to-markdown';
import {gfmToMarkdown} from 'mdast-util-gfm';
import type {Nodes, PhrasingContent} from 'mdast';
import {importMarkdown, type ImportedDocument, type SourceSpan} from './importer.ts';
import {schema} from './schema.ts';

// Inline content is compared and written through one normalized leaf list.
// Whitespace and line breaks have no visible bold/italic state, and Markdown
// cannot place them at the inner edge of `**…**`. They take strong/em only when
// both neighbours carry it; a line break joins a link only between its halves.
interface Leaf {
  kind: 'text' | 'space' | 'break' | 'atom';
  node: PMNode;
  text: string;
  marks: readonly Mark[];
}
const flowing = (mark: Mark) => mark.type.name === 'strong' || mark.type.name === 'em';
const has = (leaf: Leaf | undefined, mark: Mark) => !!leaf && leaf.marks.some(m => m.eq(mark));
// A wrapper never starts or ends on these: the mark is derived from neighbours.
const neutral = (leaf: Leaf, mark: Mark) => leaf.kind === 'break' || (leaf.kind === 'space' && flowing(mark));
const literalAutolink = (link: Mark, text: string) => link.attrs.title == null
  && [text, 'http://' + text, 'mailto:' + text].includes(link.attrs.href);

function leaves(parent: PMNode): Leaf[] {
  const list: Leaf[] = [];
  parent.forEach(node => {
    if (node.type.name === 'soft_break' || node.type.name === 'hard_break') {
      list.push({kind: 'break', node, text: '', marks: Mark.none});
    } else if (!node.isText || node.marks.some(m => m.type.name === 'code')) {
      list.push({kind: 'atom', node, text: node.text ?? '', marks: node.marks});
    } else {
      const [, lead, body, trail] = /^([ \t]*)([\s\S]*?)([ \t]*)$/.exec(node.text!)!;
      if (lead) list.push({kind: 'space', node, text: lead, marks: node.marks});
      if (body) list.push({kind: 'text', node, text: body, marks: node.marks});
      if (trail) list.push({kind: 'space', node, text: trail, marks: node.marks});
    }
  });
  // Markdown has no line break at the end of a text block; a trailing one is
  // not stored.
  while (list[list.length - 1]?.kind === 'break') list.pop();
  const solid = (leaf: Leaf) => leaf.kind === 'text' || leaf.kind === 'atom';
  const previous: (Leaf | undefined)[] = [];
  let last: Leaf | undefined;
  for (const leaf of list) {previous.push(last); if (solid(leaf)) last = leaf;}
  let next: Leaf | undefined;
  for (let i = list.length - 1; i >= 0; i--) {
    const leaf = list[i], before = previous[i];
    if (solid(leaf)) {next = leaf; continue;}
    const shared = (before?.marks ?? []).filter(m => has(next, m)
      && (flowing(m) || (leaf.kind === 'break' && m.type.name === 'link')));
    const own = leaf.kind === 'space' ? leaf.marks.filter(m => !flowing(m)) : [];
    leaf.marks = [...own, ...shared].reduce((set, m) => m.addToSet(set), Mark.none);
  }
  return list;
}

// Semantic comparison intentionally omits session identity and lexical metadata.
// It still compares list grouping, marks, soft/hard breaks and protected source.
export function semantics(node: PMNode): unknown {return meaning(node, {blocks: 0, links: []});}

// GFM links any text that reads as a URL or an address, escaped or not
// (mdast-util-gfm-autolink-literal), so unlinked URL text cannot be stored.
// Such a link adds nothing to its text: the tree compares it as plain text and
// `links` records where each one sits, so a written link is never lost or moved.
interface Meaning {blocks: number; links: string[]}
function meaning(node: PMNode, context: Meaning): unknown {
  const {id, source, before, taskOffset, tail, bom, ...attrs} = node.attrs;
  if (node.isTextblock && !node.type.spec.code) {
    type Item = {text: string; marks: readonly Mark[]} | {type: string; attrs: unknown; text?: string; marks: unknown[]};
    const block = context.blocks++;
    const items: Item[] = [];
    const add = (text: string, marks: readonly Mark[]) => {
      const last = items[items.length - 1];
      if (last && !('type' in last) && Mark.sameSet(last.marks, marks)) last.text += text;
      else items.push({text, marks});
    };
    for (const leaf of leaves(node)) {
      if (leaf.kind === 'text' || leaf.kind === 'space') add(leaf.text, leaf.marks);
      else items.push({type: leaf.node.type.name, attrs: leaf.node.attrs, text: leaf.node.text,
        marks: leaf.kind === 'break' ? [] : leaf.marks.map(m => m.toJSON())});
    }
    let offset = 0;
    for (const item of items.splice(0)) {
      if ('type' in item) {items.push(item); offset++; continue;}
      const link = item.marks.find(m => m.type.name === 'link');
      if (link && literalAutolink(link, item.text)) {
        context.links.push(JSON.stringify([block, offset, item.text, link.attrs.href]));
        add(item.text, link.removeFromSet(item.marks));
      } else add(item.text, item.marks);
      offset += item.text.length;
    }
    return {type: node.type.name, attrs, children: items.map(item =>
      'type' in item ? item : {type: 'text', text: item.text, marks: item.marks.map(m => m.toJSON())})};
  }
  const children: unknown[] = [];
  node.forEach(n => {
    // Empty top-level paragraphs are stored as gaps (IMPLEMENTATION_PLAN.md,
    // F5 preservation contract); their identity cannot round-trip through Markdown.
    // One that holds only a line break is just as empty once written.
    if (node.type.name === 'doc' && n.type.name === 'paragraph' && !leaves(n).length) return;
    children.push(meaning(n, context));
  });
  if (node.type.name === 'doc' && !children.length) {
    children.push({type: 'paragraph', attrs: {}, children: []});
  }
  return {type: node.type.name, attrs, text: node.text,
    marks: node.marks.map(m => m.toJSON()), children};
}

function checkedPatches(old: PMNode, next: PMNode, patches: {at: number; value: string}[]): boolean {
  if (old.type !== next.type || old.text !== next.text || old.childCount !== next.childCount
      || !Mark.sameSet(old.marks, next.marks)) return false;
  const {checked: oldChecked, before: oldBefore, ...oldAttrs} = old.attrs;
  const {checked: newChecked, before: newBefore, ...newAttrs} = next.attrs;
  if (JSON.stringify(oldAttrs) !== JSON.stringify(newAttrs)) return false;
  if (oldChecked !== newChecked) {
    if (old.type.name !== 'list_item' || oldChecked == null || newChecked == null
        || !Number.isInteger(old.attrs.taskOffset)) return false;
    patches.push({at: old.attrs.taskOffset, value: newChecked ? 'x' : ' '});
  }
  for (let i = 0; i < old.childCount; i++) if (!checkedPatches(old.child(i), next.child(i), patches)) return false;
  return true;
}

// Changed inline content is written by mdast-util-to-markdown, the counterpart
// of the parser in importer.ts. It owns escaping, delimiter runs, autolinks and
// link destinations; this file owns block scaffolding and source reuse.
interface InlineStyle {emphasis: '*' | '_'; strong: '*' | '_'; escapes: 'light' | 'strict'}
// serialize() tries these in order until the round-trip check accepts one.
// 'light' writes text the way people type it: URL text and literal autolinks
// bare, and `&`, `~`, `[` and `$` unescaped. Those are syntax only in certain
// surroundings (an entity, a closing `~`, a link target, a second `$`), and
// the round-trip check is what detects such surroundings. 'strict' then
// escapes everything the library considers unsafe and writes links as `<url>`.
// The library already alternates `*` and `_` around adjacent runs; the
// remaining styles are a last resort for overlaps of bold and italic.
const styles: InlineStyle[] = [
  {emphasis: '*', strong: '*', escapes: 'light'}, {emphasis: '*', strong: '*', escapes: 'strict'},
  {emphasis: '_', strong: '*', escapes: 'strict'}, {emphasis: '*', strong: '_', escapes: 'strict'},
  {emphasis: '_', strong: '_', escapes: 'strict'},
];
const reference = (text: string) => Array.from(text, c => `&#x${c.charCodeAt(0).toString(16).toUpperCase()};`).join('');
const bloctMarkdown = {
  // Bloct reads `$…$` and `$$…$$` as math (math-syntax.ts).
  unsafe: [{character: '$', inConstruct: 'phrasing' as const}],
  handlers: {
    bloctMath: (node: {value: string; display: boolean}) => {
      const delimiter = node.display ? '$$' : '$';
      return delimiter + node.value + delimiter;
    },
    bloctRaw: (node: {value: string}) => node.value,
  },
};
const gfmExtensions = gfmToMarkdown().extensions ?? [];
// The importer links URL-like text even when it is escaped
// (mdast-util-gfm-autolink-literal), so 'light' leaves those escapes out.
const withoutAutolinkEscapes = gfmExtensions
  .filter(extension => !extension.unsafe?.some(pattern => pattern.character === '@'));
// Removes the backslash the library put before `&`, `~`, `[` and `$`. A
// backslash that is itself escaped (an even run before it) stays, and so does
// the one before a complete character reference.
const lightText: MarkdownOptions = {handlers: {text: (node, _, state, info) =>
  state.safe(node.value, info).replace(/(\\*)\\([&~[$])/g, (match, slashes: string, character: string, at: number, whole: string) =>
    slashes.length % 2 || (character === '&' && /^#?[A-Za-z0-9]+;/.test(whole.slice(at + match.length)))
      ? match : slashes + character)}};
// The parser starts a `www.` autolink before markup too (`www.[a](b)`), which
// the library's own pattern does not cover.
const wwwEscape: MarkdownOptions = {unsafe: [{character: '.', before: '[Ww][Ww][Ww]',
  inConstruct: 'phrasing', notInConstruct: ['autolink', 'link', 'image', 'label']}]};
const markdownOptions = new Map<string, MarkdownOptions>();
function render(node: unknown, style: InlineStyle): string {
  const key = style.emphasis + style.strong + style.escapes;
  let options = markdownOptions.get(key);
  if (!options) markdownOptions.set(key, options = {
    emphasis: style.emphasis, strong: style.strong,
    extensions: [...(style.escapes === 'light' ? [...withoutAutolinkEscapes, lightText] : [...gfmExtensions, wwwEscape]),
      bloctMarkdown as unknown as MarkdownOptions],
  });
  return toMarkdown(node as Nodes, options).replace(/\n$/, '');
}

const wrapRank = ['link', 'strong', 'em'];
function phrasing(list: Leaf[], from: number, to: number, active: readonly Mark[], style: InlineStyle, source: string): PhrasingContent[] {
  const output: unknown[] = [];
  const text = (value: string) => {
    const last = output[output.length - 1] as {type: string; value: string} | undefined;
    if (last?.type === 'text') last.value += value; else output.push({type: 'text', value});
  };
  for (let i = from; i < to;) {
    const leaf = list[i];
    const pending = leaf.marks.filter(m => wrapRank.includes(m.type.name) && !neutral(leaf, m) && !active.some(a => a.eq(m)));
    if (pending.length) {
      // The mark that continues furthest becomes the outer wrapper.
      let outer = pending[0], end = i;
      for (const mark of pending) {
        let stop = i + 1;
        while (stop < to && has(list[stop], mark)) stop++;
        while (neutral(list[stop - 1], mark)) stop--;
        if (stop > end || (stop === end && wrapRank.indexOf(mark.type.name) < wrapRank.indexOf(outer.type.name))) {
          outer = mark; end = stop;
        }
      }
      const children = phrasing(list, i, end, [...active, outer], style, source) as unknown as {type: string; value: string}[];
      if (outer.type.name !== 'link') output.push({type: outer.type.name === 'strong' ? 'strong' : 'emphasis', children});
      // An autolink the author wrote as `<url>` keeps that form.
      else if (style.escapes === 'light' && children.length === 1 && children[0].type === 'text'
          && literalAutolink(outer, children[0].value) && !source.includes(`<${children[0].value}>`)) text(children[0].value);
      else output.push({type: 'link', url: outer.attrs.href, title: outer.attrs.title, children});
      i = end;
      continue;
    }
    const {node} = leaf;
    if (leaf.kind === 'text' || leaf.kind === 'space') text(leaf.text);
    else if (node.type.name === 'soft_break') text('\n');
    else if (node.type.name === 'hard_break') output.push({type: 'break'});
    else if (node.isText) output.push({type: 'inlineCode', value: leaf.text});
    else if (node.type.name === 'inline_math') output.push({type: 'bloctMath', value: node.attrs.value, display: node.attrs.display});
    else if (node.type.name === 'inline_image') output.push(imageNode(node.attrs));
    else throw new Error(`Unsupported inline node: ${node.type.name}`);
    i++;
  }
  return output as PhrasingContent[];
}
const imageNode = (attrs: PMNode['attrs']) => ({type: 'image', url: attrs.src, alt: attrs.alt, title: attrs.title});

// `source` is the text block's original Markdown, or '' for a new block.
function inline(node: PMNode, style: InlineStyle, source: string, container: 'paragraph' | 'heading' | 'tableCell' = 'paragraph'): string {
  const list = leaves(node);
  if (!list.length) return '';
  const children = phrasing(list, 0, list.length, [], style, source) as unknown as {type: string; value: string}[];
  if (container === 'tableCell') {
    // A cell is trimmed when read. Keep its outer whitespace as references.
    const first = children[0], last = children[children.length - 1];
    const lead = first.type === 'text' ? /^[ \t]/.exec(first.value)?.[0] : undefined;
    if (lead) {first.value = first.value.slice(1); children.unshift({type: 'bloctRaw', value: reference(lead)});}
    const trail = last.type === 'text' ? /[ \t]$/.exec(last.value)?.[0] : undefined;
    if (trail) {last.value = last.value.slice(0, -1); children.push({type: 'bloctRaw', value: reference(trail)});}
  }
  return render(container === 'heading' ? {type: 'heading', depth: node.attrs.level, children}
    : {type: container, children}, style);
}
export function imageBlockMarkdown(attrs: PMNode['attrs']) {
  return render({type: 'paragraph', children: [imageNode(attrs)]}, styles[0])
    + (attrs.imageAttrs ? `{${attrs.imageAttrs}}` : '')
    + (attrs.caption ? `\n*[${attrs.caption}]*` : '');
}

export function serialize(imported: ImportedDocument, doc: PMNode, verify = true): string {
  if (doc.eq(imported.doc)) return imported.original;
  if (!verify) return write(imported, doc, (_, text) => text(styles[0]));
  const read = (node: PMNode) => {
    const context: Meaning = {blocks: 0, links: []};
    return {tree: JSON.stringify(meaning(node, context)), links: context.links};
  };
  const accepts = (expected: ReturnType<typeof read>, markdown: string) => {
    const actual = read(importMarkdown(markdown).doc);
    return actual.tree === expected.tree && expected.links.every(link => actual.links.includes(link));
  };
  // Each changed top-level block takes the first style that reads back on its
  // own, so one block that needs strict escaping does not change the others.
  const output = write(imported, doc, (node, text) => {
    const expected = read(schema.nodes.doc.create(null, node));
    const tried: string[] = [];
    for (const style of styles) {
      const candidate = text(style);
      if (tried.includes(candidate)) continue;
      if (accepts(expected, candidate)) return candidate;
      tried.push(candidate);
    }
    return tried[0];
  });
  const expected = read(doc);
  if (accepts(expected, output)) return output;
  // Neighbouring blocks without a blank line between them are parsed together.
  for (const style of styles) {
    const whole = write(imported, doc, (_, text) => text(style));
    if (whole !== output && accepts(expected, whole)) return whole;
  }
  throw new Error('Markdown round-trip would change document structure; draft preserved');
}

// `choose` receives a changed top-level block and a function that writes it
// in a given style, and returns the text to store.
function write(imported: ImportedDocument, doc: PMNode,
    choose: (node: PMNode, text: (style: InlineStyle) => string) => string): string {
  const eol = /\r\n|\r|\n/.exec(imported.original)?.[0] ?? '\n';

  function reused(node: PMNode): string | undefined {
    const old = imported.blocks.get(node.attrs.id);
    const span = old?.attrs.source as SourceSpan | undefined;
    if (!old || !span) return;
    const patches: {at: number; value: string}[] = [];
    if (!checkedPatches(old, node, patches)) return;
    let raw = imported.original.slice(span.from, span.to);
    for (const patch of patches.sort((a, b) => b.at - a.at)) {
      if (patch.at < span.from || patch.at >= span.to
          || !/^\[[ xX]\]$/.test(imported.original.slice(patch.at - 1, patch.at + 2))) {
        throw new Error('Invalid archived task source position');
      }
      const offset = patch.at - span.from;
      raw = raw.slice(0, offset) + patch.value + raw.slice(offset + 1);
    }
    return raw;
  }

  const sourceOf = (node: PMNode) => {
    const span = imported.blocks.get(node.attrs.id)?.attrs.source as SourceSpan | undefined;
    return span ? imported.original.slice(span.from, span.to) : '';
  };

  // Only top-level immutable scopes are reused verbatim. Reindenting a container
  // invalidates its lexical child prefixes; serializing it cannot reuse those
  // source slices blindly. Checked-only changes use the exact patch path above.
  function block(node: PMNode, style: InlineStyle, nested = false): string {
    switch (node.type.name) {
      case 'paragraph': return inline(node, style, sourceOf(node));
      case 'heading': return inline(node, style, sourceOf(node), 'heading') || '#'.repeat(node.attrs.level) + ' ';
      case 'horizontal_rule': return '---';
      case 'raw_source':
        if (nested) throw new Error('Restructuring a container with protected raw source is not supported');
        return node.attrs.raw;
      case 'code_block': {
        const max = Math.max(2, ...Array.from(node.textContent.matchAll(/`+/g), m => m[0].length));
        const fence = '`'.repeat(max + 1);
        return `${fence}${node.attrs.language}\n${node.textContent}\n${fence}`;
      }
      case 'equation': return `$$\n${node.attrs.value}\n$$`;
      case 'image_block': return imageBlockMarkdown(node.attrs);
      case 'blockquote': {
        const contents: string[] = [];
        node.forEach(child => contents.push(block(child, style, true)));
        return contents.join('\n\n').split('\n').map(line => '> ' + line).join('\n');
      }
      case 'bullet_list': case 'ordered_list': {
        const items: string[] = [];
        node.forEach((item, _, index) => {
          const marker = node.type.name === 'ordered_list'
            ? `${node.attrs.start + index}${node.attrs.marker}` : node.attrs.marker;
          const old = imported.blocks.get(item.attrs.id);
          const oldChar = old?.attrs.taskOffset != null ? imported.original[old.attrs.taskOffset] : '';
          const taskChar = old?.attrs.checked === item.attrs.checked && /[ xX]/.test(oldChar)
            ? oldChar : item.attrs.checked ? 'x' : ' ';
          const prefix = marker + ' ' + (item.attrs.checked == null ? '' : `[${taskChar}] `);
          let text = inline(item.firstChild!, style, sourceOf(item.firstChild!));
          item.forEach((child, offset) => {
            if (offset) text += '\n' + block(child, style, true);
          });
          const lines = text.split('\n');
          items.push(prefix + lines[0] + lines.slice(1).map(line => '\n' + ' '.repeat(marker.length + 1) + line).join(''));
        });
        return items.join('\n');
      }
      case 'table': {
        const rows: string[] = [];
        node.forEach(row => {
          const cells: string[] = [];
          row.forEach(cell => cells.push(inline(cell, style, sourceOf(cell), 'tableCell')));
          rows.push('| ' + cells.join(' | ') + ' |');
        });
        const separators = Array.from({length: node.firstChild!.childCount}, (_, i) => {
          const align = node.attrs.align[i];
          return align === 'left' ? ':---' : align === 'right' ? '---:' : align === 'center' ? ':---:' : '---';
        });
        rows.splice(1, 0, '| ' + separators.join(' | ') + ' |');
        return rows.join('\n');
      }
      default: throw new Error(`Unsupported block node: ${node.type.name}`);
    }
  }

  let output: string = doc.attrs.bom;
  doc.forEach(node => {
    output += node.attrs.before;
    const raw = reused(node);
    output += raw ?? (node.type.name === 'raw_source' ? node.attrs.raw
      : choose(node, style => block(node, style)).replace(/\n/g, eol));
  });
  return output + doc.attrs.tail;
}
