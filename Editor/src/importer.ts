import {randomID} from './id.ts';
import {fromMarkdown} from 'mdast-util-from-markdown';
import {gfmFromMarkdown} from 'mdast-util-gfm';
import {gfm} from 'micromark-extension-gfm';
import {mathFromMarkdown} from 'mdast-util-math';
import {bloctMath} from './math-syntax.ts';
import type {Node as PMNode, Mark} from '@tiptap/pm/model';
import type {RootContent, PhrasingContent, Root} from 'mdast';
import {schema} from './schema.ts';

export interface SourceSpan {from: number; to: number}
export interface ImportedDocument {
  doc: PMNode;
  original: string;
  blocks: ReadonlyMap<string, PMNode>;
}

function parse(text: string): Root {
  return fromMarkdown(text, {
    extensions: [gfm(), bloctMath()],
    mdastExtensions: [gfmFromMarkdown(), mathFromMarkdown()],
  });
}

function walkAST(node: {type: string; children?: unknown[]}, visit: (n: typeof node) => void) {
  visit(node);
  for (const child of node.children ?? []) walkAST(child as typeof node, visit);
}

// Preserve CRLF, CR and BOM in the source archive. The parser works directly on
// the original string: mdast offsets and JS/ProseMirror strings use UTF-16.
function regions(text: string): SourceSpan[] {
  const protectedSpans: SourceSpan[] = [];
  walkAST(parse(text), node => {
    const n = node as RootContent;
    if ((n.type === 'code' || n.type === 'math') && n.position) {
      protectedSpans.push({from: n.position.start.offset!, to: n.position.end.offset!});
    }
  });
  const spans: SourceSpan[] = [];
  let start = 0;
  const lines = /[^\r\n]*(?:\r\n|\r|\n|$)/g;
  for (const match of text.matchAll(lines)) {
    const from = match.index;
    if (!match[0]) break;
    const body = match[0].replace(/(?:\r\n|\r|\n)$/, '');
    if (/^[\t ]*$/.test(body) && !protectedSpans.some(p => p.from < from && from < p.to)) {
      if (from > start) spans.push({from: start, to: from});
      start = from + match[0].length;
    }
  }
  if (start < text.length) spans.push({from: start, to: text.length});
  return spans;
}

