import SwiftUI
import WebKit
import UniformTypeIdentifiers

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
