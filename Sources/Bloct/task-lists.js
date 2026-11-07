// Source positions are UTF-16 offsets, like JS strings. Generated HTML never
// grants editing authority. Validated markers get styled, disabled read-only inputs.
window._mvTasks = (() => {
    let pending = new Map();

    function source(text, start = 0) {
        return { text, positions: Array.from({ length: text.length }, (_, i) => start + i) };
    }
    function slice(view, start, end) {
        return { text: view.text.slice(start, end), positions: view.positions.slice(start, end) };
    }
    // Retain positions only for unchanged characters. Generated image/math HTML
    // has no source authority; restored code receives its original position map.
    function replace(view, pattern, callback) {
        let text = '', positions = [], cursor = 0;
        view.text.replace(pattern, (...args) => {
            const offset = args[args.length - 2], match = args[0];
            const replacement = callback(...args);
            const next = replacement === match ? slice(view, offset, offset + match.length)
                : typeof replacement === 'string'
                    ? { text: replacement, positions: Array(replacement.length).fill(-1) } : replacement;
            text += view.text.slice(cursor, offset) + next.text;
            positions = positions.concat(view.positions.slice(cursor, offset), next.positions);
            cursor = offset + match.length;
            return match;
        });
        text += view.text.slice(cursor);
        positions = positions.concat(view.positions.slice(cursor));
        return { text, positions };
    }
    function normalize(view) {
        return replace(view, /\r\n?/g, (_, offset) => ({ text: '\n', positions: [view.positions[offset]] }));
    }

    // Container lexers strip quote/list prefixes (and expand tabs), but preserve
    // line boundaries. Align each child line to the suffix of THAT parent line;
    // never search visible labels, global task order or unrelated source lines.
    function childView(text, parent) {
        const lines = text.split('\n'), raw = parent.text.split('\n');
        if (lines.length > raw.length) return null;
        let offset = 0, positions = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            let expanded = raw[i], map = parent.positions.slice(offset, offset + raw[i].length);
            // Quoted text and first list lines retain literal content tabs;
            // continuation indentation may instead be expanded by the lexer.
            if (!expanded.endsWith(line) && !expanded.trimEnd().endsWith(line)) {
                expanded = ''; map = [];
                for (let j = 0; j < raw[i].length; j++) {
                    const count = raw[i][j] === '\t' ? 4 : 1;
                    expanded += raw[i][j] === '\t' ? ' '.repeat(count) : raw[i][j];
                    for (let k = 0; k < count; k++) map.push(parent.positions[offset + j]);
                }
            }
            const trimmed = expanded.trimEnd();
            let start = expanded.length - line.length;
            if (!expanded.endsWith(line)) {
                start = trimmed.length - line.length;
                if (!trimmed.endsWith(line)) return null;
            }
            if (start < 0) return null;
            positions = positions.concat(map.slice(start, start + line.length));
            if (i < lines.length - 1) positions.push(parent.positions[offset + raw[i].length]);
            offset += raw[i].length + 1;
        }
        return { text, positions };
    }

    function mapTokens(tokens, view, found) {
        let cursor = 0;
        for (const token of tokens) {
            let raw = token.raw;
            // Marked trims the final list item's spaces, sometimes retaining an
            // artificial final newline in the enclosing container's raw value.
            if (token.type === 'list' || token.type === 'blockquote') raw = raw.trimEnd();
            // Marked joins consecutive text tokens with an extra newline in raw.
            if (token.type === 'text' && !view.text.startsWith(raw, cursor)) raw = token.text;
            const offset = view.text.indexOf(raw, cursor);
            // Definitions omitted by the lexer or an unrecognized transformation
            // are deliberately not guessed. Later ambiguous targets stay disabled.
            if (offset < 0 || view.text.slice(cursor, offset).trim()) return;
            const own = slice(view, offset, offset + raw.length);
            cursor = offset + raw.length;
            if (token.type === 'blockquote') {
                const child = childView(token.text, own);
                if (child) mapTokens(token.tokens, child, found);
            } else if (token.type === 'list') {
                let itemOffset = 0;
                for (const item of token.items) {
                    if (!own.text.startsWith(item.raw, itemOffset)) break;
                    const itemView = slice(own, itemOffset, itemOffset + item.raw.length);
                    itemOffset += item.raw.length;
                    if (item.task) {
                        const marker = /^[ \t]*(?:[-+*]|\d{1,9}[.)])[ \t]+\[([ xX])\](?=[ \t\n]|$)/.exec(item.raw);
                        if (marker) {
                            const index = marker[0].lastIndexOf('[') + 1;
                            const position = itemView.positions[index];
                            if (position >= 0) { found.set(position, !!item.checked); item.mvTaskPosition = position; }
                        }
                    }
                    const child = childView(item.text, itemView);
                    if (child) mapTokens(item.tokens, child, found);
                }
            }
        }
    }

    function begin(raw) {
        pending = new Map();
    }
    function render(view, original, prefix) {
        const allowed = new Map();
        const normalizedOriginal = normalize(original);
        mapTokens(marked.lexer(normalizedOriginal.text), normalizedOriginal, allowed);
        const normalized = normalize(view), tokens = marked.lexer(normalized.text);
        mapTokens(tokens, normalized, new Map());
        const renderer = new marked.Renderer();
        let current;
        renderer.listitem = function(token) {
            const previous = current;
            current = token;
            try { return marked.Renderer.prototype.listitem.call(this, token); }
            finally { current = previous; }
        };
        renderer.checkbox = function(token) {
            const position = current && current.mvTaskPosition;
            if (allowed.get(position) !== !!token.checked || !allowed.has(position)) {
                return marked.Renderer.prototype.checkbox.call(this, token);
            }
            const key = prefix + 'TASK' + pending.size + 'X';
            pending.set(key, { position, checked: !!token.checked });
            return key;
        };
        return marked.parser(tokens, Object.assign({}, marked.defaults, { renderer }));
    }
    function install(content) {
        // User-authored inputs remain inert, including forged IDs/classes/data.
        content.querySelectorAll('input').forEach(input => { input.disabled = true; });
        const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
        const texts = [];
        while (walker.nextNode()) texts.push(walker.currentNode);
        for (const text of texts) {
            for (const [key, record] of pending) {
                const index = text.textContent.indexOf(key);
                if (index < 0) continue;
                const tail = text.splitText(index);
                tail.deleteData(0, key.length);
                const input = document.createElement('input');
                input.type = 'checkbox';
                input.disabled = true;
                input.checked = record.checked;
                input.className = 'mv-task-checkbox';
                const label = tail.textContent.trim();
                input.setAttribute('aria-label', label || 'Task');
                tail.parentNode.insertBefore(input, tail);
                pending.delete(key);
                // A text node can contain several placeholders.
                texts.push(tail);
                break;
            }
        }
        pending.clear();
    }

    // Reading never grants edit authority. Aa owns all task mutations.
    return { source, slice, replace, begin, render, install };
})();
