import {Mark, type Node as PMNode} from '@tiptap/pm/model';
import {importMarkdown, type ImportedDocument, type SourceSpan} from './importer.ts';

// Semantic comparison intentionally omits session identity and lexical metadata.
// It still compares list grouping, marks, soft/hard breaks and protected source.
export function semantics(node: PMNode): unknown {
  const {id, source, before, taskOffset, tail, bom, ...attrs} = node.attrs;
  const children: unknown[] = [];
  node.forEach(n => {
    // Empty top-level paragraphs are stored as gaps (IMPLEMENTATION_PLAN.md,
    // F5 preservation contract); their identity cannot round-trip through Markdown.
    if (node.type.name === 'doc' && n.type.name === 'paragraph' && !n.content.size) return;
    children.push(semantics(n));
  });
  if (node.type.name === 'doc' && !children.length) {
    children.push({type: 'paragraph', attrs: {}, text: undefined, marks: [], children: []});
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

function escapeText(text: string) {
  return text.replace(/[\\$`*_[\]<>#!+\-.()|~]/g, '\\$&')
    .replace(/^[ \t]+|[ \t]+$/g, spaces => Array.from(spaces, c => c === '\t' ? '&#9;' : '&#32;').join(''));
}
function destination(url: string) {return `<${url.replace(/</g, '%3C').replace(/>/g, '%3E').replace(/\n/g, '%0A')}>`;}

function inline(node: PMNode): string {
  let output = '';
  node.forEach(child => {
    let value: string;
    if (child.isText) {
      const code = child.marks.some(m => m.type.name === 'code');
      if (code) {
        const longest = Math.max(0, ...Array.from(child.text!.matchAll(/`+/g), m => m[0].length));
        const fence = '`'.repeat(longest + 1);
        const pad = /^`|`$|^ .* $/.test(child.text!) ? ' ' : '';
        value = fence + pad + child.text! + pad + fence;
      } else value = escapeText(child.text!);
    } else if (child.type.name === 'soft_break') value = '\n';
    else if (child.type.name === 'hard_break') value = '\\\n';
    else if (child.type.name === 'inline_math') {
      const delimiter=child.attrs.display?'$$':'$';
      value=delimiter+child.attrs.value+delimiter;
    }
    else if (child.type.name === 'inline_image') value = image(child.attrs);
    else throw new Error(`Unsupported inline node: ${child.type.name}`);
    for (const mark of [...child.marks].reverse()) {
      if (mark.type.name === 'strong') value = `**${value}**`;
      if (mark.type.name === 'em') value = `*${value}*`;
      if (mark.type.name === 'link') value = `[${value}](${destination(mark.attrs.href)}${title(mark.attrs.title)})`;
    }
    output += value;
  });
  return output;
}
function title(value: string | null) {return value ? ` "${value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"` : '';}
function image(attrs: PMNode['attrs']) {return `![${escapeText(attrs.alt)}](${destination(attrs.src)}${title(attrs.title)})`;}
export function imageBlockMarkdown(attrs: PMNode['attrs']) {
  return image(attrs) + (attrs.imageAttrs ? `{${attrs.imageAttrs}}` : '')
    + (attrs.caption ? `\n*[${attrs.caption}]*` : '');
}

export function serialize(imported: ImportedDocument, doc: PMNode, verify = true): string {
  if (doc.eq(imported.doc)) return imported.original;
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

  // Only top-level immutable scopes are reused verbatim. Reindenting a container
  // invalidates its lexical child prefixes; serializing it cannot reuse those
  // source slices blindly. Checked-only changes use the exact patch path above.
  function block(node: PMNode, nested = false): string {
    switch (node.type.name) {
      case 'paragraph': return inline(node).replace(/^[ \t]+/gm, spaces =>
        Array.from(spaces, s => s === '\t' ? '&#9;' : '&#32;').join(''));
      case 'heading': return '#'.repeat(node.attrs.level) + ' ' + inline(node);
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
        node.forEach(child => contents.push(block(child, true)));
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
          let text = inline(item.firstChild!);
          item.forEach((child, offset) => {
            if (offset) text += '\n' + block(child, true);
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
          row.forEach(cell => cells.push(inline(cell)));
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
    output += raw ?? (node.type.name === 'raw_source' ? node.attrs.raw : block(node).replace(/\n/g, eol));
  });
  output += doc.attrs.tail;
  if (verify && JSON.stringify(semantics(importMarkdown(output).doc)) !== JSON.stringify(semantics(doc))) {
    throw new Error('Markdown round-trip would change document structure; draft preserved');
  }
  return output;
}
