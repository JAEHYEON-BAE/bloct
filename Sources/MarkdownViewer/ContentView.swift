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

struct SaveDocumentKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var saveDocument: (() -> Void)? {
        get { self[SaveDocumentKey.self] }
        set { self[SaveDocumentKey.self] = newValue }
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

@MainActor
final class DocumentState: ObservableObject {
    @Published var text: String = ""
    weak var undoManager: UndoManager?

    func load(_ initialText: String) {
        text = initialText
        undoManager?.removeAllActions()
    }

    func commit(_ newText: String) {
        guard newText != text else { return }
        let old = text
        text = newText
        undoManager?.registerUndo(withTarget: self) { target in
            target.commit(old)
        }
        undoManager?.setActionName("Typing")
    }
}

// MARK: - Window close interception

private class CloseProxy: NSObject, NSWindowDelegate {
    weak var window: NSWindow?
    weak var next: NSWindowDelegate?
    var bypass = false
    var hasUnsavedChanges: () -> Bool = { false }
    var onIntercept: () -> Void = {}

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if bypass { bypass = false; return true }
        if hasUnsavedChanges() { onIntercept(); return false }
        return next?.windowShouldClose?(sender) ?? true
    }

    override func responds(to sel: Selector!) -> Bool {
        super.responds(to: sel) || (next?.responds(to: sel) ?? false)
    }
    override func forwardingTarget(for sel: Selector!) -> Any? {
        next?.responds(to: sel) == true ? next : super.forwardingTarget(for: sel)
    }
}

private class CloseHandlerView: NSView {
    var proxy: CloseProxy?
    var onReady: ((CloseProxy) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let win = window, proxy == nil else { return }
        let p = CloseProxy()
        p.window = win
        p.next = win.delegate
        win.delegate = p
        proxy = p
        onReady?(p)
    }
}

private struct WindowCloseHandler: NSViewRepresentable {
    var hasUnsavedChanges: Bool
    var onIntercept: () -> Void
    var onReady: (CloseProxy) -> Void

    func makeNSView(context: Context) -> CloseHandlerView { CloseHandlerView() }

    func updateNSView(_ v: CloseHandlerView, context: Context) {
        if v.proxy == nil { v.onReady = onReady }
        v.proxy?.hasUnsavedChanges = { hasUnsavedChanges }
        v.proxy?.onIntercept = onIntercept
    }
}

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var docState = DocumentState()
    @Environment(\.undoManager) var undoManager
    @State private var zoomLevel: Double = 1.0
    @State private var showTOC: Bool = false
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var showCloseWarning: Bool = false
    @State private var closeProxy: CloseProxy? = nil
    private let webViewStore = WebViewStore()

    var body: some View {
        MarkdownWebView(markdown: docState.text, fileURL: fileURL, zoomLevel: zoomLevel, showTOC: showTOC, webViewStore: webViewStore, onCloseTOC: { showTOC = false }, onTextCommit: { docState.commit($0) })
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            docState.undoManager = undoManager
            docState.load(document.text)
        }
        .focusedValue(\.zoomLevel, $zoomLevel)
        .focusedValue(\.exportPDF, exportAsPDF)
        .focusedValue(\.showTOC, $showTOC)
        .focusedValue(\.showSearch, $showSearch)
        .focusedValue(\.saveDocument, saveDocument)
        .onChange(of: showSearch) { _, visible in
            if !visible { clearHighlights() }
        }
        .background(
            WindowCloseHandler(
                hasUnsavedChanges: docState.text != document.text,
                onIntercept: { showCloseWarning = true },
                onReady: { proxy in DispatchQueue.main.async { closeProxy = proxy } }
            )
            .frame(width: 0, height: 0)
        )
        .alert("Unsaved Changes", isPresented: $showCloseWarning) {
            Button("Save") {
                saveDocument()
                closeProxy?.bypass = true
                closeProxy?.window?.close()
            }
            Button("Don't Save", role: .destructive) {
                closeProxy?.bypass = true
                closeProxy?.window?.close()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save your changes before closing?")
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
                            .onChange(of: searchText) { updateHighlights() }
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

    private func saveDocument() {
        guard let url = fileURL else { return }
        try? docState.text.write(to: url, atomically: true, encoding: .utf8)
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
