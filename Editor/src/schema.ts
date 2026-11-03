import {Schema} from '@tiptap/pm/model';

// All editable state lives in this engine tree. Source metadata is inert: it is
// never an authority to execute commands received from HTML or a native bridge.
const blockAttrs = {
  id: {default: null}, source: {default: null}, before: {default: ''},
};

export const schema = new Schema({
  nodes: {
    doc: {content: 'block+', attrs: {tail: {default: ''}, bom: {default: ''}}},
    paragraph: {
      group: 'block', content: 'inline*', attrs: blockAttrs,
      toDOM: () => ['p', 0],
    },
    heading: {
      group: 'block', content: 'inline*', defining: true,
      attrs: {...blockAttrs, level: {default: 1}},
      toDOM: node => [`h${node.attrs.level}`, 0],
    },
    bullet_list: {
      group: 'block', content: 'list_item+',
      attrs: {...blockAttrs, marker: {default: '-'}}, toDOM: () => ['ul', 0],
    },
    ordered_list: {
      group: 'block', content: 'list_item+',
      attrs: {...blockAttrs, start: {default: 1}, marker: {default: '.'}},
      toDOM: node => ['ol', {start: node.attrs.start}, 0],
    },
    list_item: {
      content: 'paragraph block*', defining: true,
      attrs: {...blockAttrs, checked: {default: null}, taskOffset: {default: null}},
      toDOM: () => ['li', 0],
    },
    blockquote: {
      group: 'block', content: 'block+', defining: true, attrs: blockAttrs,
      toDOM: () => ['blockquote', 0],
    },
    code_block: {
      group: 'block', content: 'text*', marks: '', code: true, defining: true,
      attrs: {...blockAttrs, language: {default: ''}},
      toDOM: () => ['pre', ['code', 0]],
    },
    equation: {
      group: 'block', atom: true,
      attrs: {...blockAttrs, value: {default: ''}},
      toDOM: node => ['div', {'data-equation': ''}, node.attrs.value],
    },
    image_block: {
      group: 'block', atom: true,
      attrs: {...blockAttrs, src: {default: ''}, alt: {default: ''},
        title: {default: null}, imageAttrs: {default: ''}, caption: {default: ''}},
      // Resource URL resolution belongs to the future WebView adapter.
      toDOM: node => ['span', {'data-image-source': node.attrs.src}, node.attrs.alt],
    },
    horizontal_rule: {
      group: 'block', atom: true, attrs: blockAttrs, toDOM: () => ['hr'],
    },
    raw_source: {
      group: 'block', atom: true, isolating: true,
      attrs: {...blockAttrs, raw: {default: ''}, reason: {default: 'unsupported'}},
      toDOM: node => ['pre', {'data-source-protected': ''}, node.attrs.raw],
    },
    table: {
      group: 'block', content: 'table_row+', isolating: true,
      attrs: {...blockAttrs, align: {default: []}},
      toDOM: () => ['table', ['tbody', 0]],
    },
    table_row: {content: 'table_cell+', attrs: blockAttrs, toDOM: () => ['tr', 0]},
    table_cell: {content: 'inline*', attrs: blockAttrs, toDOM: () => ['td', 0]},
    text: {group: 'inline'},
    soft_break: {group: 'inline', inline: true, atom: true, toDOM: () => ['span', ' ']},
    hard_break: {group: 'inline', inline: true, selectable: false, toDOM: () => ['br']},
    inline_math: {
      group: 'inline', inline: true, atom: true,
      attrs: {value: {default: ''}}, toDOM: node => ['span', node.attrs.value],
    },
    inline_image: {
      group: 'inline', inline: true, atom: true,
      attrs: {src: {default: ''}, alt: {default: ''}, title: {default: null}},
      toDOM: node => ['span', {'data-image-source': node.attrs.src}, node.attrs.alt],
    },
  },
  marks: {
    strong: {toDOM: () => ['strong', 0]},
    em: {toDOM: () => ['em', 0]},
    code: {code: true, excludes: '_', toDOM: () => ['code', 0]},
    link: {
      attrs: {href: {}, title: {default: null}}, inclusive: false,
      // Navigation/URL validation must be added by the UI adapter before use.
      toDOM: mark => ['span', {'data-link-source': mark.attrs.href}, 0],
    },
  },
});
