import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fileURL: URL?
    let zoomLevel: Double
    let showTOC: Bool
    let webViewStore: WebViewStore
    var onCloseTOC: () -> Void = {}
    var onTextCommit: (String) -> Void = { _ in }
    var onSave: (() -> Void)? = nil
    var onSaveOnly: (() -> Void)? = nil
    var onEditorActiveChanged: (Bool) -> Void = { _ in }

    private static let markedJS: String = {
        guard let url = Bundle.main.url(forResource: "marked.min", withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return content
    }()

    private static let css: String = {
        guard let url = Bundle.main.url(forResource: "style", withExtension: "css"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return content
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static let tocWidth = "220px"
    private static let tocScript = """
        (function() {
            if (!window._mvBuildTOC) {
                window._mvBuildTOC = function() {
                    var headings = document.querySelectorAll('h1,h2,h3');
                    var toc = document.getElementById('toc');
                    var isNew = !toc;
                    if (isNew) {
                        toc = document.createElement('nav');
                        toc.id = 'toc';
                        toc.style.cssText = 'position:fixed;top:0;left:0;width:220px;height:100vh;' +
                            'background:var(--color-canvas-default,Canvas);' +
                            'border-right:1px solid var(--color-border-default,GrayText);' +
                            'padding:20px 14px;overflow-y:auto;z-index:100;box-sizing:border-box;' +
                            'overscroll-behavior:contain;transition:transform 0.3s ease;';
                    }
                    toc.innerHTML = '';
                    headings.forEach(function(h) {
                        var level = parseInt(h.tagName[1]);
                        var fontSize = level === 1 ? '13.5px' : level === 2 ? '12px' : '11px';
                        var fontWeight = level === 1 ? '600' : '400';
                        var opacity = level === 3 ? '0.7' : '1';
                        var a = document.createElement('a');
                        a.href = '#' + h.id;
                        a.textContent = h.textContent;
                        a.style.cssText = 'display:block;padding-left:' + (level-1)*12 + 'px;' +
                            'margin:4px 0;color:var(--color-fg-default,CanvasText);text-decoration:none;' +
                            'font-size:' + fontSize + ';font-weight:' + fontWeight + ';opacity:' + opacity + ';' +
                            'white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.5;';
                        a.onmouseenter = function() { this.style.opacity = String(parseFloat(opacity) * 0.6); };
                        a.onmouseleave = function() { this.style.opacity = opacity; };
                        a.onclick = function(e) { e.preventDefault(); h.scrollIntoView({behavior:'smooth'}); };
                        toc.appendChild(a);
                    });
                    if (isNew) {
                        document.body.appendChild(toc);
                        document.body.style.paddingLeft = '220px';
                        document.body.style.transition = 'padding-left 0.3s ease';
                    }
                };
            }
            window._mvBuildTOC();
        })();
    """

    // Weak wrapper to break the retain cycle between WKUserContentController and Coordinator.
    private class WeakMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: WKScriptMessageHandler?
        init(_ target: WKScriptMessageHandler) { self.target = target }
        func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(ucc, didReceive: message)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastMarkdown: String = ""
        var showTOC: Bool = true
        var lastShowTOC: Bool = true
        var tempHTMLURL: URL?
        var onCloseTOC: () -> Void = {}
        var fileURL: URL?
        var isPageLoaded: Bool = false
        var onTextCommit: ((String) -> Void)?
        var onSave: (() -> Void)?
        var onSaveOnly: (() -> Void)?
        var onEditorActiveChanged: ((Bool) -> Void)?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "closeTOC" {
                DispatchQueue.main.async { [weak self] in self?.onCloseTOC() }
                return
            }
            if message.name == "scrollPosition" {
                if let y = message.body as? Double, let url = fileURL {
                    UserDefaults.standard.set(y, forKey: "scrollPos:\(url.path)")
                }
                return
            }
            if message.name == "commitEdit" {
                if let base64 = message.body as? String,
                   let data = Data(base64Encoded: base64),
                   let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { [weak self] in self?.onTextCommit?(text) }
                }
                return
            }
            if message.name == "commitEditAndSave" {
                if let base64 = message.body as? String,
                   let data = Data(base64Encoded: base64),
                   let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { [weak self] in
                        self?.onTextCommit?(text)
                        self?.onSaveOnly?()
                    }
                }
                return
            }
            if message.name == "editorActive" {
                if let active = message.body as? Bool {
                    DispatchQueue.main.async { [weak self] in self?.onEditorActiveChanged?(active) }
                }
                return
            }
            if message.name == "debug" {
                print("[MV-JS] \(message.body)")
                return
            }
            guard message.name == "openExternal",
                  let urlString = message.body as? String,
                  let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            // Do NOT delete tempHTMLURL here — WKWebView's sandboxed content process
            // needs the origin file to exist in order to resolve and load local images
            // (file:// src attributes) throughout the page's lifetime. The file is
            // deleted just before the next load starts (see updateNSView).
            webView.evaluateJavaScript(MarkdownWebView.tocScript, completionHandler: nil)
            if !showTOC {
                // Instant hide on load (no animation)
                webView.evaluateJavaScript(
                    "(function(){var t=document.getElementById('toc');if(t){t.style.transition='none';t.style.transform='translateX(-220px)';t.style.pointerEvents='none';document.body.style.transition='none';document.body.style.paddingLeft='';}})();",
                    completionHandler: nil)
            }
            // Restore saved scroll position
            if let url = fileURL {
                let savedY = UserDefaults.standard.double(forKey: "scrollPos:\(url.path)")
                if savedY > 0 {
                    webView.evaluateJavaScript(
                        "setTimeout(function(){ window.scrollTo({ top: \(savedY), behavior: 'smooth' }); }, 100);",
                        completionHandler: nil)
                }
            }
            // Install debounced scroll listener (saves position)
            webView.evaluateJavaScript("""
                (function() {
                    var t;
                    window.addEventListener('scroll', function() {
                        clearTimeout(t);
                        t = setTimeout(function() {
                            window.webkit.messageHandlers.scrollPosition.postMessage(window.scrollY);
                        }, 200);
                    }, { passive: true });
                })();
                """, completionHandler: nil)
            // Install resize scroll-anchor: keeps the first visible block element
            // at the same viewport position as the user drags the window edge.
            webView.evaluateJavaScript("""
                (function() {
                    var _anchor = null, _anchorTop = 0, _tid = null, _raf = null;
                    function _findAnchor() {
                        var x = Math.floor(window.innerWidth * 0.5);
                        for (var y = 2; y < window.innerHeight * 0.4; y += 4) {
                            var el = document.elementFromPoint(x, y);
                            while (el && el !== document.body && el !== document.documentElement) {
                                var d = window.getComputedStyle(el).display;
                                if (d === 'block' || d === 'list-item' || d === 'table' || d === 'flex') {
                                    return el;
                                }
                                el = el.parentElement;
                            }
                        }
                        return null;
                    }
                    window.addEventListener('resize', function() {
                        if (!_anchor) {
                            _anchor = _findAnchor();
                            if (_anchor) _anchorTop = _anchor.getBoundingClientRect().top;
                        } else {
                            // Batch corrections to one per animation frame so rapid resize events
                            // don't queue multiple scroll calls. Each correction is instant so
                            // the content appears locked to the viewport edge while dragging.
                            cancelAnimationFrame(_raf);
                            _raf = requestAnimationFrame(function() {
                                var delta = _anchor.getBoundingClientRect().top - _anchorTop;
                                if (Math.abs(delta) > 0.5) window.scrollBy(0, delta);
                            });
                        }
                        clearTimeout(_tid);
                        _tid = setTimeout(function() {
                            // Once the drag stops, apply a final smooth correction for any
                            // residual drift that accumulated during the live resize.
                            if (_anchor) {
                                var delta = _anchor.getBoundingClientRect().top - _anchorTop;
                                if (Math.abs(delta) > 0.5) window.scrollBy({ top: delta, behavior: 'smooth' });
                            }
                            _anchor = null;
                        }, 150);
                    }, { passive: true });
                })();
                """, completionHandler: nil)
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "openExternal")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "closeTOC")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "scrollPosition")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "commitEdit")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "commitEditAndSave")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "editorActive")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "debug")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        #endif
        webViewStore.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webViewStore.webView = webView
        context.coordinator.showTOC = showTOC
        context.coordinator.onCloseTOC = onCloseTOC
        context.coordinator.fileURL = fileURL
        context.coordinator.onTextCommit = { text in onTextCommit(text) }
        context.coordinator.onSave = onSave
        context.coordinator.onSaveOnly = onSaveOnly
        context.coordinator.onEditorActiveChanged = onEditorActiveChanged
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown
            context.coordinator.lastShowTOC = showTOC
            if context.coordinator.isPageLoaded {
                // Live edit: update only the content in-place, no page reload, scroll is preserved
                let base64 = Data(markdown.utf8).base64EncodedString()
                webView.evaluateJavaScript("window._mvRender && window._mvRender('\(base64)');", completionHandler: nil)
            } else {
                // Delete the previous temp file now that a new load is starting
                if let prev = context.coordinator.tempHTMLURL {
                    try? FileManager.default.removeItem(at: prev)
                    context.coordinator.tempHTMLURL = nil
                }
                context.coordinator.isPageLoaded = false
                if let fileURL = fileURL {
                    let dir = fileURL.deletingLastPathComponent()
                    let tmpURL = dir.appendingPathComponent(".mv_preview.html")
                    if (try? buildHTML().write(to: tmpURL, atomically: true, encoding: .utf8)) != nil {
                        context.coordinator.tempHTMLURL = tmpURL
                        webView.loadFileURL(tmpURL, allowingReadAccessTo: dir)
                    } else {
                        webView.loadHTMLString(buildHTML(), baseURL: dir)
                    }
                } else {
                    webView.loadHTMLString(buildHTML(), baseURL: URL(string: "https://cdn.jsdelivr.net"))
                }
            }
        } else if context.coordinator.lastShowTOC != showTOC {
            context.coordinator.lastShowTOC = showTOC
            let transform = showTOC ? "translateX(0)" : "translateX(-220px)"
            let pointer = showTOC ? "auto" : "none"
            let padding = showTOC ? "220px" : ""
            let js = """
            (function(){
                var t = document.getElementById('toc');
                if (!t) return;
                // Find the first block-level element at the top of the viewport.
                var anchor = null;
                var x = Math.floor(window.innerWidth * 0.5);
                outer: for (var y = 2; y < window.innerHeight * 0.4; y += 4) {
                    var el = document.elementFromPoint(x, y);
                    while (el && el !== document.body && el !== document.documentElement) {
                        var d = window.getComputedStyle(el).display;
                        if (d === 'block' || d === 'list-item' || d === 'table' || d === 'flex') {
                            anchor = el; break outer;
                        }
                        el = el.parentElement;
                    }
                }
                // Predict the scroll delta by peeking at the final layout state.
                var delta = 0;
                if (anchor) {
                    var anchorTop = anchor.getBoundingClientRect().top;
                    var prevTransform = t.style.transform;
                    var prevPadding = document.body.style.paddingLeft;
                    t.style.transition = 'none';
                    document.body.style.transition = 'none';
                    t.style.transform = '\(transform)';
                    document.body.style.paddingLeft = '\(padding)';
                    delta = anchor.getBoundingClientRect().top - anchorTop; // forced reflow
                    t.style.transform = prevTransform;
                    document.body.style.paddingLeft = prevPadding;
                    void document.body.getBoundingClientRect(); // force restore reflow
                }
                // Start the TOC animation and scroll correction simultaneously.
                t.style.transition = 'transform 0.3s ease';
                t.style.transform = '\(transform)';
                t.style.pointerEvents = '\(pointer)';
                document.body.style.transition = 'padding-left 0.3s ease';
                document.body.style.paddingLeft = '\(padding)';
                if (Math.abs(delta) > 0.5) { window.scrollBy({ top: delta, behavior: 'smooth' }); }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        webView.pageZoom = zoomLevel
    }

    private func buildHTML() -> String {
        let base64Markdown = Data(markdown.utf8).base64EncodedString()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="color-scheme" content="light dark">
            <style>\(Self.css)</style>
            <style>
                #content { cursor: text; }
                #content a { cursor: pointer; }
                .mv-block { display: contents; }
                article.markdown-body { padding-bottom: 40vh; }
                #mv-append-zone { height: 1.5em; }
                #mv-block-editor {
                    display: block; width: 100%; box-sizing: border-box;
                    font-family: ui-monospace, 'SFMono-Regular', Menlo, Monaco, Consolas, monospace;
                    font-size: 0.9em; line-height: 1.6; padding: 8px 12px; margin: 2px 0;
                    border: 2px solid #0969da; border-radius: 6px;
                    background: #f6f8fa; color: inherit;
                    resize: none; outline: none; overflow: hidden; tab-size: 4;
                }
                @media (prefers-color-scheme: dark) {
                    #mv-block-editor { background: #161b22; border-color: #388bfd; }
                }
            </style>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
            <script>\(Self.markedJS)</script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        </head>
        <body>
            <article class="markdown-body">
                <div id="content"></div>
            </article>
            <script>
                // figureCaption handles *[...]*  blocks so the outer * are never seen by the italic rule
                const figureCaption = {
                    name: 'figureCaption',
                    level: 'block',
                    start(src) { return src.indexOf('*['); },
                    tokenizer(src) {
                        const match = src.match(/^\\*\\[([\\s\\S]*?)\\]\\*[ \\t]*(?:\\n|$)/);
                        if (match) return { type: 'figureCaption', raw: match[0], text: match[1] };
                    },
                    renderer(token) {
                        return '<p class="figure-caption">' + marked.parseInline(token.text) + '</p>\\n';
                    }
                };
                const noStrikethrough = {
                    extensions: [{
                        name: 'del',
                        level: 'inline',
                        start(src) { return src.indexOf('~'); },
                        tokenizer(src) {
                            const match = src.match(/^~+[\\s\\S]*?~+/);
                            if (match) return { type: 'del', raw: match[0], text: match[0] };
                        },
                        renderer(token) { return token.text; }
                    }]
                };
                marked.use({ breaks: false, gfm: true, extensions: [figureCaption] });
                marked.use(noStrikethrough);

                // Render one block's raw text through the math/code pipeline and return HTML.
                function _mvRenderOneBlock(blockRaw) {
                    var mathStore = [], codeStore = [];
                    var md = blockRaw
                        .replace(/!\\[([^\\]]*)\\]\\(([^)]+)\\)\\{([^}]+)\\}/g, function(_, alt, src, attrs) {
                            let style = '';
                            const w = attrs.match(/width\\s*=\\s*([^\\s,}]+)/);
                            const h = attrs.match(/height\\s*=\\s*([^\\s,}]+)/);
                            const a = attrs.match(/align\\s*=\\s*([^\\s,}]+)/);
                            if (w) { const v = w[1]; style += 'width:' + (/^[\\d.]+$/.test(v) ? v + 'px' : v) + ';'; }
                            if (h) { const v = h[1]; style += 'height:' + (/^[\\d.]+$/.test(v) ? v + 'px' : v) + ';'; }
                            const img = '<img src="' + src + '" alt="' + alt + '"' + (style ? ' style="' + style + '"' : '') + '>';
                            if (a && (a[1] === 'left' || a[1] === 'center' || a[1] === 'right')) {
                                return '<div style="text-align:' + a[1] + '">' + img + '</div>';
                            }
                            return img;
                        })
                        .replace(/^(`{3,}|~{3,})[^\\n]*\\n[\\s\\S]*?\\n\\1[ \\t]*$/mg, function(match) {
                            codeStore.push(match); return 'MVCODE' + (codeStore.length - 1) + 'X';
                        })
                        .replace(/`+[^`\\n]*`+/g, function(match) {
                            codeStore.push(match); return 'MVCODE' + (codeStore.length - 1) + 'X';
                        })
                        .replace(/\\$\\$([\\s\\S]+?)\\$\\$/g, function(match, tex, offset, str) {
                            var before = str.substring(0, offset);
                            var after = str.substring(offset + match.length);
                            var blankBefore = /\\n[ \\t]*\\n[ \\t]*$/.test(before) || /^[ \\t]*$/.test(before);
                            var blankAfter = /^[ \\t]*\\n[ \\t]*\\n/.test(after) || /^[ \\t]*$/.test(after);
                            var isBlock = blankBefore && blankAfter;
                            mathStore.push({ display: true, tex: tex.trim() });
                            var ph = 'MVMATH' + (mathStore.length - 1) + 'X';
                            return isBlock ? '\\n\\n' + ph + '\\n\\n' : ph;
                        })
                        .replace(/\\$((?:[^\\$\\\\\\n]|\\\\.)+?)\\$/g, function(_, tex) {
                            mathStore.push({ display: false, tex: tex.trim() });
                            return '<mvmath data-i="' + (mathStore.length - 1) + '"></mvmath>';
                        })
                        .replace(/MVCODE(\\d+)X/g, function(_, i) { return codeStore[+i]; });
                    md = md.replace(/^(#{1,6}|[-*+]|>|\\d+[.)])[ \\t]*$/mg, function(_, m) {
                        return '<span>' + m.replace(/&/g,'&amp;').replace(/</g,'&lt;') + '</span>';
                    });
                    var html = marked.parse(md);
                    html = html.replace(/MVMATH(\\d+)X/g, function(_, i) {
                        const item = mathStore[+i];
                        return katex.renderToString(item.tex, { throwOnError: false, displayMode: item.display });
                    });
                    html = html.replace(/<mvmath data-i="(\\d+)"><\\/mvmath>/g, function(_, i) {
                        const item = mathStore[+i];
                        return katex.renderToString(item.tex, { throwOnError: false, displayMode: false });
                    });
                    return html;
                }

                // Render markdown (base64-encoded) into #content without touching scroll position.
                // Called once on initial load, then on every live edit keystroke from Swift.
                window._mvRender = function(base64md) {
                    var bytes = Uint8Array.from(atob(base64md), c => c.charCodeAt(0));
                    var raw = new TextDecoder().decode(bytes);
                    window._mvRawLines = raw.split('\\n');
                    window.webkit.messageHandlers.debug.postMessage('[MV] _mvRender called: activeEl=' + (window._mvActiveEl ? window._mvActiveEl.id || 'block' : 'null') + ' pendingNextLine=' + window._mvPendingNextEditLine + ' dirty=' + window._mvBlockDirty);
                    if (window._mvActiveEl) { window.webkit.messageHandlers.debug.postMessage('[MV] _mvRender: bailed (editor active)'); return; }

                    // Split raw into blocks: contiguous non-empty lines separated by blank lines.
                    var blocks = [];
                    var bStart = -1;
                    window._mvRawLines.forEach(function(line, i) {
                        if (line.trim() === '') {
                            if (bStart !== -1) { blocks.push({ start: bStart, end: i }); bStart = -1; }
                        } else {
                            if (bStart === -1) bStart = i;
                        }
                    });
                    if (bStart !== -1) blocks.push({ start: bStart, end: window._mvRawLines.length });

                    // Render each block independently and wrap in a .mv-block container.
                    var fullHtml = blocks.map(function(b) {
                        var blockText = window._mvRawLines.slice(b.start, b.end).join('\\n');
                        return '<div class="mv-block" data-start="' + b.start + '" data-end="' + b.end + '">'
                            + _mvRenderOneBlock(blockText) + '</div>';
                    }).join('');
                    fullHtml += '<div id="mv-append-zone" class="mv-placeholder" data-start="'
                        + window._mvRawLines.length + '" data-end="' + window._mvRawLines.length + '"></div>';
                    document.getElementById('content').innerHTML = fullHtml;

                    document.querySelectorAll('a[href^="#"]').forEach(function(a) {
                        var decoded = decodeURIComponent(a.getAttribute('href')).replace(/-+/g, '-');
                        a.setAttribute('href', decoded);
                    });
                    document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(h) {
                        h.id = h.textContent.trim().toLowerCase()
                            .replace(/[^\\p{L}\\p{N}\\s-]/gu, '')
                            .trim()
                            .replace(/\\s+/g, '-')
                            .replace(/-+/g, '-');
                    });
                    if (window._mvBuildTOC) window._mvBuildTOC();

                    if (window._mvPendingNextEditLine !== undefined) {
                        var targetLine = window._mvPendingNextEditLine;
                        window._mvPendingNextEditLine = undefined;
                        var blocks = document.querySelectorAll('.mv-block');
                        window.webkit.messageHandlers.debug.postMessage('[MV] _mvRender: focusNext targetLine=' + targetLine + ' blockCount=' + blocks.length);
                        var found = false;
                        for (var i = 0; i < blocks.length; i++) {
                            if (+blocks[i].getAttribute('data-start') >= targetLine) {
                                window.webkit.messageHandlers.debug.postMessage('[MV] _mvRender: starting edit on block[' + i + ']');
                                window._mvStartBlockEdit(blocks[i], Infinity, true);
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            window.webkit.messageHandlers.debug.postMessage('[MV] _mvRender: no next block found, opening append zone');
                            var az = document.getElementById('mv-append-zone');
                            if (az) window._mvStartBlockEdit(az, Infinity, true);
                        }
                    }
                    if (window._mvPendingPrevEditLine !== undefined) {
                        var targetLine = window._mvPendingPrevEditLine;
                        window._mvPendingPrevEditLine = undefined;
                        var blocks = document.querySelectorAll('.mv-block');
                        var found = false;
                        for (var i = blocks.length - 1; i >= 0; i--) {
                            if (+blocks[i].getAttribute('data-end') <= targetLine) {
                                window._mvStartBlockEdit(blocks[i], Infinity, true);
                                found = true;
                                break;
                            }
                        }
                        if (!found) window.webkit.messageHandlers.debug.postMessage('[MV] _mvRender: no prev block found');
                    }
                };

                // Initial render
                window._mvRender('\(base64Markdown)');

                // Count visible characters from blockEl start to caret position.
                function _mvCharOffset(blockEl, caretNode, caretOffset) {
                    var offset = 0;
                    var walker = document.createTreeWalker(blockEl, NodeFilter.SHOW_TEXT, null);
                    var node;
                    while ((node = walker.nextNode())) {
                        if (node === caretNode) { return offset + caretOffset; }
                        offset += node.textContent.length;
                    }
                    return offset;
                }

                // Block editing state
                window._mvRawLines = window._mvRawLines || [];
                window._mvActiveEl = null;
                window._mvActiveStartLine = -1;
                window._mvActiveEndLine = -1;

                // Close the inline block editor. commit=true posts the full text to Swift.
                window._mvCloseEditor = function(commit, save, focusNext, focusPrev) {
                    var ta = document.getElementById('mv-block-editor');
                    var prevEl = window._mvActiveEl;
                    var wasAppendZone = prevEl && prevEl.id === 'mv-append-zone';
                    var wasDirty = !!window._mvBlockDirty;
                    var savedStartLine = window._mvActiveStartLine;
                    var savedEndLine = window._mvActiveEndLine;
                    window._mvBlockDirty = false;
                    if (ta) ta.remove();
                    if (prevEl) {
                        if (prevEl.classList.contains('mv-placeholder')) prevEl.remove();
                        else prevEl.style.display = '';
                    }
                    window._mvActiveEl = null;
                    window.webkit.messageHandlers.editorActive.postMessage(false);
                    // If no edits were made, _mvRender won't fire (text unchanged),
                    // so focus the target block immediately while the DOM is still intact.
                    if ((focusNext || focusPrev) && !wasDirty) {
                        var blocks = document.querySelectorAll('.mv-block');
                        var target = null;
                        if (focusNext) {
                            for (var i = 0; i < blocks.length; i++) {
                                if (+blocks[i].getAttribute('data-start') >= savedEndLine) { target = blocks[i]; break; }
                            }
                        } else {
                            for (var i = blocks.length - 1; i >= 0; i--) {
                                if (+blocks[i].getAttribute('data-end') <= savedStartLine) { target = blocks[i]; break; }
                            }
                        }
                        if (target) window._mvStartBlockEdit(target, Infinity, true);
                        else if (focusNext) {
                            var az = document.getElementById('mv-append-zone');
                            if (az) window._mvStartBlockEdit(az, Infinity, true);
                        }
                    }
                    if (commit && prevEl) {
                        // Insert the blank separator first so savedEndLine can be adjusted
                        // before _mvPendingNextEditLine is set — otherwise the +1 shift from
                        // the splice would make the pending line land on the new block's start,
                        // causing it to be re-opened instead of advancing to the append zone.
                        var s = window._mvActiveStartLine;
                        if (wasAppendZone && s > 0
                                && window._mvRawLines.length > s
                                && window._mvRawLines[s - 1].trim() !== '') {
                            window._mvRawLines.splice(s, 0, '');
                            savedEndLine += 1;
                        }
                        if (focusNext && wasDirty) {
                            window._mvPendingNextEditLine = savedEndLine;
                            window.webkit.messageHandlers.debug.postMessage('[MV] _mvCloseEditor: dirty, set _mvPendingNextEditLine=' + window._mvPendingNextEditLine);
                        }
                        if (focusPrev && wasDirty) {
                            window._mvPendingPrevEditLine = savedStartLine;
                            window.webkit.messageHandlers.debug.postMessage('[MV] _mvCloseEditor: dirty, set _mvPendingPrevEditLine=' + window._mvPendingPrevEditLine);
                        }
                        var text = window._mvRawLines.join('\\n');
                        var encoded = btoa(unescape(encodeURIComponent(text)));
                        var handler = save ? 'commitEditAndSave' : 'commitEdit';
                        window.webkit.messageHandlers[handler].postMessage(encoded);
                    }
                    // Re-add the append zone if it was being edited and _mvRender didn't fire.
                    if (wasAppendZone && !document.getElementById('mv-append-zone')) {
                        var az = document.createElement('div');
                        az.id = 'mv-append-zone';
                        az.className = 'mv-placeholder';
                        az.setAttribute('data-start', String(window._mvRawLines.length));
                        az.setAttribute('data-end', String(window._mvRawLines.length));
                        var c = document.getElementById('content');
                        if (c) c.appendChild(az);
                    }
                };

                // Replace a .mv-block with an inline textarea for direct markdown editing.
                window._mvStartBlockEdit = function(blockEl, charOffset, scrollTo) {
                    if (window._mvActiveEl === blockEl) return;
                    if (window._mvActiveEl) window._mvCloseEditor(true);

                    var start = +blockEl.getAttribute('data-start');
                    var end = +blockEl.getAttribute('data-end');
                    window._mvActiveEl = blockEl;
                    window.webkit.messageHandlers.editorActive.postMessage(true);
                    window._mvActiveStartLine = start;
                    window._mvActiveEndLine = end;

                    window._mvBlockDirty = false;
                    var blockRaw = window._mvRawLines.slice(start, end).join('\\n');
                    var ta = document.createElement('textarea');
                    ta.id = 'mv-block-editor';
                    ta.value = blockRaw;
                    ta.spellcheck = true;

                    var savedScroll = window.scrollY;
                    blockEl.style.display = 'none';
                    blockEl.parentNode.insertBefore(ta, blockEl.nextSibling);
                    ta.style.height = ta.scrollHeight + 'px';
                    if (scrollTo) {
                        var targetY = ta.getBoundingClientRect().top + window.scrollY - window.innerHeight * 0.3;
                        window.scrollTo({ top: targetY, behavior: 'smooth' });
                    } else {
                        window.scrollTo(0, savedScroll);
                    }
                    ta.focus();
                    var pos = Math.min(charOffset || 0, ta.value.length);
                    ta.setSelectionRange(pos, pos);

                    ta.addEventListener('input', function() {
                        window._mvBlockDirty = true;
                        var newLines = ta.value.split('\\n');
                        window._mvRawLines = window._mvRawLines.slice(0, window._mvActiveStartLine)
                            .concat(newLines)
                            .concat(window._mvRawLines.slice(window._mvActiveEndLine));
                        window._mvActiveEndLine = window._mvActiveStartLine + newLines.length;
                        ta.style.height = 'auto';
                        ta.style.height = ta.scrollHeight + 'px';
                    });
                    ta.addEventListener('keydown', function(e) {
                        if (e.key === 'Escape') { e.preventDefault(); window._mvCloseEditor(true, false); }
                        if (e.key === 'Enter' && e.metaKey && !e.shiftKey) {
                            e.preventDefault();
                            window.webkit.messageHandlers.debug.postMessage('[MV] Cmd+Enter: activeStartLine=' + window._mvActiveStartLine + ' activeEndLine=' + window._mvActiveEndLine + ' dirty=' + window._mvBlockDirty);
                            window._mvCloseEditor(true, false, true, false);
                        }
                        if (e.key === 'Enter' && e.metaKey && e.shiftKey) {
                            e.preventDefault();
                            window.webkit.messageHandlers.debug.postMessage('[MV] Shift+Cmd+Enter: activeStartLine=' + window._mvActiveStartLine + ' activeEndLine=' + window._mvActiveEndLine + ' dirty=' + window._mvBlockDirty);
                            window._mvCloseEditor(true, false, false, true);
                        }
                    });
                    ta.addEventListener('blur', function() {
                        // Defer so a click on another block fires _mvStartBlockEdit first,
                        // letting it take ownership before this cleanup runs.
                        setTimeout(function() {
                            if (window._mvActiveEl === blockEl) window._mvCloseEditor(true);
                        }, 0);
                    });
                };

                // Click in the bottom padding area — forward to the append zone.
                document.addEventListener('click', function(e) {
                    var az = document.getElementById('mv-append-zone');
                    if (!az) return;
                    var content = document.getElementById('content');
                    if (!content) return;
                    if (content.contains(e.target)) return;
                    var contentBottom = content.getBoundingClientRect().bottom;
                    if (e.clientY >= contentBottom) window._mvStartBlockEdit(az, 0);
                });

                // Click anywhere in the preview to start block editing.
                document.getElementById('content').addEventListener('click', function(e) {
                    if (e.target.closest('a')) return;
                    if (e.target.id === 'mv-block-editor' || e.target.closest('#mv-block-editor')) return;
                    var blockEl = e.target.closest('.mv-block, #mv-append-zone');
                    if (!blockEl) return;
                    var charOffset = 0;
                    var caret = document.caretRangeFromPoint ? document.caretRangeFromPoint(e.clientX, e.clientY) : null;
                    if (caret && blockEl.contains(caret.startContainer)) {
                        charOffset = _mvCharOffset(blockEl, caret.startContainer, caret.startOffset);
                    }
                    window._mvStartBlockEdit(blockEl, charOffset);
                });

                document.addEventListener('click', function(e) {
                    var a = e.target.closest('a[href^="#"]');
                    if (!a) return;
                    e.preventDefault();
                    var fragment = decodeURIComponent(a.getAttribute('href').slice(1));
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
                window._mvSearch = (function() {
                    var marks = [], idx = 0;
                    function clear() {
                        document.querySelectorAll('mark.mv-hl').forEach(function(m) {
                            var p = m.parentNode;
                            if (p) { p.replaceChild(document.createTextNode(m.textContent), m); p.normalize(); }
                        });
                        marks = []; idx = 0;
                    }
                    function highlight(text) {
                        clear();
                        if (!text) return;
                        var lo = text.toLowerCase();
                        var root = document.getElementById('content') || document.body;
                        var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
                        var nodes = [], n;
                        while ((n = walker.nextNode())) nodes.push(n);
                        var ranges = [];
                        nodes.forEach(function(node) {
                            var t = node.textContent, lt = t.toLowerCase(), i = 0;
                            while ((i = lt.indexOf(lo, i)) !== -1) { ranges.push({node: node, start: i, end: i + lo.length}); i++; }
                        });
                        for (var r = ranges.length - 1; r >= 0; r--) {
                            try {
                                var rng = document.createRange();
                                rng.setStart(ranges[r].node, ranges[r].start);
                                rng.setEnd(ranges[r].node, ranges[r].end);
                                var m = document.createElement('mark');
                                m.className = 'mv-hl';
                                m.style.cssText = 'background:#FFD700;color:#000;border-radius:2px;padding:0 1px;';
                                rng.surroundContents(m);
                                marks.unshift(m);
                            } catch(e) {}
                        }
                        idx = 0;
                        if (marks.length) { marks[0].style.background = '#FF8C00'; marks[0].scrollIntoView({behavior:'smooth',block:'center'}); }
                    }
                    function navigate(fwd) {
                        if (!marks.length) return;
                        marks[idx].style.background = '#FFD700';
                        idx = (idx + (fwd ? 1 : marks.length - 1)) % marks.length;
                        marks[idx].style.background = '#FF8C00';
                        marks[idx].scrollIntoView({behavior:'smooth',block:'center'});
                    }
                    return {highlight: highlight, navigate: navigate, clear: clear};
                })();

                // Copy selection as markdown
                function _mvHtmlToMd(node) {
                    if (node.nodeType === 3) return node.textContent;
                    if (node.nodeType !== 1) return '';
                    var tag = node.tagName.toLowerCase();
                    // KaTeX math: restore original LaTeX from MathML annotation
                    if (tag === 'span') {
                        if (node.classList.contains('katex-display')) {
                            var ann = node.querySelector('annotation[encoding="application/x-tex"]');
                            if (ann) return '$$' + ann.textContent.trim() + '$$\\n\\n';
                        }
                        if (node.classList.contains('katex')) {
                            var ann = node.querySelector('annotation[encoding="application/x-tex"]');
                            if (ann) return '$' + ann.textContent.trim() + '$';
                        }
                    }
                    var ch = Array.from(node.childNodes).map(_mvHtmlToMd).join('');
                    switch(tag) {
                        case 'h1': return '# ' + ch.trim() + '\\n\\n';
                        case 'h2': return '## ' + ch.trim() + '\\n\\n';
                        case 'h3': return '### ' + ch.trim() + '\\n\\n';
                        case 'h4': return '#### ' + ch.trim() + '\\n\\n';
                        case 'h5': return '##### ' + ch.trim() + '\\n\\n';
                        case 'h6': return '###### ' + ch.trim() + '\\n\\n';
                        case 'strong': case 'b': return '**' + ch + '**';
                        case 'em': case 'i': return '*' + ch + '*';
                        case 'code':
                            if (node.parentElement && node.parentElement.tagName.toLowerCase() === 'pre') return ch;
                            return '`' + ch + '`';
                        case 'pre': {
                            var c = node.querySelector('code');
                            var lang = c ? ((c.className.match(/language-(\\S+)/) || [])[1] || '') : '';
                            return '```' + lang + '\\n' + (c ? c.textContent : ch) + '\\n```\\n\\n';
                        }
                        case 'a': return '[' + ch + '](' + (node.getAttribute('href') || '') + ')';
                        case 'img': return '![' + (node.getAttribute('alt') || '') + '](' + (node.getAttribute('src') || '') + ')';
                        case 'p': return ch.trim() + '\\n\\n';
                        case 'br': return '\\n';
                        case 'hr': return '---\\n\\n';
                        case 'blockquote': return ch.split('\\n').map(function(l){return '> '+l;}).join('\\n') + '\\n\\n';
                        case 'ul': return Array.from(node.children).map(function(li){return '- '+_mvHtmlToMd(li).trim();}).join('\\n') + '\\n\\n';
                        case 'ol': return Array.from(node.children).map(function(li,i){return (i+1)+'. '+_mvHtmlToMd(li).trim();}).join('\\n') + '\\n\\n';
                        case 'table': {
                            var rows = Array.from(node.querySelectorAll('tr'));
                            if (!rows.length) return ch;
                            var mdRows = rows.map(function(row){
                                var cells = Array.from(row.querySelectorAll('th,td')).map(function(cell){return _mvHtmlToMd(cell).trim();});
                                return '| ' + cells.join(' | ') + ' |';
                            });
                            var colCount = Array.from(rows[0].querySelectorAll('th,td')).length;
                            var sep = '| ' + Array(colCount).fill('---').join(' | ') + ' |';
                            mdRows.splice(1, 0, sep);
                            return mdRows.join('\\n') + '\\n\\n';
                        }
                        case 'del': case 's': return '~~' + ch + '~~';
                        default: return ch;
                    }
                }
                document.addEventListener('copy', function(e) {
                    var sel = window.getSelection();
                    if (!sel || sel.isCollapsed) return;
                    var frag = sel.getRangeAt(0).cloneContents();
                    var wrap = document.createElement('div');
                    wrap.appendChild(frag);
                    var md = _mvHtmlToMd(wrap).replace(/\\n{3,}/g, '\\n\\n').trim();
                    e.clipboardData.setData('text/plain', md);
                    e.preventDefault();
                });
            </script>
        </body>
        </html>
        """
    }
}
