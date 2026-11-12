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
    let webViewStore: WebViewStore
    var onCloseTOC: () -> Void = {}
    var onTextCommit: (String) -> Void = { _ in }
    var onEditorDirtyChanged: (Bool) -> Void = { _ in }
    var onReload: () -> Void = {}
    var reloadGeneration: Int = 0
    var visualEditing: Bool = false
    var savedMarkdown: String? = nil
    var automaticEditing: Bool = false
    var onEditingRequested: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        var lastVisualEditing: Bool = false
        var savedMarkdown = ""
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
        var onReload: (() -> Void)?
        var onEditingRequested: ((Bool) -> Void)?
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
                if let payload = message.body as? [String: Any],
                   payload["generation"] as? Int == (message.webView as? DocumentWebView)?.documentGeneration,
                   let dirty = payload["dirty"] as? Bool {
                    self.onEditorDirtyChanged?(dirty)
                } else if let dirty = message.body as? Bool {
                    self.onEditorDirtyChanged?(dirty)
                }
            case "reloadDocument":
                onReload?()
            case "editorModeRequest":
                guard let payload = message.body as? [String: Any],
                      payload["generation"] as? Int == (message.webView as? DocumentWebView)?.documentGeneration,
                      let editing = payload["editing"] as? Bool else { return }
                onEditingRequested?(editing)
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
            webView.callAsyncJavaScript("""
                window._mvGeneration = generation;
                window._mvImageOrigin = imageOrigin;
                if (reset) window._mvStale = true;
                window._mvRender && window._mvRender(markdown);
                """, arguments: ["generation": reloadGeneration, "imageOrigin": imageOrigin, "reset": reset,
                                 "markdown": Data(lastMarkdown.utf8).base64EncodedString()],
                in: nil, in: .page, completionHandler: nil)
        }

        func dismantle(_ webView: WKWebView) {
            isDismantled = true
            isPageLoaded = false
            pageLoad = nil
            webView.stopLoading()
            webView.navigationDelegate = nil
            onTextCommit = nil
            onEditorDirtyChanged = nil
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
            // TOC, remembered scroll position and resize anchor (page-host.js).
            let savedScrollY = fileURL.map { UserDefaults.standard.double(forKey: "scrollPos:\($0.path)") } ?? 0
            webView.callAsyncJavaScript("window._mvInstallHost(options);",
                arguments: ["options": ["showTOC": showTOC, "savedScrollY": savedScrollY]],
                in: nil, in: .page, completionHandler: nil)
            // Apply the latest Aa request even if it changed during bootstrap.
            webView.callAsyncJavaScript("""
                await window._mvSwitchEditor(on, baseline);
                if (focus) window._bloctVisual?.focus();
                return true;
                """, arguments: ["on":lastVisualEditing,"baseline":savedMarkdown,"focus":pendingAutoFocus], in:nil, in:.page,
                completionHandler:nil)
            pendingAutoFocus = false;
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
        config.preferences.tabFocusesLinks = true // Include task controls in Tab navigation on macOS.
        config.setURLSchemeHandler(context.coordinator.localImages, forURLScheme: LocalImageLoader.scheme)
        let handler = WeakMessageHandler(context.coordinator)
        for name in ["openExternal", "closeTOC", "scrollPosition", "commitEdit", "editorDirty", "reloadDocument", "editorModeRequest"] {
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
        coordinator.onEditingRequested = onEditingRequested
        coordinator.onReload = onReload
        (webView as? DocumentWebView)?.reloadDocument = fileURL == nil ? nil : onReload
        (webView as? DocumentWebView)?.documentGeneration = reloadGeneration
        let forcedReload = coordinator.reloadGeneration != reloadGeneration
        coordinator.reloadGeneration = reloadGeneration
        coordinator.lastVisualEditing = visualEditing
        coordinator.savedMarkdown = savedMarkdown ?? markdown
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
                    coordinator.pendingAutoFocus = visualEditing
                    coordinator.loadInitialPage(html, in: webView, previewURL: nil, baseURL: nil)
                }
            }
        }
        if coordinator.lastShowTOC != showTOC {
            coordinator.lastShowTOC = showTOC
            webView.callAsyncJavaScript("window._mvSetTOC?.(show);", arguments: ["show": showTOC],
                                        in: nil, in: .page, completionHandler: nil)
        }
        if webView.pageZoom != zoomLevel {
            webView.pageZoom = zoomLevel
        }
    }

    /// The document page (page.html) with the current text and editor state.
    func buildHTML(imageOrigin: String = "") -> String {
        PageTemplate.html(config: .init(
            markdown: Data(markdown.utf8).base64EncodedString(),
            imageOrigin: imageOrigin,
            editor: .init(generation: reloadGeneration, visual: visualEditing, automatic: automaticEditing,
                          baseline: savedMarkdown ?? markdown)))
    }
}
