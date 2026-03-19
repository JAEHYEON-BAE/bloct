import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

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

    class Coordinator: NSObject, WKNavigationDelegate {
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
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(buildHTML(), baseURL: URL(string: "https://cdn.jsdelivr.net"))
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
                const md = new TextDecoder().decode(bytes);
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
