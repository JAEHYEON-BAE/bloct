import AppKit
import SwiftUI
import WebKit

@main
struct WebKitRegression {
    @MainActor static func wait(_ label: String, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(25)
        while !predicate() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(predicate(), "Timed out: \(label)")
    }

    @MainActor static func js(_ webView: WKWebView, _ body: String,
                              arguments: [String: Any] = [:]) -> Any? {
        var done = false
        var output: Any?
        var failure: Error?
        webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) { result in
            switch result {
            case .success(let value): output = value
            case .failure(let error): failure = error
            }
            done = true
        }
        wait("JavaScript", until: { done })
        precondition(failure == nil, "JavaScript failed: \(String(describing: failure))")
        return output
    }

    @MainActor static func check(_ webView: WKWebView, _ expression: String, _ label: String) {
        precondition(js(webView, "return !!(\(expression));") as? Bool == true, label)
        print("PASS: \(label)")
    }

    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let view = MarkdownWebView(markdown: "# Initial\n\nText", fileURL: nil,
                                   zoomLevel: 1, showTOC: false, isEditMode: false,
                                   webViewStore: WebViewStore())
        // Deterministic offline checks: omit only the two external KaTeX resources.
        // All bundled scripts, nonce CSP, renderer and coordinator are production code.
        let html = view.buildHTML()
            .replacingOccurrences(of: #"<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex[^"]+">"#,
                                  with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<script nonce="[^"]+" src="https://cdn.jsdelivr.net/npm/katex[^"]+"></script>"#,
                                  with: "", options: .regularExpression)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-webkit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            PreviewFiles.removeAll()
            try? FileManager.default.removeItem(at: directory)
        }
        let page = try PreviewFiles.create(html: html, in: directory)
        let coordinator = MarkdownWebView.Coordinator()
        coordinator.showTOC = false
        var commits: [String] = []
        coordinator.onTextCommit = { commits.append($0) }
        let config = WKWebViewConfiguration()
        for name in ["openExternal", "closeTOC", "scrollPosition", "commitEdit", "editorDirty"] {
            config.userContentController.add(coordinator, name: name)
        }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 800), configuration: config)
        webView.navigationDelegate = coordinator
        coordinator.loadInitialPage(html, in: webView, previewURL: page, baseURL: directory)
        wait("file page load", until: { coordinator.isPageLoaded })
        check(webView, "typeof DOMPurify !== 'undefined' && DOMPurify.isSupported && document.querySelector('h1').textContent === 'Initial'", "bundled sanitizer and initial renderer load under CSP")

        func render(_ raw: String) {
            _ = js(webView, "window._mvRender(md); return true;", arguments: ["md": Data(raw.utf8).base64EncodedString()])
        }
        render("MVMATH0X MVCODE0X MVMATH999X MVCODE999X and $x$ and `safe`")
        check(webView, "document.getElementById('content').textContent.includes('MVMATH0X MVCODE0X MVMATH999X MVCODE999X')", "literal internal-looking placeholders remain unchanged")
        render("**bold** and `code` and $x$\n\n$$y$$")
        check(webView, "document.querySelector('strong').textContent === 'bold' && document.querySelector('code').textContent === 'code' && document.getElementById('content').textContent.includes('$x$') && document.getElementById('content').textContent.includes('$$y$$')", "Markdown and offline inline/display math survive sanitizing")
        // A KaTeX-shaped fixture checks the sanitizer's MathML/SVG/style compatibility.
        let mathHTML = "<span class=\"katex\"><span class=\"katex-mathml\"><math><semantics><mi>x</mi><annotation encoding=\"application/x-tex\">x</annotation></semantics></math></span><span class=\"katex-html\" style=\"height:1em\">x<svg><path d=\"M0 0\"></path></svg></span></span>"
        _ = js(webView, "document.getElementById('content').innerHTML = _mvSanitize(html); return true;", arguments: ["html": mathHTML])
        check(webView, "!!document.querySelector('.katex annotation') && !!document.querySelector('.katex svg path')", "sanitizer preserves math markup")

        let attack = #"<img src="missing" onerror="window.webkit.messageHandlers.commitEdit.postMessage(btoa('changed'))"><svg onload="window._mvPwned=1"></svg><a href="javascript:window._mvPwned=2">bad</a><iframe srcdoc="<script>parent._mvPwned=3</script>"></iframe><base href="https://example.invalid/"><meta http-equiv="refresh" content="0;url=https://example.invalid"><form><textarea id="mv-block-editor">fake</textarea></form><div class="mv-block mv-hl" id="toc" data-start="0">fake</div>"#
        render(attack)
        _ = js(webView, "await new Promise(r => setTimeout(r, 100)); return true;")
        check(webView, "!document.querySelector('#content [onerror], #content [onload], #content iframe, #content base, #content meta, #content form, #content textarea, #content [data-start]:not(.mv-block):not(#mv-append-zone), #content #toc') && !document.querySelector('#content a').hasAttribute('href') && !window._mvPwned", "untrusted HTML loses executable attributes, dangerous URLs and editor impersonation")
        check(webView, "document.querySelectorAll('#content .mv-block').length === 1", "user HTML cannot create editor blocks")
        wait("bridge callbacks drain", until: { !webView.isLoading })
        precondition(commits.isEmpty, "Untrusted HTML must not commit edits")
        print("PASS: malicious HTML cannot send an edit through the native bridge")

        render("![x\" onerror=\"window._mvPwned=4](file:///tmp/picture.png){width=30,height=40,align=center}")
        check(webView, "document.querySelector('#content img').getAttribute('src') === 'file:///tmp/picture.png' && !document.querySelector('#content img').hasAttribute('onerror') && document.querySelector('#content img').style.width === '30px'", "custom image attributes are escaped and local image URLs survive")
        render("![x](images/picture.png)")
        check(webView, "document.querySelector('#content img').getAttribute('src') === 'images/picture.png'", "relative local images survive sanitizing")

        let pixel = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=")!
        try pixel.write(to: directory.appendingPathComponent("pixel.png"))
        render("![pixel](pixel.png)")
        let imageLoaded = js(webView, """
            const image = document.querySelector('#content img');
            try { await image.decode(); return image.naturalWidth === 1; }
            catch (_) { return false; }
            """) as? Bool
        precondition(imageLoaded == true, "Local image must load from an owned preview origin")
        print("PASS: relative local image actually loads from the unique preview file")

        // CSP must also block an event attribute and non-nonced script deliberately
        // inserted outside the sanitizer by this trusted test driver.
        _ = js(webView, """
            const img = document.createElement('img');
            img.setAttribute('onerror', 'window._mvCSPFailed = true');
            img.src = 'missing-csp-test'; document.body.appendChild(img);
            const s = document.createElement('script');
            s.textContent = 'window._mvCSPFailed = true'; document.body.appendChild(s);
            await new Promise(r => setTimeout(r, 100));
            return true;
            """)
        check(webView, "!window._mvCSPFailed", "CSP independently blocks event handlers and untrusted inline scripts")
        _ = js(webView, "location.href = 'https://example.invalid/'; await new Promise(r => setTimeout(r, 100)); return true;")
        precondition(webView.url == page, "Navigation must not replace the bridge-owning page")
        print("PASS: remote page navigation is blocked")

        // Verify native bridge integration for a legitimate commit as well.
        _ = js(webView, "window.webkit.messageHandlers.commitEdit.postMessage(btoa('legitimate')); await new Promise(r => setTimeout(r, 100)); return true;")
        wait("legitimate commit", until: { commits == ["legitimate"] })
        print("PASS: authorized preview can still commit through the native bridge")

        let inlineCoordinator = MarkdownWebView.Coordinator()
        let inlineConfig = WKWebViewConfiguration()
        for name in ["closeTOC", "scrollPosition", "commitEdit", "editorDirty", "openExternal"] {
            inlineConfig.userContentController.add(inlineCoordinator, name: name)
        }
        let inlineView = WKWebView(frame: .zero, configuration: inlineConfig)
        inlineView.navigationDelegate = inlineCoordinator
        inlineCoordinator.loadInitialPage(html, in: inlineView, previewURL: nil, baseURL: nil)
        wait("inline page load", until: { inlineCoordinator.isPageLoaded })
        check(inlineView, "!!document.querySelector('h1')", "new-document inline HTML load works with navigation policy")
        var inlineCommit = false
        inlineCoordinator.onTextCommit = { inlineCommit = $0 == "new document" }
        _ = js(inlineView, "window.webkit.messageHandlers.commitEdit.postMessage(btoa('new document')); await new Promise(r => setTimeout(r, 100)); return true;")
        wait("inline commit", until: { inlineCommit })
        print("PASS: new-document inline page retains native bridge access")
    }
}
