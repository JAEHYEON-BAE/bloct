import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fileURL: URL?
    let zoomLevel: Double
    let showTOC: Bool
    let webViewStore: WebViewStore
    var onCloseTOC: () -> Void = {}

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
            if (document.getElementById('toc')) return;
            var headings = document.querySelectorAll('h1,h2,h3');
            var toc = document.createElement('nav');
            toc.id = 'toc';
            toc.style.cssText = 'position:fixed;top:0;left:0;width:220px;height:100vh;' +
                'background:var(--color-canvas-default,Canvas);' +
                'border-right:1px solid var(--color-border-default,GrayText);' +
                'padding:20px 14px;overflow-y:auto;z-index:100;box-sizing:border-box;' +
                'overscroll-behavior:contain;transition:transform 0.3s ease;';
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
            document.body.appendChild(toc);
            document.body.style.paddingLeft = '220px';
            document.body.style.transition = 'padding-left 0.3s ease';
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

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "closeTOC" {
                DispatchQueue.main.async { [weak self] in self?.onCloseTOC() }
                return
            }
            guard message.name == "openExternal",
                  let urlString = message.body as? String,
                  let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let tmp = tempHTMLURL {
                try? FileManager.default.removeItem(at: tmp)
                tempHTMLURL = nil
            }
            webView.evaluateJavaScript(MarkdownWebView.tocScript, completionHandler: nil)
            if !showTOC {
                // Instant hide on load (no animation)
                webView.evaluateJavaScript(
                    "(function(){var t=document.getElementById('toc');if(t){t.style.transition='none';t.style.transform='translateX(-220px)';t.style.pointerEvents='none';document.body.style.transition='none';document.body.style.paddingLeft='';}})();",
                    completionHandler: nil)
            }
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "openExternal")
        config.userContentController.add(WeakMessageHandler(context.coordinator), name: "closeTOC")
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
        context.coordinator.showTOC = showTOC
        context.coordinator.onCloseTOC = onCloseTOC
        if context.coordinator.lastMarkdown != markdown {
            context.coordinator.lastMarkdown = markdown
            context.coordinator.lastShowTOC = showTOC
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
        } else if context.coordinator.lastShowTOC != showTOC {
            context.coordinator.lastShowTOC = showTOC
            let transform = showTOC ? "translateX(0)" : "translateX(-220px)"
            let pointer = showTOC ? "auto" : "none"
            let padding = showTOC ? "220px" : ""
            webView.evaluateJavaScript(
                "(function(){var t=document.getElementById('toc');if(t){t.style.transition='transform 0.3s ease';t.style.transform='\(transform)';t.style.pointerEvents='\(pointer)';document.body.style.transition='padding-left 0.3s ease';document.body.style.paddingLeft='\(padding)';}})();",
                completionHandler: nil)
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
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
            <script>\(Self.markedJS)</script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        </head>
        <body>
            <article class="markdown-body">
                <div id="content"></div>
            </article>
            <script>
                const mathBlock = {
                    name: 'mathBlock',
                    level: 'block',
                    start(src) { return src.indexOf('$$'); },
                    tokenizer(src) {
                        const match = src.match(/^\\$\\$([^]+?)\\$\\$/);
                        if (match) return { type: 'mathBlock', raw: match[0], text: match[1].trim() };
                    },
                    renderer(token) {
                        return '<p>' + katex.renderToString(token.text, { throwOnError: false, displayMode: true }) + '</p>';
                    }
                };
                const mathInline = {
                    name: 'mathInline',
                    level: 'inline',
                    start(src) { return src.indexOf('$'); },
                    tokenizer(src) {
                        const match = src.match(/^\\$([^\\$\\n]+?)\\$/);
                        if (match) return { type: 'mathInline', raw: match[0], text: match[1].trim() };
                    },
                    renderer(token) {
                        return katex.renderToString(token.text, { throwOnError: false, displayMode: false });
                    }
                };
                marked.use({ breaks: false, gfm: true, extensions: [mathBlock, mathInline] });
                const bytes = Uint8Array.from(atob('\(base64Markdown)'), c => c.charCodeAt(0));
                const raw = new TextDecoder().decode(bytes);
                const md = raw.replace(/!\\[([^\\]]*)\\]\\(([^)]+)\\)\\{([^}]+)\\}/g, function(_, alt, src, attrs) {
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
                });
                document.getElementById('content').innerHTML = marked.parse(md);
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
            </script>
        </body>
        </html>
        """
    }
}
