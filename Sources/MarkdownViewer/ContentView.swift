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

struct ShowTOCKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showTOC: Binding<Bool>? {
        get { self[ShowTOCKey.self] }
        set { self[ShowTOCKey.self] = newValue }
    }
}

struct ShowSearchKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showSearch: Binding<Bool>? {
        get { self[ShowSearchKey.self] }
        set { self[ShowSearchKey.self] = newValue }
    }
}

class WebViewStore {
    var webView: WKWebView?
}

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    @State private var zoomLevel: Double = 1.0
    @State private var showTOC: Bool = true
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    private let webViewStore = WebViewStore()

    var body: some View {
        MarkdownWebView(markdown: document.text, fileURL: fileURL, zoomLevel: zoomLevel, showTOC: showTOC, webViewStore: webViewStore)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusedValue(\.zoomLevel, $zoomLevel)
            .focusedValue(\.exportPDF, exportAsPDF)
            .focusedValue(\.showTOC, $showTOC)
            .focusedValue(\.showSearch, $showSearch)
            .onChange(of: showSearch) { value in
                if value {
                    DispatchQueue.main.async { searchFocused = true }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Toggle(isOn: $showTOC) {
                        Label("Table of Contents", systemImage: "list.bullet")
                    }
                    .toggleStyle(.button)
                    .help("Toggle Table of Contents (⇧⌘T)")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSearch.toggle()
                        if showSearch {
                            searchFocused = true
                        } else {
                            searchText = ""
                        }
                    } label: {
                        Label("Find", systemImage: "magnifyingglass")
                    }
                    .help("Find in Document (⌘F)")
                }
                if showSearch {
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 4) {
                            TextField("Find…", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                                .focused($searchFocused)
                                .onSubmit { performFind(forward: true) }
                                .onChange(of: searchText) { _ in performFind(forward: true) }
                                .onKeyPress(.escape) {
                                    showSearch = false
                                    searchText = ""
                                    return .handled
                                }
                            Button { performFind(forward: false) } label: {
                                Image(systemName: "chevron.up")
                            }
                            .help("Previous match")
                            Button { performFind(forward: true) } label: {
                                Image(systemName: "chevron.down")
                            }
                            .help("Next match")
                            Button {
                                showSearch = false
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .help("Close")
                        }
                    }
                }
            }
    }

    private func performFind(forward: Bool) {
        guard let webView = webViewStore.webView, !searchText.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.wraps = true
        config.caseSensitive = false
        webView.find(searchText, configuration: config) { _ in }
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

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        let op = webView.printOperation(with: printInfo)
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        if let window = webView.window {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            op.run()
        }
    }
}
