// Reading renderer for the document page (Sources/Bloct/Resources/Web/page.html). Sanitizes and renders
// Markdown blocks into #content, keeps the read snapshot (_mvRawLines) and
// routes document links. Swift supplies the page configuration as JSON.
const _mvPage = JSON.parse(document.getElementById('mv-page-config').textContent);

// Fail closed if the bundled sanitizer is unavailable.
if (typeof DOMPurify === 'undefined' || !DOMPurify.isSupported) {
    throw new Error('HTML sanitizer unavailable');
}
DOMPurify.addHook('uponSanitizeAttribute', function(node, data) {
    // User HTML must not impersonate the editor's own block containers.
    if (node.tagName === 'IMG' && data.attrName === 'src') {
        try {
            if (new URL(data.attrValue, document.baseURI).protocol === 'file:') {
                data.forceKeepAttr = true;
            }
        } catch (_) { data.keepAttr = false; }
    }
    if (data.attrName === 'class') {
        data.attrValue = data.attrValue.split(/\s+/).filter(function(c) {
            return !c.startsWith('mv-') && c !== 'markdown-body';
        }).join(' ');
    }
});
window._mvImageOrigin = _mvPage.imageOrigin;
function _mvSanitize(html) {
    var clean = DOMPurify.sanitize(html, {
        ALLOW_DATA_ATTR: false,
        ADD_TAGS: ['annotation'],
        ADD_ATTR: ['encoding'],
        FORBID_TAGS: ['style', 'form', 'textarea', 'select', 'button', 'iframe',
                      'object', 'embed', 'base', 'link', 'meta', 'template'],
        FORBID_ATTR: ['id', 'name', 'srcset', 'autofocus', 'contenteditable']
    });
    if (!window._mvImageOrigin) return clean;
    // Convert only sanitized image sources. Keep the author's URL for copy.
    var template = document.createElement('template');
    template.innerHTML = clean;
    template.content.querySelectorAll('img[src]').forEach(function(image) {
        var src = image.getAttribute('src');
        try {
            if (new URL(src, 'file:///').protocol !== 'file:') return;
            image.setAttribute('data-mv-image-source', src);
            // Encode raw Unicode/spaces without double-encoding existing %XX.
            var uri = encodeURI(src).replace(/%25([0-9a-f]{2})/gi, '%$1');
            image.src = window._mvImageOrigin + '?src=' + encodeURIComponent(uri);
        } catch (_) {}
    });
    return template.innerHTML;
}

// figureCaption handles *[...]*  blocks so the outer * are never seen by the italic rule
const figureCaption = {
    name: 'figureCaption',
    level: 'block',
    start(src) { return src.indexOf('*['); },
    tokenizer(src) {
        const match = src.match(/^\*\[([\s\S]*?)\]\*[ \t]*(?:\n|$)/);
        if (match) return { type: 'figureCaption', raw: match[0], text: match[1] };
    },
    renderer(token) {
        return '<p class="figure-caption">' + marked.parseInline(token.text) + '</p>\n';
    }
};
const noStrikethrough = {
    extensions: [{
        name: 'del',
        level: 'inline',
        start(src) { return src.indexOf('~'); },
        tokenizer(src) {
            const match = src.match(/^~+[\s\S]*?~+/);
            if (match) return { type: 'del', raw: match[0], text: match[0] };
        },
        renderer(token) { return token.text; }
    }]
};
// Override strong tokenizer: CommonMark's punctuation-flanking rule rejects
// closing ** when preceded by ) and followed by a non-space/non-punct char
// (e.g. a Korean letter). We only require content not to start/end with whitespace.
const permissiveStrong = {
    extensions: [{
        name: 'strong',
        level: 'inline',
        start(src) { return src.indexOf('**'); },
        tokenizer(src) {
            const match = /^\*\*(?!\s)((?:[^*\\]|\\[\s\S]|\*(?!\*))*?)(?<!\s)\*\*(?!\*)/.exec(src);
            if (match && match[1]) {
                return {
                    type: 'strong',
                    raw: match[0],
                    text: match[1],
                    tokens: this.lexer.inlineTokens(match[1])
                };
            }
        }
    }]
};
// Same fix for em: closing * preceded by ) and followed by a letter also fails.
const permissiveEm = {
    extensions: [{
        name: 'em',
        level: 'inline',
        start(src) { return src.indexOf('*'); },
        tokenizer(src) {
            // Skip ** (handled by permissiveStrong)
            if (/^\*\*/.test(src)) return;
            const match = /^\*(?!\s)((?:[^*\\]|\\[\s\S])*?)(?<!\s)\*(?!\*)/.exec(src);
            if (match && match[1]) {
                return {
                    type: 'em',
                    raw: match[0],
                    text: match[1],
                    tokens: this.lexer.inlineTokens(match[1])
                };
            }
        }
    }]
};
marked.use({ breaks: false, gfm: true, extensions: [figureCaption] });
marked.use(noStrikethrough);
marked.use(permissiveStrong);
marked.use(permissiveEm);


