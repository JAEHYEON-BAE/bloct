import SwiftUI
import Combine
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

// Poll bookkeeping has no visible representation. Keep it per view lifetime, but
// deliberately unobserved: toggling @State for every read rebuilds the focused
// command closures and can make SwiftUI reconstruct the open macOS menus.
@MainActor
private final class DiskCheckState {
    var inProgress = false
    var reportedReadFailure = false
    var pendingReadFailureURL: URL?
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
    @State private var lastKnownFileURL: URL?
    private var sourceURL: URL? { fileURL ?? lastKnownFileURL }
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
    @State private var isClosed = false
    @State private var diskCheck = DiskCheckState()
    @State private var reloadGeneration = 0
    @State private var ignoredExternalText: String?
    // Background polling can wait until menu/control tracking and modal panels end.
    // Explicit Reload / before-edit checks still read the current source directly.
    private let diskTimer = Timer.publish(every: 0.6, on: .main, in: .default).autoconnect()
    @State private var webViewStore = WebViewStore()
    @State private var visualEditing = false
    @State private var isCheckingVisualClose = false
    @State private var isSwitchingEditor = false

    // State is seeded here rather than in onAppear so the web view's first load already
    // has the document text (otherwise it loads an empty page, then reloads).
    init(document: Binding<MarkdownDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        document.wrappedValue.writeProtection.trackSource(fileURL)
        _lastKnownFileURL = State(initialValue: fileURL)
        let text = document.wrappedValue.text
        _docState = StateObject(wrappedValue: DocumentState(document: document))
        _originalText = State(initialValue: text)
    }

    private var hasUnsavedChanges: Bool {
        visualEditing ? isBlockEditorDirty : docState.text != originalText || isBlockEditorDirty
    }

