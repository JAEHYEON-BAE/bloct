import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// Only image responses cross into WebKit; the page never receives broad file access.
@MainActor
final class LocalImageLoader: NSObject, WKURLSchemeHandler {
    static let scheme = "bloct-image"
    private(set) var host = UUID().uuidString.lowercased()
    private var documentURL: URL?
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    func setDocumentURL(_ url: URL?) {
        guard documentURL != url else { return }
        invalidate()
        documentURL = url
        host = UUID().uuidString.lowercased()
    }

    func invalidate() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        documentURL = nil
    }

    func imageURL(for request: URLRequest) -> URL? {
        guard request.httpMethod == "GET", let url = request.url,
              url.scheme == Self.scheme, url.host == host,
              let documentURL, documentURL.isFileURL,
              let source = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "src" })?.value,
              let image = URL(string: source, relativeTo: documentURL.deletingLastPathComponent())?.absoluteURL,
              image.isFileURL, image.host == nil || image.host == "" || image.host == "localhost"
        else { return nil }
        return image.standardizedFileURL.resolvingSymlinksInPath()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let image = imageURL(for: urlSchemeTask.request),
              let type = UTType(filenameExtension: image.pathExtension), type.conforms(to: .image),
              let mime = type.preferredMIMEType, let requestURL = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        let key = ObjectIdentifier(urlSchemeTask)
        tasks[key] = Task {
            let result = await Task.detached {
                Result { () throws -> Data in
                    guard try image.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                        throw URLError(.noPermissionsToReadFile)
                    }
                    return try Data(contentsOf: image)
                }
            }.value
            guard !Task.isCancelled else { return }
            tasks[key] = nil
            switch result {
            case .success(let data):
                urlSchemeTask.didReceive(URLResponse(url: requestURL, mimeType: mime,
                                                    expectedContentLength: data.count, textEncodingName: nil))
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            case .failure(let error): urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }
}

