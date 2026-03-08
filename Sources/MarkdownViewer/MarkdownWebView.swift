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
        webView.loadHTMLString(buildHTML(), baseURL: nil)
    }

    private func buildHTML() -> String {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="color-scheme" content="light dark">
            <style>\(Self.css)</style>
            <script>\(Self.markedJS)</script>
        </head>
        <body>
            <article class="markdown-body">
                <div id="content"></div>
            </article>
            <script>
                marked.use({ breaks: false, gfm: true });
                document.getElementById('content').innerHTML = marked.parse(`\(escaped)`);
            </script>
        </body>
        </html>
        """
    }
}