    var body: some View {
        MarkdownWebView(markdown: docState.text, fileURL: sourceURL, zoomLevel: zoomLevel, showTOC: showTOC, webViewStore: webViewStore, onCloseTOC: { showTOC = false }, onTextCommit: { commitEdit($0) }, onEditorDirtyChanged: { if visualEditing { isBlockEditorDirty = $0 } }, onReload: { checkDisk(manual: true) }, reloadGeneration: reloadGeneration, visualEditing: visualEditing, savedMarkdown: originalText)
            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        .focusedValue(\.zoomLevel, $zoomLevel)
        .focusedValue(\.exportPDF, exportAsPDF)
        .focusedValue(\.showTOC, $showTOC)
        .focusedValue(\.showSearch, $showSearch)
        .focusedValue(\.saveDocument, { saveDocument() })
        .focusedValue(\.documentUndo, visualEditing ? { replayEdit(redo: false) } : nil)
        .focusedValue(\.documentRedo, visualEditing ? { replayEdit(redo: true) } : nil)
        .focusedValue(\.closeDocument, {
            guard !isSaving, !isSwitchingEditor else { return }
            if visualEditing { closeProxy?.window?.performClose(nil) }
            else if hasUnsavedChanges { showCloseWarning = true }
            else { closeProxy?.window?.performClose(nil) }
        })
        .onChange(of: hasUnsavedChanges) { _, dirty in
            closeProxy?.window?.isDocumentEdited = dirty
        }
        .onChange(of: document.text) { _, text in
            if let stagedSave, stagedSave.text == text { stagedSave.run() }
            else { checkDisk() }
        }
        .onAppear { isClosed = false }
        .onDisappear { isClosed = true }
        .onReceive(diskTimer) { _ in checkDisk() }
        .onChange(of: fileURL) { _, location in
            if let location { lastKnownFileURL = location }
            ignoredExternalText = nil
            diskCheck.reportedReadFailure = false
            checkDisk()
        }
        .onChange(of: showSearch) { _, visible in
            if !visible {
                searchText = ""
                clearHighlights()
            }
        }
        .background(
            WindowCloseHandler(
                hasUnsavedChanges: hasUnsavedChanges || isSaving || visualEditing,
                onIntercept: {
                    if !isSaving {
                        if visualEditing { requestVisualClose() }
                        else { showCloseWarning = true }
                    }
                },
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
                        get: { visualEditing },
                        set: { if $0 != visualEditing { switchEditor() } }
                    )) {
                        Label("Aa", systemImage: "textformat")
                    }
                    .toggleStyle(.button)
                    .disabled(isSaving || isSwitchingEditor)
                    .help(visualEditing ? "Finish editing (Aa)" : "Edit document (Aa)")
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

    private func switchEditor() {
        guard !isSaving, !isSwitchingEditor,
              let webView = webViewStore.webView else { return }
        isSwitchingEditor = true
        Task { @MainActor in
            while self.diskCheck.inProgress { try? await Task.sleep(for: .milliseconds(10)) }
            guard !self.isClosed else { self.isSwitchingEditor = false; return }
            if !self.visualEditing {
                let allowed = await withCheckedContinuation { continuation in
                    self.checkDisk(beforeEdit: { continuation.resume(returning: $0) }, enteringEditor: true)
                }
                guard allowed, !self.isClosed else { self.isSwitchingEditor = false; return }
            }
            let generation = self.reloadGeneration
            webView.callAsyncJavaScript("""
                return await window._mvSwitchEditor(on, baseline);
                """, arguments: ["on": !visualEditing, "baseline": originalText], in: nil, in: .page) { result in
                DispatchQueue.main.async {
                    self.isSwitchingEditor = false
                    guard !self.isClosed, self.reloadGeneration == generation,
                          self.webViewStore.webView === webView else {
                        webView.evaluateJavaScript("window._bloctVisual?.unfreeze(); window._mvDiskChecking = false;", completionHandler: nil)
                        return
                    }
                    if case .success(let value) = result, let payload = value as? [String: Any],
                       payload["blocked"] as? Bool == true { return }
                    guard case .success(let value) = result, let payload = value as? [String: Any],
                          let text = payload["text"] as? String else {
                        webView.evaluateJavaScript("window._bloctVisual?.unfreeze(); window._mvDiskChecking = false;", completionHandler: nil)
                        if case .failure(let error) = result { NSApp.presentError(error) }
                        return
                    }
                    // A mode boundary is one native Undo checkpoint. It never writes
                    // the file model or changes the last successful Save baseline.
                    self.docState.commit(text)
                    self.isBlockEditorDirty = !self.visualEditing && text != self.originalText
                    self.visualEditing.toggle()
                }
            }
        }
    }

    // Native dirty notifications can be queued behind the close command. Query
    // and freeze the live engine before allowing a clean visual document to close.
    private func requestVisualClose() {
        guard !isSaving, !isSwitchingEditor, !isCheckingVisualClose, let webView = webViewStore.webView else { return }
        isCheckingVisualClose = true
        webView.callAsyncJavaScript("return window._bloctVisual.freezeIfClean();",
                                   arguments: [:], in: nil, in: .page) { result in
            DispatchQueue.main.async {
                self.isCheckingVisualClose = false
                guard !self.isClosed else { return }
                guard (try? result.get()) as? Bool == false else {
                    self.showCloseWarning = true
                    return
                }
                self.closeProxy?.bypass = true
                self.closeProxy?.window?.close()
                if AppDelegate.isQuitting { handleQuit() }
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
            "window._bloctVisual?.setEditable(false); true;"
        ) { _, _ in
            DispatchQueue.main.async {
                self.document.writeProtection.discard()
                self.docState.restore(self.originalText)
                proxy?.hasUnsavedChanges = { false }
                proxy?.bypass = true
                if let nativeDocument = proxy?.window?.windowController?.document as? NSDocument {
                    // NSDocument may recreate a deleted source when its last window
                    // closes. Don't Save must also abandon that native recovery path.
                    if let url = self.sourceURL, !FileManager.default.fileExists(atPath: url.path) {
                        nativeDocument.fileURL = nil
                    }
                    nativeDocument.updateChangeCount(.changeCleared)
                    nativeDocument.close()
                } else { proxy?.window?.close() }
                if AppDelegate.isQuitting { handleQuit() }
            }
        }
    }

    private func commitEdit(_ newText: String) {
        guard visualEditing else { return }
        docState.receiveVisualSnapshot(newText)
    }

    // Take an explicit JS snapshot: native message delivery need not finish before
    // evaluateJavaScript's completion. Save the same text that the editor committed.
    private func saveDocument(then completion: (() -> Void)? = nil) {
        guard !isSaving, !isSwitchingEditor else { return }
        guard let webView = webViewStore.webView,
              let nativeDocument = closeProxy?.window?
                .windowController?.document as? NSDocument else {
            AppDelegate.isQuitting = false
            NSApp.presentError(CocoaError(.fileWriteUnknown))
            return
        }
        isSaving = true
        webView.callAsyncJavaScript("""
            if (window._bloctVisual) return await window._bloctVisual.snapshot();
            if (!window._mvRawLines) throw new Error('Document not ready');
            return {text: window._mvRawLines.join('\\n')};
            """, arguments: [:], in: nil, in: .page) { result in
            DispatchQueue.main.async {
                guard case .success(let value) = result, let payload = value as? [String: Any],
                      let text = payload["text"] as? String else {
                    self.isSaving = false
                    AppDelegate.isQuitting = false
                    if case .failure(let error) = result { NSApp.presentError(error) }
                    else { NSApp.presentError(CocoaError(.fileWriteUnknown)) }
                    return
                }
                let token = payload["token"] as? String
                if self.visualEditing { self.commitEdit(text) }
                else { self.docState.commit(text) }
                if let url = self.sourceURL {
                    let expected = self.originalText
                    Task { @MainActor in
                        do {
                            try await DocumentDisk.saveAsync(text, to: url, replacing: expected)
                            guard !self.isClosed, self.sourceURL == url else { self.isSaving = false; return }
                            self.originalText = text
                            self.ignoredExternalText = nil
                            try nativeDocument.revert(toContentsOf: url, ofType: nativeDocument.fileType ?? "net.daringfireball.markdown")
                            nativeDocument.updateChangeCount(.changeCleared)
                            self.finishEditorSave(webView, text: text, token: token, completion: completion)
                        } catch {
                            self.isSaving = false
                            AppDelegate.isQuitting = false
                            if case DocumentDisk.Conflict.changed = error { self.checkDisk(manual: true) }
                            else { NSApp.presentError(error) }
                        }
                    }
                    return
                }
                let request = StagedDocumentSave(text: text) {
                    DocumentSaveOperation.save(nativeDocument) { success in
                        self.stagedSave = nil
                        guard success else {
                            self.isSaving = false
                            self.docState.stageForSave(self.originalText)
                            nativeDocument.updateChangeCount(.changeCleared)
                            AppDelegate.isQuitting = false
                            return
                        }
                        self.originalText = text
                        self.finishEditorSave(webView, text: text, token: token, completion: completion)
                    }
                }
                self.stagedSave = request
                if self.document.text == text { request.run() }
                else { self.docState.stageForSave(text) }
            }
        }
    }

    private func finishEditorSave(_ webView: WKWebView, text: String, token: String?, completion: (() -> Void)?) {
        guard let token else {
            isSaving = false
            if docState.text == text && !isBlockEditorDirty { completion?() }
            else if completion != nil { AppDelegate.isQuitting = false; showCloseWarning = true }
            if completion == nil && AppDelegate.isQuitting { handleQuit() }
            return
        }
        webView.callAsyncJavaScript("return window._bloctVisual.acknowledge(token, closing);",
                                   arguments: ["token": token, "closing": completion != nil], in: nil, in: .page) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                guard !self.isClosed else { return }
                let clean = (try? result.get()) as? Bool == true
                self.isBlockEditorDirty = !clean
                if clean { completion?() }
                else if completion != nil { AppDelegate.isQuitting = false; self.showCloseWarning = true }
                if completion == nil && AppDelegate.isQuitting { handleQuit() }
            }
        }
    }