// Keep WebKit's selection/link/editor menus, but route Reload to the document.
final class DocumentWebView: WKWebView, NSMenuItemValidation {
    var reloadDocument: (() -> Void)?
    var documentGeneration = 0
    private var keyMonitor: Any?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeKeyMonitor()
        guard window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "r" else { return event }
            self.reloadDocument?()
            return nil
        }
    }
    func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "r" {
            reloadDocument?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        for item in menu.items where item.title == "Reload" { menu.removeItem(item) }
        menu.addItem(.separator())
        let reload = NSMenuItem(title: "Reload", action: #selector(reloadSource), keyEquivalent: "")
        reload.target = self
        reload.isEnabled = reloadDocument != nil
        menu.addItem(reload)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(reloadSource) || reloadDocument != nil
    }
    @objc private func reloadSource() { reloadDocument?() }
}

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let fileURL: URL?
    let zoomLevel: Double
    let showTOC: Bool
    let isEditMode: Bool
    let webViewStore: WebViewStore
    var onCloseTOC: () -> Void = {}
    var onTextCommit: (String) -> Void = { _ in }
    var onEditorDirtyChanged: (Bool) -> Void = { _ in }
    var onReload: () -> Void = {}
    var onBeforeEdit: ((@escaping (Bool) -> Void) -> Void)? = nil
    var reloadGeneration: Int = 0

    private static let markedJS: String = {
        guard let url = Bundle.main.url(forResource: "marked.min", withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return content
    }()

    private static let purifyJS: String = {
        guard let url = Bundle.main.url(forResource: "purify.min", withExtension: "js"),
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

    @MainActor static func removeAllPreviewFiles() {
        PreviewFiles.removeAll()
    }

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
                            'background:var(--color-bg);' +
                            'border-right:1px solid var(--color-border);' +
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
                            'margin:4px 0;color:var(--color-text);text-decoration:none;' +
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
        let localImages = LocalImageLoader()
        var lastMarkdown: String? = nil
        var showTOC: Bool = true
        var lastShowTOC: Bool = true
        var lastEditMode: Bool = false
        var tempHTMLURL: URL?
        var onCloseTOC: () -> Void = {}
        var fileURL: URL?
        var isPageLoaded: Bool = false
        var pendingAutoFocus: Bool = false
        var inlinePageURL: URL?
        // Only one native bootstrap navigation may be in flight. Subsequent
        // SwiftUI updates replace lastMarkdown, not the page/navigation itself.
        final class PageLoad {
            enum Phase { case awaitingPolicy, loading, finished }
            let expectedURL: URL
            var navigation: WKNavigation?
            var phase = Phase.awaitingPolicy
            init(expectedURL: URL) { self.expectedURL = expectedURL }
        }
        private(set) var pageLoad: PageLoad?
        private(set) var isDismantled = false
        var imageOrigin = ""
        var onTextCommit: ((String) -> Void)?
        var onEditorDirtyChanged: ((Bool) -> Void)?
        var onBeforeEdit: ((@escaping (Bool) -> Void) -> Void)?
        var onReload: (() -> Void)?
        var reloadGeneration = 0

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !isDismantled, isPageLoaded, message.frameInfo.isMainFrame,
                  let url = message.webView?.url, isPreviewURL(url) else { return }
            switch message.name {
            case "closeTOC":
                DispatchQueue.main.async { [weak self] in self?.onCloseTOC() }
            case "scrollPosition":
                if let y = message.body as? Double, let url = fileURL {
                    UserDefaults.standard.set(y, forKey: "scrollPos:\(url.path)")
                }
            case "commitEdit":
                let payload = message.body as? [String: Any]
                let generation = (message.webView as? DocumentWebView)?.documentGeneration ?? 0
                let base64 = payload?["text"] as? String ?? (generation == 0 ? message.body as? String : nil)
                guard payload == nil || payload?["generation"] as? Int == generation else { return }
                if let base64,
                   let data = Data(base64Encoded: base64),
                   let text = String(data: data, encoding: .utf8) {
                    self.onTextCommit?(text)
                }
            case "editorDirty":
                if let dirty = message.body as? Bool {
                    self.onEditorDirtyChanged?(dirty)
                }
            case "reloadDocument":
                onReload?()
            case "beforeEdit":
                let generation = reloadGeneration
                onBeforeEdit? { [weak self, weak webView = message.webView] allowed in
                    guard let self, !self.isDismantled, self.isPageLoaded,
                          self.reloadGeneration == generation else { return }
                    webView?.evaluateJavaScript("window._mvResumeEdit && window._mvResumeEdit(\(allowed ? "true" : "false"));", completionHandler: nil)
                }
            case "openExternal":
                if let urlString = message.body as? String, let url = URL(string: urlString),
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    NSWorkspace.shared.open(url)
                }
            default:
                break
            }
        }

        private func isPreviewURL(_ url: URL) -> Bool {
            if let tempHTMLURL { return url == tempHTMLURL }
            return inlinePageURL != nil && (url == inlinePageURL || url.absoluteString == "about:blank")
        }

        func loadInitialPage(_ html: String, in webView: WKWebView, previewURL: URL?, baseURL: URL?) {
            guard !isDismantled, pageLoad == nil else { return }
            let load = PageLoad(expectedURL: previewURL ?? baseURL ?? URL(string: "about:blank")!)
            pageLoad = load
            isPageLoaded = false
            if let previewURL {
                tempHTMLURL = previewURL
                load.navigation = webView.loadFileURL(previewURL, allowingReadAccessTo: baseURL ?? previewURL.deletingLastPathComponent())
            } else {
                inlinePageURL = baseURL ?? URL(string: "about:blank")!
                load.navigation = webView.loadHTMLString(html, baseURL: baseURL)
            }
        }

        func renderLatestContent(in webView: WKWebView, reset: Bool) {
            guard let lastMarkdown else { return }
            let base64 = Data(lastMarkdown.utf8).base64EncodedString()
            let stale = reset ? "window._mvStale = true;" : ""
            webView.evaluateJavaScript("window._mvGeneration = \(reloadGeneration); window._mvImageOrigin = '\(imageOrigin)'; \(stale) window._mvRender && window._mvRender('\(base64)');", completionHandler: nil)
        }

        func dismantle(_ webView: WKWebView) {
            isDismantled = true
            isPageLoaded = false
            pageLoad = nil
            webView.stopLoading()
            webView.navigationDelegate = nil
            onTextCommit = nil
            onEditorDirtyChanged = nil
            onBeforeEdit = nil
            onReload = nil
            onCloseTOC = {}
            (webView as? DocumentWebView)?.reloadDocument = nil
            localImages.invalidate()
            if let tempHTMLURL { PreviewFiles.remove(tempHTMLURL) }
            tempHTMLURL = nil
            inlinePageURL = nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard !isDismantled, let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if let load = pageLoad, load.phase == .awaitingPolicy,
               navigationAction.targetFrame?.isMainFrame == true,
               navigationAction.navigationType == .other, url == load.expectedURL {
                load.phase = .loading
                decisionHandler(.allow)
                return
            }
            // Do not let untrusted documents replace the page that owns the bridge.
            if navigationAction.navigationType == .linkActivated,
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isDismantled, let navigation, let load = pageLoad,
                  load.phase == .loading, navigation === load.navigation else { return }
            load.phase = .finished
            isPageLoaded = true
            // The initial HTML may contain an older snapshot. Apply the latest
            // text, resource origin and document generation before installing UI.
            renderLatestContent(in: webView, reset: true)
            // Do NOT delete tempHTMLURL here — WKWebView's sandboxed content process
            // needs the origin file to exist in order to resolve and load local images
            // (file:// src attributes) throughout the page's lifetime. The file is
            // deleted when this WebView is dismantled.
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
            // _findAnchor is also exposed for the TOC toggle (see updateNSView).
            webView.evaluateJavaScript("""
                (function() {
                    var _anchor = null, _anchorTop = 0, _tid = null, _raf = null;
                    window._mvFindAnchor = _findAnchor;
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
            // Edit-mode changes made before the page finished loading were dropped; apply now.
            if lastEditMode {
                webView.evaluateJavaScript("window._mvSetEditMode && window._mvSetEditMode(true);", completionHandler: nil)
            }
            if pendingAutoFocus {
                pendingAutoFocus = false
                webView.evaluateJavaScript("""
                    (function() {
                        var el = document.querySelector('.mv-block') || document.getElementById('mv-append-zone');
                        if (el && window._mvStartBlockEdit) window._mvStartBlockEdit(el, 0, false);
                    })();
                    """, completionHandler: nil)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failPageLoad(navigation)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failPageLoad(navigation)
        }

        private func failPageLoad(_ navigation: WKNavigation?) {
            guard !isDismantled, let navigation, let load = pageLoad,
                  load.phase == .loading, navigation === load.navigation else { return }
            isPageLoaded = false
            pageLoad = nil
            lastMarkdown = nil // A later SwiftUI update may retry a failed bootstrap.
            if let tempHTMLURL { PreviewFiles.remove(tempHTMLURL) }
            tempHTMLURL = nil
            inlinePageURL = nil
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.localImages, forURLScheme: LocalImageLoader.scheme)
        let handler = WeakMessageHandler(context.coordinator)
        for name in ["openExternal", "closeTOC", "scrollPosition", "commitEdit", "editorDirty", "beforeEdit", "reloadDocument"] {
            config.userContentController.add(handler, name: name)
        }
        let webView = DocumentWebView(frame: .zero, configuration: config)
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

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        (webView as? DocumentWebView)?.removeKeyMonitor()
        coordinator.dismantle(webView)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        webViewStore.webView = webView
        coordinator.showTOC = showTOC
        coordinator.onCloseTOC = onCloseTOC
        let locationChanged = coordinator.fileURL != fileURL
        coordinator.fileURL = fileURL
        coordinator.localImages.setDocumentURL(fileURL)
        let imageOrigin = fileURL == nil ? "" : "\(LocalImageLoader.scheme)://\(coordinator.localImages.host)/"
        coordinator.imageOrigin = imageOrigin
        coordinator.onTextCommit = onTextCommit
        coordinator.onEditorDirtyChanged = onEditorDirtyChanged
        coordinator.onBeforeEdit = onBeforeEdit
        coordinator.onReload = onReload
        (webView as? DocumentWebView)?.reloadDocument = fileURL == nil ? nil : onReload
        (webView as? DocumentWebView)?.documentGeneration = reloadGeneration
        let forcedReload = coordinator.reloadGeneration != reloadGeneration
        coordinator.reloadGeneration = reloadGeneration
        if coordinator.lastEditMode != isEditMode {
            coordinator.lastEditMode = isEditMode
            // Before the page has loaded, didFinish applies lastEditMode instead.
            if coordinator.isPageLoaded {
                let flag = isEditMode ? "true" : "false"
                webView.evaluateJavaScript("window._mvSetEditMode && window._mvSetEditMode(\(flag));", completionHandler: nil)
            }
        }
        if coordinator.lastMarkdown != markdown || locationChanged || forcedReload {
            coordinator.lastMarkdown = markdown
            if coordinator.isPageLoaded {
                // Live edit: update only the content in-place, no page reload, scroll is preserved
                coordinator.renderLatestContent(in: webView, reset: locationChanged || forcedReload)
            } else if coordinator.pageLoad == nil {
                // didFinish applies the current TOC state, so no toggle animation is needed.
                coordinator.lastShowTOC = showTOC
                let html = buildHTML(imageOrigin: imageOrigin)
                if let fileURL = fileURL {
                    let dir = fileURL.deletingLastPathComponent()
                    do {
                        let tmpURL = try PreviewFiles.create(html: html, in: dir)
                        coordinator.loadInitialPage(html, in: webView, previewURL: tmpURL, baseURL: dir)
                    } catch {
                        coordinator.loadInitialPage(html, in: webView, previewURL: nil, baseURL: dir)
                    }
                } else {
                    coordinator.pendingAutoFocus = true
                    coordinator.loadInitialPage(html, in: webView, previewURL: nil, baseURL: nil)
                }
            }
        }
        if coordinator.lastShowTOC != showTOC {
            coordinator.lastShowTOC = showTOC
            let transform = showTOC ? "translateX(0)" : "translateX(-220px)"
            let pointer = showTOC ? "auto" : "none"
            let padding = showTOC ? "220px" : ""
            let js = """
            (function(){
                var t = document.getElementById('toc');
                if (!t) return;
                // First block-level element at the top of the viewport.
                var anchor = window._mvFindAnchor ? window._mvFindAnchor() : null;
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
        if webView.pageZoom != zoomLevel {
            webView.pageZoom = zoomLevel
        }
    }

    func buildHTML(imageOrigin: String = "") -> String {
        let base64Markdown = Data(markdown.utf8).base64EncodedString()
        let nonce = UUID().uuidString

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)'; script-src-attr 'none'; style-src 'unsafe-inline' https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css; font-src https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/fonts/; img-src file: bloct-image: data: https: http:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
            <meta name="color-scheme" content="light dark">
            <style>\(Self.css)</style>
            <style>
                .mv-block { display: contents; }
                .mv-block:has(> hr:only-child) { display: block; min-height: 2em; }
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
            <script nonce="\(nonce)">\(Self.purifyJS)</script>
            <script nonce="\(nonce)">\(Self.markedJS)</script>
            <script nonce="\(nonce)" src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        </head>
        <body>
            <article class="markdown-body">
                <div id="content"></div>
            </article>
            <script nonce="\(nonce)">
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
                        data.attrValue = data.attrValue.split(/\\s+/).filter(function(c) {
                            return !c.startsWith('mv-') && c !== 'markdown-body';
                        }).join(' ');
                    }
                });
                window._mvImageOrigin = '\(imageOrigin)';
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
                // Override strong tokenizer: CommonMark's punctuation-flanking rule rejects
                // closing ** when preceded by ) and followed by a non-space/non-punct char
                // (e.g. a Korean letter). We only require content not to start/end with whitespace.
                const permissiveStrong = {
                    extensions: [{
                        name: 'strong',
                        level: 'inline',
                        start(src) { return src.indexOf('**'); },
                        tokenizer(src) {
                            const match = /^\\*\\*(?!\\s)((?:[^*\\\\]|\\\\[\\s\\S]|\\*(?!\\*))*?)(?<!\\s)\\*\\*(?!\\*)/.exec(src);
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
                            if (/^\\*\\*/.test(src)) return;
                            const match = /^\\*(?!\\s)((?:[^*\\\\]|\\\\[\\s\\S])*?)(?<!\\s)\\*(?!\\*)/.exec(src);
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
                function _mvRenderOneBlock(blockRaw) {
                    var mathStore = [], codeStore = [];
                    // Choose a per-render namespace absent from the original source.
                    // Literal MVCODE/MVMATH strings are ordinary document text.
                    var prefix;
                    do { prefix = 'MV' + Math.random().toString(36).slice(2) + 'Q'; }
                    while (blockRaw.includes(prefix));
                    var codePattern = new RegExp(prefix + 'CODE([0-9]+)X', 'g');
                    var mathPattern = new RegExp(prefix + 'MATH([0-9]+)X', 'g');
                    var md = blockRaw
                        .replace(/!\\[([^\\]]*)\\]\\(([^)]+)\\)\\{([^}]+)\\}/g, function(_, alt, src, attrs) {
                            let style = '';
                            const w = attrs.match(/width\\s*=\\s*([^\\s,}]+)/);
                            const h = attrs.match(/height\\s*=\\s*([^\\s,}]+)/);
                            const a = attrs.match(/align\\s*=\\s*([^\\s,}]+)/);
                            if (w && /^(?:[0-9]+(?:\\.[0-9]+)?)(?:px|%|em|rem|vw|vh)?$/.test(w[1])) { const v = w[1]; style += 'width:' + (/^[\\d.]+$/.test(v) ? v + 'px' : v) + ';'; }
                            if (h && /^(?:[0-9]+(?:\\.[0-9]+)?)(?:px|%|em|rem|vw|vh)?$/.test(h[1])) { const v = h[1]; style += 'height:' + (/^[\\d.]+$/.test(v) ? v + 'px' : v) + ';'; }
                            const img = document.createElement('img');
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
                        })
                        .replace(/^(`{3,}|~{3,})[^\\n]*\\n[\\s\\S]*?\\n\\1[ \\t]*$/mg, function(match) {
                            codeStore.push(match); return prefix + 'CODE' + (codeStore.length - 1) + 'X';
                        })
                        .replace(/`+[^`\\n]*`+/g, function(match) {
                            codeStore.push(match); return prefix + 'CODE' + (codeStore.length - 1) + 'X';
                        })
                        .replace(/\\$\\$([\\s\\S]+?)\\$\\$/g, function(match, tex, offset, str) {
                            var before = str.substring(0, offset);
                            var after = str.substring(offset + match.length);
                            var blankBefore = /\\n[ \\t]*\\n[ \\t]*$/.test(before) || /^[ \\t]*$/.test(before);
                            var blankAfter = /^[ \\t]*\\n[ \\t]*\\n/.test(after) || /^[ \\t]*$/.test(after);
                            var isBlock = blankBefore && blankAfter;
                            mathStore.push({ display: true, tex: tex.trim() });
                            var ph = prefix + 'MATH' + (mathStore.length - 1) + 'X';
                            return isBlock ? '\\n\\n' + ph + '\\n\\n' : ph;
                        })
                        .replace(/\\$((?:[^\\$\\\\\\n]|\\\\.)+?)\\$/g, function(_, tex) {
                            mathStore.push({ display: false, tex: tex.trim() });
                            return prefix + 'MATH' + (mathStore.length - 1) + 'X';
                        })
                        .replace(codePattern, function(match, i) { return codeStore[+i] ?? match; });
                    var _hasBlockquote = /^>/m.test(md);
                    md = md.replace(/^(#{1,6}|[-*+]|>|\\d+[.)])[ \\t]*$/mg, function(_, m) {
                        if (m === '>' && _hasBlockquote) return m;
                        return '<span>' + m.replace(/&/g,'&amp;').replace(/</g,'&lt;') + '</span>';
                    });
                    var html = marked.parse(md);
                    html = html.replace(mathPattern, function(match, i) {
                        return mathStore[+i] ? _mvRenderMath(mathStore[+i]) : match;
                    });
                    return _mvSanitize(html);
                }

                // KaTeX comes from a CDN; when offline it is undefined, so fall back to the
                // raw TeX instead of throwing and leaving the whole document blank.
                function _mvRenderMath(item) {
                    if (typeof katex === 'undefined') {
                        var d = item.display ? '$$' : '$';
                        return (d + item.tex + d).replace(/&/g, '&amp;').replace(/</g, '&lt;');
                    }
                    return katex.renderToString(item.tex, { throwOnError: false, displayMode: item.display });
                }

                function _mvSafeDecodeURI(s) {
                    try { return decodeURIComponent(s); } catch (e) { return s; }
                }

                // Rebuild #content from raw markdown without touching scroll position.
                // Also makes _mvRawLines (the line model used by block editing) match the DOM.
                function _mvRenderRaw(raw) {
                    window._mvRawLines = raw.split('\\n');
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
                    var fullHtml = blocks.map(function(b) {
                        var blockText = window._mvRawLines.slice(b.start, b.end).join('\\n');
                        return '<div class="mv-block" data-start="' + b.start + '" data-end="' + b.end + '">'
                            + _mvRenderOneBlock(blockText) + '</div>';
                    }).join('');
                    fullHtml += '<div id="mv-append-zone" data-start="'
                        + window._mvRawLines.length + '" data-end="' + window._mvRawLines.length + '"></div>';
                    var content = document.getElementById('content');
                    content.innerHTML = fullHtml;

                    content.querySelectorAll('a[href^="#"]').forEach(function(a) {
                        a.setAttribute('href', _mvSafeDecodeURI(a.getAttribute('href')).replace(/-+/g, '-'));
                    });
                    content.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(h) {
                        h.id = h.textContent.trim().toLowerCase()
                            .replace(/[^\\p{L}\\p{N}\\s-]/gu, '')
                            .trim()
                            .replace(/\\s+/g, '-')
                            .replace(/-+/g, '-');
                    });
                    if (window._mvBuildTOC) window._mvBuildTOC();
                    if (window._mvSearch) window._mvSearch.refresh();
                }

                // Called by Swift with the base64-encoded document on initial load and
                // whenever the document text changes (commit echo, undo/redo).
                window._mvRender = function(base64md) {
                    var bytes = Uint8Array.from(atob(base64md), c => c.charCodeAt(0));
                    var raw = new TextDecoder().decode(bytes);
                    var current = window._mvRawLines ? window._mvRawLines.join('\\n') : null;
                    if (raw === current && !window._mvStale) return;  // already rendered locally
                    if (window._mvActiveEl) {
                        // Rebuilding #content would destroy the open editor. Keep it if it has
                        // edits (_mvCloseEditor re-renders later); otherwise drop it, e.g. on undo.
                        if (window._mvBlockDirty) { window._mvStale = true; return; }
                        window._mvCloseEditor(false);
                    }
                    _mvRenderRaw(raw);
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

                // First rendered block that covers or follows a raw line index.
                function _mvBlockAtLine(line) {
                    var blocks = document.querySelectorAll('#content .mv-block');
                    for (var i = 0; i < blocks.length; i++) {
                        if (+blocks[i].getAttribute('data-end') > line) return blocks[i];
                    }
                    return document.getElementById('mv-append-zone');
                }

                // Block editing state
                document.addEventListener('keydown', function(e) {
                    if (e.metaKey && !e.ctrlKey && !e.altKey && !e.shiftKey && e.key.toLowerCase() === 'r') {
                        e.preventDefault();
                        window.webkit.messageHandlers.reloadDocument.postMessage(true);
                    }
                }, true);
                window._mvCheckBeforeEdit = \(onBeforeEdit == nil ? "false" : "true");
                window._mvActiveEl = null;
                window._mvActiveStartLine = -1;
                window._mvActiveEndLine = -1;
                window._mvBlockDirty = false;

                // Close the inline block editor. commit=true posts the full text to Swift.
                // focusNext / focusPrev then open the following / preceding block.
                window._mvCloseEditor = function(commit, focusNext, focusPrev) {
                    var ta = document.getElementById('mv-block-editor');
                    var prevEl = window._mvActiveEl;
                    var wasAppendZone = prevEl && prevEl.id === 'mv-append-zone';
                    var wasDirty = window._mvBlockDirty;
                    var savedStartLine = window._mvActiveStartLine;
                    var savedEndLine = window._mvActiveEndLine;
                    window._mvBlockDirty = false;
                    window._mvComposing = false;
                    if (ta) ta.remove();
                    if (prevEl) prevEl.style.display = '';
                    window._mvActiveEl = null;
                    if (wasDirty) window.webkit.messageHandlers.editorDirty.postMessage(false);
                    if (commit && prevEl) {
                        // Text typed into the append zone needs a blank separator line so it
                        // doesn't merge into the previous block.
                        if (wasAppendZone && savedStartLine > 0
                                && window._mvRawLines.length > savedStartLine
                                && window._mvRawLines[savedStartLine - 1].trim() !== '') {
                            window._mvRawLines.splice(savedStartLine, 0, '');
                            savedEndLine += 1;
                        }
                        var text = window._mvRawLines.join('\\n');
                        window.webkit.messageHandlers.commitEdit.postMessage({text:btoa(unescape(encodeURIComponent(text))), generation:window._mvGeneration || 0});
                    }
                    // Re-render immediately so every block's data-start/data-end matches
                    // _mvRawLines again; Swift's echo _mvRender with the same text is a no-op.
                    if ((commit && wasDirty) || window._mvStale) {
                        _mvRenderRaw(window._mvRawLines.join('\\n'));
                    }
                    if (focusNext || focusPrev) {
                        var blocks = document.querySelectorAll('#content .mv-block');
                        var target = null;
                        if (focusNext) {
                            for (var i = 0; i < blocks.length; i++) {
                                if (+blocks[i].getAttribute('data-start') >= savedEndLine) { target = blocks[i]; break; }
                            }
                            if (!target) target = document.getElementById('mv-append-zone');
                        } else {
                            for (var i = blocks.length - 1; i >= 0; i--) {
                                if (+blocks[i].getAttribute('data-end') <= savedStartLine) { target = blocks[i]; break; }
                            }
                        }
                        if (target) window._mvStartBlockEdit(target, Infinity, true);
                    }
                };

                // Replace a .mv-block with an inline textarea for direct markdown editing.
                window._mvResumeEdit = function(allowed) {
                    var pending = window._mvPendingEdit;
                    window._mvPendingEdit = null;
                    if (allowed && pending && pending[0].isConnected) {
                        window._mvStartBlockEdit(pending[0], pending[1], pending[2], true);
                    }
                };
                window._mvStartBlockEdit = function(blockEl, charOffset, scrollTo, checked) {
                    if (window._mvDiskChecking) return;
                    if (!checked && window._mvCheckBeforeEdit) {
                        window._mvPendingEdit = [blockEl, charOffset, scrollTo];
                        window.webkit.messageHandlers.beforeEdit.postMessage(true);
                        return;
                    }
                    if (window._mvActiveEl === blockEl) return;
                    if (window._mvActiveEl) {
                        // Closing the open editor may re-render #content and detach blockEl.
                        // Remember its line, shifted by the lines the closed edit added or
                        // removed, so the matching block can be found in the new DOM.
                        var prevEnd = +window._mvActiveEl.getAttribute('data-end');
                        var line = +blockEl.getAttribute('data-start');
                        if (line >= prevEnd) line += window._mvActiveEndLine - prevEnd;
                        var isAppendZone = blockEl.id === 'mv-append-zone';
                        window._mvCloseEditor(true);
                        if (!blockEl.isConnected) {
                            blockEl = isAppendZone ? document.getElementById('mv-append-zone') : _mvBlockAtLine(line);
                            if (!blockEl) return;
                        }
                    }

                    var start = +blockEl.getAttribute('data-start');
                    var end = +blockEl.getAttribute('data-end');
                    window._mvActiveEl = blockEl;
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

                    ta.addEventListener('compositionstart', function() { window._mvComposing = true; });
                    ta.addEventListener('compositionend', function() { window._mvComposing = false; });
                    ta.addEventListener('input', function() {
                        if (!window._mvBlockDirty) {
                            window._mvBlockDirty = true;
                            window.webkit.messageHandlers.editorDirty.postMessage(true);
                        }
                        var newLines = ta.value.split('\\n');
                        window._mvRawLines = window._mvRawLines.slice(0, window._mvActiveStartLine)
                            .concat(newLines)
                            .concat(window._mvRawLines.slice(window._mvActiveEndLine));
                        window._mvActiveEndLine = window._mvActiveStartLine + newLines.length;
                        ta.style.height = 'auto';
                        ta.style.height = ta.scrollHeight + 'px';
                    });
                    ta.addEventListener('keydown', function(e) {
                        if (e.key === 'Escape') { e.preventDefault(); window._mvCloseEditor(true); }
                        if (e.key === 'Enter' && e.metaKey && !e.shiftKey) {
                            e.preventDefault();
                            window._mvCloseEditor(true, true, false);
                        }
                        if (e.key === 'Enter' && e.metaKey && e.shiftKey) {
                            e.preventDefault();
                            window._mvCloseEditor(true, false, true);
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

                // Edit mode flag — toggled by Swift via _mvSetEditMode.
                window._mvEditMode = false;
                window._mvSetEditMode = function(on) {
                    window._mvEditMode = on;
                    document.getElementById('content').style.cursor = on ? 'text' : '';
                    if (!on && window._mvActiveEl) window._mvCloseEditor(true);
                };

                // Click in the bottom padding area — forward to the append zone.
                document.addEventListener('click', function(e) {
                    if (!window._mvEditMode) return;
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
                    if (!window._mvEditMode) return;
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
                window._mvSearch = (function() {
                    var marks = [], idx = 0, term = '';
                    function removeMarks() {
                        document.querySelectorAll('mark.mv-hl').forEach(function(m) {
                            var p = m.parentNode;
                            if (p) { p.replaceChild(document.createTextNode(m.textContent), m); p.normalize(); }
                        });
                        marks = []; idx = 0;
                    }
                    function highlight(text, keepScroll) {
                        removeMarks();
                        term = text || '';
                        if (!term) return;
                        var lo = term.toLowerCase();
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
                        if (marks.length) {
                            marks[0].style.background = '#FF8C00';
                            if (!keepScroll) marks[0].scrollIntoView({behavior:'smooth',block:'center'});
                        }
                    }
                    // Re-apply the current search after #content is re-rendered.
                    function refresh() { if (term) highlight(term, true); }
                    function clear() { term = ''; removeMarks(); }
                    function navigate(fwd) {
                        if (!marks.length) return;
                        marks[idx].style.background = '#FFD700';
                        idx = (idx + (fwd ? 1 : marks.length - 1)) % marks.length;
                        marks[idx].style.background = '#FF8C00';
                        marks[idx].scrollIntoView({behavior:'smooth',block:'center'});
                    }
                    return {highlight: highlight, navigate: navigate, clear: clear, refresh: refresh};
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
                        case 'img': return '![' + (node.getAttribute('alt') || '') + '](' + (node.getAttribute('data-mv-image-source') || node.getAttribute('src') || '') + ')';
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
