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

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
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
            </script>
        </body>
        </html>
        """
    }
}
