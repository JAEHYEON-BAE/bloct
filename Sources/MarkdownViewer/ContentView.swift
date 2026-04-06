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

struct ShowRawEditorKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showRawEditor: Binding<Bool>? {
        get { self[ShowRawEditorKey.self] }
        set { self[ShowRawEditorKey.self] = newValue }
    }
}

// NSTextField subclass that requests focus in viewDidMoveToWindow,
// which fires exactly once when the view is attached to a window.
class FocusOnAppearTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let win = window else { return }
        DispatchQueue.main.async { [weak self, weak win] in
            guard let self, let win else { return }
            win.makeFirstResponder(self)
        }
    }
}

// NSTextField wrapper that calls makeFirstResponder directly,
// bypassing SwiftUI's @FocusState which doesn't work in toolbar items.
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> FocusOnAppearTextField {
        let field = FocusOnAppearTextField()
        field.placeholderString = "Find…"
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ nsView: FocusOnAppearTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        init(_ parent: SearchTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

class WebViewStore {
    var webView: WKWebView?
}

class DragHandleNSView: NSView {
    var onDragChanged: ((CGFloat) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    @objc private func handlePan(_ pan: NSPanGestureRecognizer) {
        guard pan.state == .changed else { return }
        let delta = pan.translation(in: nil).x
        pan.setTranslation(.zero, in: nil)
        onDragChanged?(delta)
    }
}

struct DragHandleView: NSViewRepresentable {
    var onDragChanged: (CGFloat) -> Void

    func makeNSView(context: Context) -> DragHandleNSView {
        let v = DragHandleNSView()
        v.onDragChanged = onDragChanged
        return v
    }
    func updateNSView(_ nsView: DragHandleNSView, context: Context) {
        nsView.onDragChanged = onDragChanged
    }
}

struct RawTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
}

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    @State private var zoomLevel: Double = 1.0
    @State private var showTOC: Bool = false
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var showRawEditor: Bool = false
    @State private var rawPaneWidth: CGFloat = 320
    private let webViewStore = WebViewStore()

    var body: some View {
        HStack(spacing: 0) {
            RawTextView(text: document.text)
                .frame(width: showRawEditor ? rawPaneWidth : 0)
                .clipped()
            // Divider: 1px visual line inside an 8px ZStack so the drag target has a real layout frame
            ZStack {
                Color(NSColor.separatorColor).frame(width: 1)
                DragHandleView(onDragChanged: { delta in
                    rawPaneWidth = max(160, min(800, rawPaneWidth + delta))
                })
            }
            .frame(width: showRawEditor ? 8 : 0)
            .opacity(showRawEditor ? 1 : 0)
            MarkdownWebView(markdown: document.text, fileURL: fileURL, zoomLevel: zoomLevel, showTOC: showTOC, webViewStore: webViewStore, onCloseTOC: { showTOC = false })
                .frame(minWidth: 300, maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: showRawEditor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusedValue(\.zoomLevel, $zoomLevel)
        .focusedValue(\.exportPDF, exportAsPDF)
        .focusedValue(\.showTOC, $showTOC)
        .focusedValue(\.showSearch, $showSearch)
        .focusedValue(\.showRawEditor, $showRawEditor)
        .onChange(of: showSearch) { visible in
            if !visible { clearHighlights() }
        }
        .toolbar {
                ToolbarItem(placement: .navigation) {
                    Toggle(isOn: $showTOC) {
                        Label("Table of Contents", systemImage: "list.bullet")
                    }
                    .toggleStyle(.button)
                    .help("Toggle Table of Contents (⇧⌘T)")
                }
                ToolbarItem(placement: .navigation) {
                    Toggle(isOn: $showRawEditor) {
                        Label("Raw Markdown", systemImage: "doc.plaintext")
                    }
                    .toggleStyle(.button)
                    .help("Toggle Raw Markdown View (⇧⌘R)")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSearch.toggle()
                        if !showSearch { searchText = "" }
                    } label: {
                        Label("Find", systemImage: "magnifyingglass")
                    }
                    .help("Find in Document (⌘F)")
                }
                if showSearch {
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 4) {
                            SearchTextField(
                                text: $searchText,
                                onSubmit: { performFind(forward: true) },
                                onEscape: { showSearch = false; searchText = "" }
                            )
                            .frame(width: 180, height: 22)
                            .onChange(of: searchText) { _ in updateHighlights() }
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

    private func clearHighlights() {
        webViewStore.webView?.evaluateJavaScript("window._mvSearch.clear();", completionHandler: nil)
        if let webView = webViewStore.webView {
            webView.window?.makeFirstResponder(webView)
        }
    }

    private func updateHighlights() {
        guard let webView = webViewStore.webView else { return }
        let escaped = searchText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window._mvSearch.highlight('\(escaped)');", completionHandler: nil)
    }

    private func performFind(forward: Bool) {
        guard let webView = webViewStore.webView, !searchText.isEmpty else { return }
        webView.evaluateJavaScript("window._mvSearch.navigate(\(forward ? "true" : "false"));", completionHandler: nil)
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