    // Read the actual source and freeze a clean Aa engine before accepting a reload.
    private func checkDisk(manual: Bool = false, beforeEdit: ((Bool) -> Void)? = nil, enteringEditor: Bool = false) {
        guard !isClosed else { beforeEdit?(false); return }
        guard let url = sourceURL else { beforeEdit?(true); return }
        guard !isSaving, (!isSwitchingEditor || enteringEditor), !diskCheck.inProgress else { beforeEdit?(false); return }
        diskCheck.inProgress = true
        let generation = reloadGeneration
        Task { @MainActor in
            defer { self.diskCheck.inProgress = false }
            var frozenWebView: WKWebView?
            defer {
                frozenWebView?.evaluateJavaScript("""
                    window._mvDiskChecking = false;
                    window._bloctVisual?.unfreeze();
                    """, completionHandler: nil)
            }
            do {
                let diskText = try await DocumentDisk.readAsync(url)
                guard !self.isClosed, self.sourceURL == url, self.reloadGeneration == generation,
                      !self.isSaving else { beforeEdit?(false); return }
                self.diskCheck.reportedReadFailure = false
                self.diskCheck.pendingReadFailureURL = nil
                guard manual || diskText != self.originalText else { beforeEdit?(true); return }
                if !manual && beforeEdit == nil && self.ignoredExternalText == diskText { return }
                guard let webView = self.webViewStore.webView else { beforeEdit?(false); return }
                frozenWebView = webView
                let editorDirty: Bool = try await withCheckedThrowingContinuation { continuation in
                    webView.evaluateJavaScript("""
                        (() => {
                            if (window._bloctVisual) return window._bloctVisual.freezeIfClean();
                            if (!window._mvRawLines) return null;
                            window._mvDiskChecking = true;
                            return false;
                        })();
                        """) { result, error in
                            if let dirty = result as? Bool { continuation.resume(returning: dirty) }
                            else { continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown)) }
                        }
                }
                let latest = try await DocumentDisk.readAsync(url)
                guard !self.isClosed, self.sourceURL == url, self.reloadGeneration == generation,
                      !self.isSaving else { beforeEdit?(false); return }
                let dirty = editorDirty || (!self.visualEditing && self.docState.text != self.originalText) || self.isBlockEditorDirty
                if dirty {
                    if manual || latest != self.originalText {
                        self.presentDiskConflict(latest, webView: webView)
                        beforeEdit?(false)
                    } else { beforeEdit?(true) }
                } else {
                    self.acceptDisk(latest, webView: webView)
                    beforeEdit?(enteringEditor) // Aa can start on the newly accepted source.
                }
            } catch {
                beforeEdit?(false)
                guard !self.isClosed else { return }
                // Give NSDocument's move notification a run-loop turn to update
                // fileURL; a disappearing old path during rename is transient.
                if !manual && self.diskCheck.pendingReadFailureURL != url {
                    self.diskCheck.pendingReadFailureURL = url
                    return
                }
                if manual || !self.diskCheck.reportedReadFailure {
                    self.diskCheck.reportedReadFailure = true
                    NSApp.presentError(error)
                }
            }
        }
    }

    private func acceptDisk(_ text: String, webView: WKWebView) {
        // Close only a verified clean editor, or one explicitly discarded by the user.
        let base64 = Data(text.utf8).base64EncodedString()
        (webView as? DocumentWebView)?.documentGeneration = reloadGeneration + 1
        webView.evaluateJavaScript("""
            window._mvGeneration = \(reloadGeneration + 1);
            window._mvStale = true;
            window._mvRender && window._mvRender('\(base64)');
            window._mvDiskChecking = false;
            window._bloctVisual?.unfreeze();
            """, completionHandler: nil)
        originalText = text
        docState.restore(text)
        if let nativeDocument = closeProxy?.window?.windowController?.document as? NSDocument,
           let url = sourceURL {
            do { try nativeDocument.revert(toContentsOf: url, ofType: nativeDocument.fileType ?? "net.daringfireball.markdown") }
            catch { NSApp.presentError(error) }
        }
        isBlockEditorDirty = false
        ignoredExternalText = nil
        reloadGeneration += 1
    }

    private func presentDiskConflict(_ diskText: String, webView: WKWebView) {
        guard let window = closeProxy?.window, window.attachedSheet == nil else { return }
        ignoredExternalText = diskText
        let alert = NSAlert()
        alert.messageText = diskText == originalText ? "Reload Document?" : "File Changed on Disk"
        alert.informativeText = "Your edits are preserved. Reload discards your edits and reads the current file. Save a Copy keeps both versions."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard Edits and Reload")
        alert.addButton(withTitle: "Save a Copy…")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn {
                Task { @MainActor in
                    do {
                        if let url = self.sourceURL {
                            let text = try await DocumentDisk.readAsync(url)
                            guard !self.isClosed, self.sourceURL == url else { return }
                            self.acceptDisk(text, webView: webView)
                        }
                    } catch { NSApp.presentError(error) }
                }
            } else if response == .alertThirdButtonReturn {
                self.saveDraftCopy(webView)
            }
            AppDelegate.isQuitting = false
        }
    }

    private func saveDraftCopy(_ webView: WKWebView) {
        webView.callAsyncJavaScript("if (window._bloctVisual) return (await window._bloctVisual.snapshot()).text; return window._mvRawLines.join('\\n');",
                                   arguments: [:], in: nil, in: .page) { result in
            guard case .success(let value) = result, let text = value as? String else { return }
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = MarkdownDocument.readableContentTypes
                panel.nameFieldStringValue = "\(self.sourceURL?.deletingPathExtension().lastPathComponent ?? "document") copy.md"
                guard panel.runModal() == .OK, let destination = panel.url else { return }
                guard destination.resolvingSymlinksInPath() != self.sourceURL?.resolvingSymlinksInPath() else {
                    NSApp.presentError(DocumentDisk.Conflict.changed); return
                }
                do { try Data(text.utf8).write(to: destination, options: .atomic) }
                catch { NSApp.presentError(error) }
            }
        }
    }

    private func replayEdit(redo: Bool) {
        guard visualEditing, !isSwitchingEditor else { return }
        // Aa owns text history; earlier mode checkpoints remain in DocumentState.
        webViewStore.webView?.evaluateJavaScript("""
            (() => {
                if (window._bloctVisual) {
                    if (window._bloctVisual.history(\(redo ? "true" : "false"))) return true;
                    return {text: window._bloctVisual.session.markdown()};
                }
                return false;
            })();
            """) { handled, error in
                guard error == nil, (handled as? Bool) != true else { return }
                if let payload = handled as? [String: Any], let text = payload["text"] as? String {
                    guard redo ? docState.undoManager.canRedo : docState.undoManager.canUndo else { return }
                    docState.receiveVisualSnapshot(text)
                    if redo { docState.undoManager.redo() }
                    else { docState.undoManager.undo() }
                    webViewStore.webView?.callAsyncJavaScript(
                        "window._bloctVisual.restoreDraft(text, baseline);",
                        arguments: ["text": docState.text, "baseline": originalText], in: nil, in: .page,
                        completionHandler: nil)
                } else {
                    if redo { docState.undoManager.redo() }
                    else { docState.undoManager.undo() }
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
