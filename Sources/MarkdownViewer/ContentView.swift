import SwiftUI
import WebKit

struct ZoomLevelKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

extension FocusedValues {
    var zoomLevel: Binding<Double>? {
        get { self[ZoomLevelKey.self] }
        set { self[ZoomLevelKey.self] = newValue }
    }
}

struct ExportPDFKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var exportPDF: (() -> Void)? {
        get { self[ExportPDFKey.self] }
        set { self[ExportPDFKey.self] = newValue }
    }
}

class WebViewStore {
    var webView: WKWebView?
}

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    @State private var zoomLevel: Double = 1.0
    private let webViewStore = WebViewStore()

    var body: some View {
        MarkdownWebView(markdown: document.text, zoomLevel: zoomLevel, webViewStore: webViewStore)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusedValue(\.zoomLevel, $zoomLevel)
            .focusedValue(\.exportPDF, exportAsPDF)
    }

    private func exportAsPDF() {
        guard let webView = webViewStore.webView else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        if let name = fileURL?.deletingPathExtension().lastPathComponent {
            panel.nameFieldStringValue = "\(name).pdf"
        } else {
            panel.nameFieldStringValue = "document.pdf"
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
            let config = WKPDFConfiguration()
            let height = (result as? CGFloat) ?? webView.bounds.height
            config.rect = CGRect(x: 0, y: 0, width: webView.bounds.width, height: height)
            webView.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    try? data.write(to: url)
                case .failure(let error):
                    DispatchQueue.main.async {
                        NSAlert(error: error).runModal()
                    }
                }
            }
        }
    }
}