// Render one block's raw text through the math/code pipeline and return HTML.
function _mvRenderOneBlock(blockRaw, sourceOffset) {
    var mathStore = [], codeStore = [];
    // Choose a per-render namespace absent from the original source.
    // Literal MVCODE/MVMATH strings are ordinary document text.
    var prefix;
    do { prefix = 'MV' + Math.random().toString(36).slice(2) + 'Q'; }
    while (blockRaw.includes(prefix));
    var codePattern = new RegExp(prefix + 'CODE([0-9]+)X', 'g');
    var mathPattern = new RegExp(prefix + 'MATH([0-9]+)X', 'g');
    var original = _mvTasks.source(blockRaw, sourceOffset);
    var md = original;
    function replace(pattern, callback) { md = _mvTasks.replace(md, pattern, callback); }
    replace(/!\[([^\]]*)\]\(([^)]+)\)\{([^}]+)\}/g, function(_, alt, src, attrs) {
            let style = '';
            const w = attrs.match(/width\s*=\s*([^\s,}]+)/);
            const h = attrs.match(/height\s*=\s*([^\s,}]+)/);
            const a = attrs.match(/align\s*=\s*([^\s,}]+)/);
            if (w && /^(?:[0-9]+(?:\.[0-9]+)?)(?:px|%|em|rem|vw|vh)?$/.test(w[1])) { const v = w[1]; style += 'width:' + (/^[\d.]+$/.test(v) ? v + 'px' : v) + ';'; }
            if (h && /^(?:[0-9]+(?:\.[0-9]+)?)(?:px|%|em|rem|vw|vh)?$/.test(h[1])) { const v = h[1]; style += 'height:' + (/^[\d.]+$/.test(v) ? v + 'px' : v) + ';'; }
            const img = document.createElement('img');
            // The editor serializes destinations with angle brackets.
            const destination = /^<([^>]+)>(?:[ \t]+["'][^"']*["'])?$/.exec(src);
            if (destination) src = destination[1];
            img.setAttribute('src', src);
            img.setAttribute('alt', alt);
            if (style) img.setAttribute('style', style);
            if (a && (a[1] === 'left' || a[1] === 'center' || a[1] === 'right')) {
                const wrapper = document.createElement('div');
                wrapper.style.textAlign = a[1];
                wrapper.appendChild(img);
                return wrapper.outerHTML;
            }
            return img.outerHTML;
        });
    replace(/^(`{3,}|~{3,})[^\n]*\n[\s\S]*?\n\1[ \t]*$/mg, function(match, fence, offset) {
            codeStore.push(_mvTasks.slice(md, offset, offset + match.length)); return prefix + 'CODE' + (codeStore.length - 1) + 'X';
        });
    replace(/`+[^`\n]*`+/g, function(match, offset) {
            codeStore.push(_mvTasks.slice(md, offset, offset + match.length)); return prefix + 'CODE' + (codeStore.length - 1) + 'X';
        });
    replace(/\$\$([\s\S]+?)\$\$/g, function(match, tex, offset, str) {
            var before = str.substring(0, offset);
            var after = str.substring(offset + match.length);
            var blankBefore = /\n[ \t]*\n[ \t]*$/.test(before) || /^[ \t]*$/.test(before);
            var blankAfter = /^[ \t]*\n[ \t]*\n/.test(after) || /^[ \t]*$/.test(after);
            var isBlock = blankBefore && blankAfter;
            mathStore.push({ display: true, tex: tex.trim() });
            var ph = prefix + 'MATH' + (mathStore.length - 1) + 'X';
            return isBlock ? '\n\n' + ph + '\n\n' : ph;
        });
    replace(/\$((?:[^\$\\\n]|\\.)+?)\$/g, function(_, tex) {
            mathStore.push({ display: false, tex: tex.trim() });
            return prefix + 'MATH' + (mathStore.length - 1) + 'X';
        });
    replace(codePattern, function(match, i) { return codeStore[+i] ?? match; });
    var _hasBlockquote = /^>/m.test(md.text);
    replace(/^(#{1,6}|[-*+]|>|\d+[.)])[ \t]*$/mg, function(_, m) {
        if (m === '>' && _hasBlockquote) return m;
        return '<span>' + m.replace(/&/g,'&amp;').replace(/</g,'&lt;') + '</span>';
    });
    var html = _mvTasks.render(md, original, prefix);
    html = html.replace(mathPattern, function(match, i) {
        return mathStore[+i] ? _mvRenderMath(mathStore[+i]) : match;
    });
    return _mvSanitize(html);
}

// Missing bundled math resources must not blank the document.
function _mvRenderMath(item) {
    if (typeof katex === 'undefined') {
        var d = item.display ? '$$' : '$';
        return (d + item.tex + d).replace(/&/g, '&amp;').replace(/</g, '&lt;');
    }
    return katex.renderToString(item.tex, { throwOnError: false, displayMode: item.display, trust: false, strict: 'warn' });
}

function _mvSafeDecodeURI(s) {
    try { return decodeURIComponent(s); } catch (e) { return s; }
}

// Rebuild #content from raw markdown without touching scroll position.
// Keep the read snapshot in sync with the rendered DOM.
function _mvRenderRaw(raw) {
    _mvTasks.begin(raw);
    window._mvRawLines = raw.split('\n');
    window._mvStale = false;

    // Split raw into blocks, keeping fenced code and math blocks intact.
    var blocks = [];
    var bStart = -1;
    var inFence = false, fenceChar = '', fenceLen = 0, inMathBlock = false;
    window._mvRawLines.forEach(function(line, i) {
        var trimmed = line.trim();
        if (!inMathBlock) {
            var fm = trimmed.match(/^(`{3,}|~{3,})/);
            if (fm) {
                var ch = fm[1][0], len = fm[1].length;
                if (!inFence) {
                    inFence = true; fenceChar = ch; fenceLen = len;
                } else if (ch === fenceChar && len >= fenceLen && trimmed.replace(new RegExp('^' + fenceChar + '+'), '') === '') {
                    inFence = false;
                }
            }
        }
        if (!inFence && trimmed === '$$') { inMathBlock = !inMathBlock; }
        if (!inFence && !inMathBlock && trimmed === '') {
            if (bStart !== -1) { blocks.push({ start: bStart, end: i }); bStart = -1; }
        } else {
            if (bStart === -1) bStart = i;
        }
    });
    if (bStart !== -1) blocks.push({ start: bStart, end: window._mvRawLines.length });

    // Render each block independently and wrap in a .mv-block container.
    var sourceOffset = 0, nextLine = 0;
    var fullHtml = blocks.map(function(b) {
        while (nextLine < b.start) sourceOffset += window._mvRawLines[nextLine++].length + 1;
        var blockText = window._mvRawLines.slice(b.start, b.end).join('\n');
        return '<div class="mv-block" data-start="' + b.start + '" data-end="' + b.end + '">'
            + _mvRenderOneBlock(blockText, sourceOffset) + '</div>';
    }).join('');
    var content = document.getElementById('content');
    content.innerHTML = fullHtml;
    _mvTasks.install(content);

    content.querySelectorAll('a[href^="#"]').forEach(function(a) {
        a.setAttribute('href', _mvSafeDecodeURI(a.getAttribute('href')).replace(/-+/g, '-'));
    });
    content.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(h) {
        h.id = h.textContent.trim().toLowerCase()
            .replace(/[^\p{L}\p{N}\s-]/gu, '')
            .trim()
            .replace(/\s+/g, '-')
            .replace(/-+/g, '-');
    });
    if (window._mvBuildTOC) window._mvBuildTOC();
}

// Called by Swift with the base64-encoded document on initial load and
// whenever the document text changes (commit echo, undo/redo).
window._mvRender = function(base64md) {
    var bytes = Uint8Array.from(atob(base64md), c => c.charCodeAt(0));
    var raw = new TextDecoder().decode(bytes);
    var current = window._mvRawLines ? window._mvRawLines.join('\n') : null;
    if (raw === current && !window._mvStale) return;  // already rendered locally
    _mvRenderRaw(raw);
};

// Initial render
window._mvRender(_mvPage.markdown);

// Reload belongs to the document in both reading and Aa.
document.addEventListener('keydown', function(e) {
    if (e.metaKey && !e.ctrlKey && !e.altKey && !e.shiftKey && e.key.toLowerCase() === 'r') {
        e.preventDefault();
        window.webkit.messageHandlers.reloadDocument.postMessage(true);
    }
}, true);

document.addEventListener('click', function(e) {
    var a = e.target.closest('a[href^="#"]');
    if (!a) return;
    e.preventDefault();
    var fragment = _mvSafeDecodeURI(a.getAttribute('href').slice(1));
    var el = document.getElementById(fragment);
    if (el) el.scrollIntoView({behavior: 'smooth'});
});
document.addEventListener('click', function(e) {
    var a = e.target.closest('a[href]');
    if (!a) return;
    var href = a.getAttribute('href');
    if (href && (href.startsWith('http://') || href.startsWith('https://'))) {
        e.preventDefault();
        e.stopPropagation();
        window.webkit.messageHandlers.openExternal.postMessage(href);
    }
}, true);
document.addEventListener('click', function(e) {
    var toc = document.getElementById('toc');
    if (toc && !toc.contains(e.target) && toc.style.transform !== 'translateX(-220px)') {
        window.webkit.messageHandlers.closeTOC.postMessage(null);
    }
});