export function importMarkdown(original: string): ImportedDocument {
  const bom = original.startsWith('\uFEFF') ? '\uFEFF' : '';
  const text = original.slice(bom.length);
  const id = () => randomID();
  const attrs = (n: {position?: RootContent['position']}, base: number, extra = {}) => ({
    id: id(), source: n.position ? {
      from: base + n.position.start.offset!, to: base + n.position.end.offset!,
    } : null, ...extra,
  });
  const raw = (n: {position?: RootContent['position']}, base: number) =>
    n.position ? original.slice(base + n.position.start.offset!, base + n.position.end.offset!) : '';

  function inline(nodes: PhrasingContent[], base: number, marks: readonly Mark[] = []): PMNode[] {
    return nodes.flatMap(n => {
      switch (n.type) {
        case 'text': {
          const pieces = n.value.split(/\r\n|\r|\n/);
          return pieces.flatMap((part, index) => [
            ...(index ? [schema.nodes.soft_break.create()] : []),
            ...(part ? [schema.text(part, marks)] : []),
          ]);
        }
        case 'strong': return inline(n.children, base, [...marks, schema.marks.strong.create()]);
        case 'emphasis': return inline(n.children, base, [...marks, schema.marks.em.create()]);
        case 'inlineCode': return n.value ? [schema.text(n.value, [...marks, schema.marks.code.create()])] : [];
        case 'break': return [schema.nodes.hard_break.create(null, null, marks)];
        case 'link': return inline(n.children, base, [...marks, schema.marks.link.create({href: n.url, title: n.title})]);
        case 'image': return [schema.nodes.inline_image.create({src: n.url, alt: n.alt ?? '', title: n.title}, null, marks)];
        case 'inlineMath': {
          // Currency/space-delimited fragments stay literal. Bloct's strike
          // policy is also intentionally not replaced by GFM's default mark.
          const source = raw(n, base);
          const display = source.startsWith('$$');
          const inner = source.replace(/^\$+|\$+$/g, '');
          if (!display && /^\s|\s$/.test(inner)) return [schema.text(source, marks)];
          return [schema.nodes.inline_math.create({value: display ? n.value.trim() : n.value, display}, null, marks)];
        }
        default: return raw(n, base) ? [schema.text(raw(n, base), marks)] : [];
      }
    });
  }

  function block(n: RootContent, base: number): PMNode {
    const a = attrs(n, base);
    const source = raw(n, base);
    switch (n.type) {
      case 'paragraph': {
        // A reference in another compatibility region is intentionally not
        // resolved (F4). Such syntax is plain text to an isolated parser.
        let unsupported = /(?<!\\)\[[^\]\r\n]+\]\[[^\]\r\n]*\]/.test(source);
        walkAST(n, child => {
          if (['html', 'linkReference', 'imageReference'].includes(child.type)) unsupported = true;
        });
        if (unsupported) return schema.nodes.raw_source.create({...a, raw: source, reason: 'mixed-or-reference'});
        const first = n.children[0];
        if (first?.type === 'image') {
          const suffix = original.slice(base + first.position!.end.offset!, a.source!.to);
          const extension = /^(?:\{([^}\r\n]+)\})?(?:\r?\n\*\[([^\]]*)\]\*)?$/.exec(suffix);
          if (extension) return schema.nodes.image_block.create({...a,
            src: first.url, alt: first.alt ?? '', title: first.title,
            imageAttrs: extension[1] ?? '', caption: extension[2] ?? '',
          });
        }
        return schema.nodes.paragraph.create(a, inline(n.children, base));
      }
      case 'heading': return schema.nodes.heading.create({...a, level: n.depth}, inline(n.children, base));
      case 'list': {
        const items = n.children.map(item => {
          const own = raw(item, base);
          const marker = /^(?:[-+*]|\d{1,9}[.)])[\t ]+\[([ xX])\](?=[\t \r\n]|$)/.exec(own);
          const emptyTask = marker && item.checked == null && own.slice(marker[0].length).trim() === '';
          const children = item.children.map(child => block(child as RootContent, base));
          if (emptyTask) children.splice(0, children.length, schema.nodes.paragraph.create({id:id()}));
          if (children[0]?.type !== schema.nodes.paragraph) children.unshift(schema.nodes.paragraph.create({id: id()}));
          return schema.nodes.list_item.create(attrs(item, base, {
            checked: emptyTask ? /[xX]/.test(marker![1]) : item.checked ?? null,
            taskOffset: marker ? base + item.position!.start.offset! + marker[0].lastIndexOf('[') + 1 : null,
          }), children);
        });
        return schema.nodes[n.ordered ? 'ordered_list' : 'bullet_list'].create({...a,
          ...(n.ordered ? {start: n.start ?? 1, marker: /^\d+([.)])/.exec(source)?.[1] ?? '.'}
            : {marker: source[0]}),
        }, items);
      }
      case 'blockquote': return schema.nodes.blockquote.create(a, n.children.length
        ? n.children.map(child => block(child as RootContent, base)) : [schema.nodes.paragraph.create({id:id()})]);
      case 'code': return schema.nodes.code_block.create({...a, language: n.lang ?? ''}, n.value ? schema.text(n.value) : null);
      case 'math': return schema.nodes.equation.create({...a, value: n.value});
      case 'thematicBreak': return schema.nodes.horizontal_rule.create(a);
      case 'table': return schema.nodes.table.create({...a, align: n.align ?? []}, n.children.map(row =>
        schema.nodes.table_row.create(attrs(row, base), row.children.map(cell =>
          schema.nodes.table_cell.create(attrs(cell, base), inline(cell.children, base))))));
      default: return schema.nodes.raw_source.create({...a, raw: source, reason: n.type});
    }
  }

  const children: PMNode[] = [];
  let cursor = bom.length;
  for (const region of regions(text)) {
    const base = region.from + bom.length;
    const tree = parse(text.slice(region.from, region.to));
    for (const n of tree.children) {
      const node = block(n, base);
      const span = node.attrs.source as SourceSpan;
      children.push(node.type.create({...node.attrs, before: original.slice(cursor, span.from)}, node.content));
      cursor = span.to;
    }
  }
  if (!children.length) children.push(schema.nodes.paragraph.create({id: id(), before: ''}));
  const doc = schema.nodes.doc.create({bom, tail: original.slice(cursor)}, children);
  doc.check();
  const blocks = new Map<string, PMNode>();
  doc.descendants(node => {if (node.attrs.id) blocks.set(node.attrs.id, node);});
  return {doc, original, blocks};
}

// Until the command/serializer layer is installed, modified trees must fail
// closed rather than silently returning the initial source.
export function exportUnchanged(imported: ImportedDocument, doc = imported.doc): string {
  if (!doc.eq(imported.doc)) throw new Error('Changed document requires the source-preserving serializer');
  return imported.original;
}
