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

struct DocumentUndoKey: FocusedValueKey { typealias Value = () -> Void }
struct DocumentRedoKey: FocusedValueKey { typealias Value = () -> Void }
struct CloseDocumentKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var documentUndo: (() -> Void)? {
        get { self[DocumentUndoKey.self] }
        set { self[DocumentUndoKey.self] = newValue }
    }
    var documentRedo: (() -> Void)? {
        get { self[DocumentRedoKey.self] }
        set { self[DocumentRedoKey.self] = newValue }
    }
    var closeDocument: (() -> Void)? {
        get { self[CloseDocumentKey.self] }
        set { self[CloseDocumentKey.self] = newValue }
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

// MARK: - Window close interception

class CloseProxy: NSObject, NSWindowDelegate {
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

    func windowWillClose(_ notification: Notification) {
        next?.windowWillClose?(notification)
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
        proxy = p
        DispatchQueue.main.async { [weak self, weak win] in
            guard let self, let win else { return }
            p.next = win.delegate
            win.delegate = p
            self.onReady?(p)
        }
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
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @StateObject private var docState: DocumentState
    @State private var zoomLevel: Double = 1.0
    @State private var showTOC: Bool = false
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var originalText: String
    @State private var showCloseWarning: Bool = false
    @State private var closeProxy: CloseProxy? = nil
    @State private var isBlockEditorDirty: Bool = false
    @State private var isSaving = false
    @State private var stagedSave: StagedDocumentSave?
    @State private var isEditMode: Bool
    @State private var webViewStore = WebViewStore()

    // State is seeded here rather than in onAppear so the web view's first load already
    // has the document text (otherwise it loads an empty page, then reloads).
    init(document: Binding<MarkdownDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        let text = document.wrappedValue.text
        _docState = StateObject(wrappedValue: DocumentState(document: document))
        _originalText = State(initialValue: text)
        _isEditMode = State(initialValue: fileURL == nil)
    }

    private var hasUnsavedChanges: Bool { docState.text != originalText || isBlockEditorDirty }

    var body: some View {
        MarkdownWebView(markdown: docState.text, fileURL: fileURL, zoomLevel: zoomLevel, showTOC: showTOC, isEditMode: isEditMode, webViewStore: webViewStore, onCloseTOC: { showTOC = false }, onTextCommit: { commitEdit($0) }, onEditorDirtyChanged: { isBlockEditorDirty = $0 })
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        .focusedValue(\.zoomLevel, $zoomLevel)
        .focusedValue(\.exportPDF, exportAsPDF)
        .focusedValue(\.showTOC, $showTOC)
        .focusedValue(\.showSearch, $showSearch)
        .focusedValue(\.saveDocument, { saveDocument() })
        .focusedValue(\.documentUndo, { replayEdit(redo: false) })
        .focusedValue(\.documentRedo, { replayEdit(redo: true) })
        .focusedValue(\.closeDocument, {
            guard !isSaving else { return }
            if hasUnsavedChanges { showCloseWarning = true }
            else { closeProxy?.window?.performClose(nil) }
        })
        .onChange(of: hasUnsavedChanges) { _, dirty in
            closeProxy?.window?.isDocumentEdited = dirty
        }
        .onChange(of: document.text) { _, text in
            if let stagedSave, stagedSave.text == text { stagedSave.run() }
        }
        .onChange(of: showSearch) { _, visible in
            if !visible {
                searchText = ""
                clearHighlights()
            }
        }
        .background(
            WindowCloseHandler(
                hasUnsavedChanges: hasUnsavedChanges || isSaving,
                onIntercept: { if !isSaving { showCloseWarning = true } },
                onReady: { proxy in
                    closeProxy = proxy
                    proxy.window?.isDocumentEdited = hasUnsavedChanges
                }
            )
            .frame(width: 0, height: 0)
        )
        .alert("Unsaved Changes", isPresented: $showCloseWarning) {
            Button("Save") { saveAndClose() }
            Button("Don't Save", role: .destructive) { discardAndClose() }
            Button("Cancel", role: .cancel) {
                AppDelegate.isQuitting = false
            }
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
                    Toggle(isOn: Binding(
                        get: { isEditMode },
                        set: { newValue in
                            isEditMode = newValue
                            if !newValue { isBlockEditorDirty = false }
                        }
                    )) {
                        Label("Edit Mode", systemImage: "pencil")
                    }
                    .toggleStyle(.button)
                    .help(isEditMode ? "Switch to Read Mode" : "Switch to Edit Mode")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSearch.toggle()
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
                                onEscape: { showSearch = false }
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
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .help("Close")
                        }
                    }
                }
            }
    }

    private func saveAndClose() {
        let proxy = closeProxy
        saveDocument {
            proxy?.hasUnsavedChanges = { false }
            proxy?.bypass = true
            proxy?.window?.close()
            if AppDelegate.isQuitting { handleQuit() }
        }
    }

    private func discardAndClose() {
        let proxy = closeProxy
        webViewStore.webView?.evaluateJavaScript(
            "window._mvCloseEditor && window._mvCloseEditor(false);"
        ) { _, _ in
            DispatchQueue.main.async {
                self.docState.restore(self.originalText)
                proxy?.hasUnsavedChanges = { false }
                proxy?.bypass = true
                proxy?.window?.close()
                if AppDelegate.isQuitting { handleQuit() }
            }
        }
    }

    private func commitEdit(_ newText: String) {
        docState.commit(newText)
    }

    // Take an explicit JS snapshot: native message delivery need not finish before
    // evaluateJavaScript's completion. Save the same text that the editor committed.
    private func saveDocument(then completion: (() -> Void)? = nil) {
        guard !isSaving else { return }
        guard let webView = webViewStore.webView,
              let nativeDocument = closeProxy?.window?
                .windowController?.document as? NSDocument else {
            AppDelegate.isQuitting = false
            NSApp.presentError(CocoaError(.fileWriteUnknown))
            return
        }
        isSaving = true
        webView.evaluateJavaScript("""
            (() => {
                if (!window._mvCloseEditor || !window._mvRawLines) throw new Error('Editor not ready');
                window._mvCloseEditor(true);
                return window._mvRawLines.join('\\n');
            })();
            """) { result, error in
            DispatchQueue.main.async {
                guard error == nil, let text = result as? String else {
                    self.isSaving = false
                    AppDelegate.isQuitting = false
                    NSApp.presentError(error ?? CocoaError(.fileWriteUnknown))
                    return
                }
                self.docState.commit(text)
                let request = StagedDocumentSave(text: text) {
                    DocumentSaveOperation.save(nativeDocument) { success in
                        self.isSaving = false
                        self.stagedSave = nil
                        guard success else {
                            self.docState.stageForSave(self.originalText)
                            nativeDocument.updateChangeCount(.changeCleared)
                            AppDelegate.isQuitting = false
                            return
                        }
                        self.originalText = text
                        // A later edit must not be discarded by save-and-close.
                        if self.docState.text == text && !self.isBlockEditorDirty {
                            completion?()
                        } else if completion != nil {
                            AppDelegate.isQuitting = false
                            self.showCloseWarning = true
                        }
                        if completion == nil && AppDelegate.isQuitting { handleQuit() }
                    }
                }
                self.stagedSave = request
                if self.document.text == text { request.run() }
                else { self.docState.stageForSave(text) }
            }
        }
    }

    private func replayEdit(redo: Bool) {
        // Let an active textarea keep its native character-level editing history.
        webViewStore.webView?.evaluateJavaScript("""
            (() => {
                if (!document.getElementById('mv-block-editor')) return false;
                document.execCommand('\(redo ? "redo" : "undo")');
                return true;
            })();
            """) { handled, error in
                guard error == nil, (handled as? Bool) == false else { return }
                if redo { docState.undoManager.redo() }
                else { docState.undoManager.undo() }
            }
    }

    private func clearHighlights() {
        webViewStore.webView?.evaluateJavaScript("window._mvSearch.clear();", completionHandler: nil)
        if let webView = webViewStore.webView {
            webView.window?.makeFirstResponder(webView)
        }
    }

    private func updateHighlights() {
        // Pass the query as an argument so quotes, backslashes and newlines need no escaping.
        webViewStore.webView?.callAsyncJavaScript(
            "window._mvSearch.highlight(text);",
            arguments: ["text": searchText],
            in: nil,
            in: .page,
            completionHandler: nil
        )
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
