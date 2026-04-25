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

class ScrollSyncCoordinator {
    weak var textView: NSTextView?
    weak var webView: WKWebView?

    /// Called when the raw NSTextView scrolls (user-initiated).
    @MainActor func onRawScrolled(scrollView: NSScrollView) {
        guard let tv = scrollView.documentView as? NSTextView, let wv = webView else { return }
        let line = topVisibleLine(in: tv, scrollView: scrollView)
        wv.evaluateJavaScript("window._mvSync && window._mvSync.scrollToLine(\(line));", completionHandler: nil)
    }

    /// Called when the preview WebView sends a syncLine message.
    @MainActor func onPreviewScrolled(toLine line: Int) {
        guard let tv = textView else { return }
        scrollTextView(tv, toLine: line)
    }

    @MainActor private func topVisibleLine(in textView: NSTextView, scrollView: NSScrollView) -> Int {
        let visibleOrigin = scrollView.contentView.bounds.origin
        let inset = textView.textContainerInset
        let y = max(0, visibleOrigin.y - inset.height + 2)
        let point = NSPoint(x: inset.width + 1, y: y)
        guard let lm = textView.layoutManager, let tc = textView.textContainer,
              lm.numberOfGlyphs > 0 else { return 1 }
        let glyphIdx = lm.glyphIndex(for: point, in: tc, fractionOfDistanceThroughGlyph: nil)
        let charIdx = lm.characterIndexForGlyph(at: min(glyphIdx, lm.numberOfGlyphs - 1))
        let nsStr = textView.string as NSString
        var lineNum = 1
        for i in 0..<min(charIdx, nsStr.length) {
            if nsStr.character(at: i) == 10 { lineNum += 1 }
        }
        return lineNum
    }

    @MainActor private func scrollTextView(_ textView: NSTextView, toLine targetLine: Int) {
        guard targetLine > 1 else {
            textView.enclosingScrollView?.documentView?.scroll(.zero)
            return
        }
        let nsStr = textView.string as NSString
        var lineNum = 1
        var charIdx = 0
        while charIdx < nsStr.length {
            if lineNum >= targetLine { break }
            if nsStr.character(at: charIdx) == 10 { lineNum += 1 }
            charIdx += 1
        }
        guard let lm = textView.layoutManager, let tc = textView.textContainer else { return }
        let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: charIdx, length: 0), actualCharacterRange: nil)
        let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        let inset = textView.textContainerInset
        let scrollY = max(0, rect.origin.y + inset.height)
        textView.enclosingScrollView?.documentView?.scroll(NSPoint(x: 0, y: scrollY))
    }
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

// MARK: - Raw text view

struct RawTextView: NSViewRepresentable {
    let text: String
    let isEditable: Bool
    let syncCoordinator: ScrollSyncCoordinator
    var onTextChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(syncCoordinator) }

    @MainActor class Coordinator: NSObject, NSTextViewDelegate {
        let sync: ScrollSyncCoordinator
        var onTextChange: ((String) -> Void)?

        init(_ sync: ScrollSyncCoordinator) { self.sync = sync }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            onTextChange?(tv.string)
            if let sv = tv.enclosingScrollView { updateMinSize(scrollView: sv, textView: tv) }
        }

        @objc func scrollViewDidLiveScroll(_ note: Notification) {
            guard let sv = note.object as? NSScrollView else { return }
            sync.onRawScrolled(scrollView: sv)
        }

        @objc func scrollViewFrameChanged(_ note: Notification) {
            guard let sv = note.object as? NSScrollView,
                  let tv = sv.documentView as? NSTextView else { return }
            updateMinSize(scrollView: sv, textView: tv)
        }

        // Ensures the text view always covers the full pane (cursor tracking everywhere)
        // and maintains 70% of pane height as empty scroll-past-end space.
        private func updateMinSize(scrollView: NSScrollView, textView: NSTextView) {
            let viewHeight = scrollView.bounds.height
            guard viewHeight > 0,
                  let lm = textView.layoutManager,
                  let tc = textView.textContainer else { return }
            lm.ensureLayout(for: tc)
            let contentHeight = lm.usedRect(for: tc).height + textView.textContainerInset.height * 2
            textView.minSize = NSSize(width: 0, height: max(viewHeight, contentHeight + viewHeight * 0.7))
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .textBackgroundColor
        textView.string = text
        textView.delegate = context.coordinator
        syncCoordinator.textView = textView
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidLiveScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        context.coordinator.onTextChange = onTextChange
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        if textView.string != text {
            textView.string = text
            syncCoordinator.textView = textView
        }
    }
}

struct ContentView: View {
    // TODO: Replace with real auth/subscription check
    private let isPro: Bool = true

    let document: MarkdownDocument
    let fileURL: URL?
    @State private var zoomLevel: Double = 1.0
    @State private var showTOC: Bool = false
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var rawPaneWidth: CGFloat = 320
    @State private var editableText: String = ""
    @State private var isEditing: Bool = false
    @State private var showUpgradeAlert: Bool = false
    @State private var showCloseWarning: Bool = false
    @State private var closeProxy: CloseProxy? = nil
    private let webViewStore = WebViewStore()
    private let syncCoordinator = ScrollSyncCoordinator()

    private var editToggle: Binding<Bool> {
        Binding(
            get: { isEditing },
            set: { newVal in
                guard isPro else { showUpgradeAlert = true; return }
                isEditing = newVal
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            RawTextView(
                text: editableText,
                isEditable: isEditing,
                syncCoordinator: syncCoordinator,
                onTextChange: { editableText = $0 }
            )
            .frame(width: isEditing ? rawPaneWidth : 0)
            .clipped()
            // Divider: 1px visual line inside an 8px ZStack so the drag target has a real layout frame
            ZStack {
                Color(NSColor.separatorColor).frame(width: 1)
                DragHandleView(onDragChanged: { delta in
                    rawPaneWidth = max(160, min(800, rawPaneWidth + delta))
                })
            }
            .frame(width: isEditing ? 8 : 0)
            .opacity(isEditing ? 1 : 0)
            MarkdownWebView(markdown: editableText, fileURL: fileURL, zoomLevel: zoomLevel, showTOC: showTOC, webViewStore: webViewStore, syncCoordinator: syncCoordinator, onCloseTOC: { showTOC = false })
                .frame(minWidth: 300, maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: isEditing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { editableText = document.text }
        .focusedValue(\.zoomLevel, $zoomLevel)
        .focusedValue(\.exportPDF, exportAsPDF)
        .focusedValue(\.showTOC, $showTOC)
        .focusedValue(\.showSearch, $showSearch)
        .focusedValue(\.showRawEditor, editToggle)
        .focusedValue(\.saveDocument, saveDocument)
        .onChange(of: showSearch) { _, visible in
            if !visible { clearHighlights() }
        }
        .background(
            WindowCloseHandler(
                hasUnsavedChanges: isEditing && editableText != document.text,
                onIntercept: { showCloseWarning = true },
                onReady: { proxy in DispatchQueue.main.async { closeProxy = proxy } }
            )
            .frame(width: 0, height: 0)
        )
        .alert("Upgrade to Pro", isPresented: $showUpgradeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Editing and saving are Pro features. Upgrade to unlock them.")
        }
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
                ToolbarItem(placement: .navigation) {
                    Toggle(isOn: editToggle) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .toggleStyle(.button)
                    .help("Toggle Edit Mode (⇧⌘R)")
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
        // TODO: Replace with real auth/subscription check
        guard isPro else { showUpgradeAlert = true; return }
        guard let url = fileURL else { return }
        try? editableText.write(to: url, atomically: true, encoding: .utf8)
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
