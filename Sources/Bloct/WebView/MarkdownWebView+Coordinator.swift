import AppKit
import WebKit

extension MarkdownWebView {
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
            // TOC, remembered scroll position and resize anchor (Editor/src/host/toc.js, scroll.js).
            let savedScrollY = fileURL.map { UserDefaults.standard.double(forKey: "scrollPos:\($0.path)") } ?? 0
            webView.callAsyncJavaScript("window._mvInstallTOC(showTOC); window._mvInstallScroll(savedScrollY);",
                arguments: ["showTOC": showTOC, "savedScrollY": savedScrollY],
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
}
