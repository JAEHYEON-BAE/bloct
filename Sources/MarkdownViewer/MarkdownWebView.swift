import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fileURL: URL?
    let zoomLevel: Double
    let showTOC: Bool
    let webViewStore: WebViewStore

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
            if (headings.length < 2) return;
            var toc = document.createElement('nav');
            toc.id = 'toc';
            toc.style.cssText = 'position:fixed;top:0;left:0;width:220px;height:100vh;' +
                'background:var(--color-canvas-default,Canvas);' +
                'border-right:1px solid var(--color-border-default,GrayText);' +
                'padding:20px 14px;overflow-y:auto;z-index:100;box-sizing:border-box;' +
                'transition:transform 0.3s ease;';
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

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastMarkdown: String = ""
        var showTOC: Bool = true
        var lastShowTOC: Bool = true
        var tempHTMLURL: URL?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            // Same-page anchor: fragment present, no real path (resolves to base URL)
            if let fragment = url.fragment, url.path == "" || url.path == "/", url.query == nil {
                decisionHandler(.cancel)
                let safe = fragment.replacingOccurrences(of: "\\", with: "\\\\")
                                   .replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript(
                    "var el=document.getElementById('\(safe)');if(el)el.scrollIntoView({behavior:'smooth'});",
                    completionHandler: nil)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
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
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        webViewStore.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.showTOC = showTOC
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
                document.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(h) {
                    h.id = h.textContent.trim().toLowerCase()
                        .replace(/[^\\w\\s-]/g, '')
                        .trim()
                        .replace(/\\s+/g, '-');
                });
            </script>
        </body>
        </html>
        """
    }
}
