import AppKit
import SwiftUI
import WebKit

// Temporary source instrumentation exposes production actions and pauses disk
// writes. It does not replace the parser, bridge, state, Undo or save algorithm.
@MainActor enum VisualProbe {
    struct Actions {
        let state: DocumentState
        let undo: () -> Void
        let redo: () -> Void
        let save: () -> Void
        let saveAndClose: () -> Void
        let discard: () -> Void
        let requestClose: () -> Void
    }
    static var actions: [URL: Actions] = [:]
    static var holdSaves = false, saveWaiting = false
    static var errors = 0
    static var closeWarnings = 0
    static func attach(_ url: URL?, _ state: DocumentState, _ save: @escaping () -> Void,
                       _ close: @escaping () -> Void, _ discard: @escaping () -> Void,
                       _ undo: @escaping () -> Void, _ redo: @escaping () -> Void,
                       _ requestClose: @escaping () -> Void) {
        guard let url else { return }
        actions[url] = Actions(state: state, undo: undo, redo: redo, save: save, saveAndClose: close, discard: discard, requestClose: requestClose)
    }
    static func presentError(_ error: Error) { errors += 1 }
    static func beforeSave() async {
        saveWaiting = true
        while holdSaves { try? await Task.sleep(for: .milliseconds(10)) }
        saveWaiting = false
    }
}

@main struct VisualEditorNative {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-visual-native-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var passed = 0, failed = 0
        func check(_ name: String, _ ok: Bool) {
            if ok { passed += 1 } else { failed += 1 }
            print("\(ok ? "PASS" : "FAIL"): \(name)")
        }
        let original = "# Visual\n\n- [ ] first\n- [X] second\n"
        let first = try Session(root.appendingPathComponent("first.md"), original)
        let second = try Session(root.appendingPathComponent("second.md"), original)
        let delayed = try Session(root.appendingPathComponent("delayed.md"), original)
        let warnings = VisualProbe.closeWarnings
        // Change the real engine while intentionally suppressing its native dirty
        // notification, modeling a close racing that queued message.
        _ = js(delayed.web, "let e=window._bloctVisual; e.session.dispatch(e.session.state.tr.insertText('pending',2)); e.view.updateState(e.session.state); true")
        delayed.actions.requestClose()
        check("close queries live visual state even before native dirty notification", wait { VisualProbe.closeWarnings > warnings }
              && delayed.window.closeCount == 0 && delayed.disk == original)
        _ = js(delayed.web, "window._bloctVisual.history(false)")
        delayed.actions.requestClose()
        check("clean visual close preflight freezes and closes without a warning", wait { delayed.window.closeCount > 0 } && VisualProbe.closeWarnings == warnings + 1)
        delayed.teardown()
        defer { first.teardown(); second.teardown() }
        check("production visual view is a single editor without the Markdown textarea", js(first.web, "!!document.querySelector('.ProseMirror') && !document.querySelector('#mv-block-editor')") as? Bool == true)
        first.toggle()
        let changed = first.raw
        check("live visual changes mark dirty without native snapshot publication or autosave", wait { first.window.isDocumentEdited }
              && first.disk == original && first.model.document.text == original && first.actions.state.text == original)
        check("two visual documents isolate their engine state", second.raw == original && !second.window.isDocumentEdited)
        first.actions.undo()
        let undone = wait { first.raw == original && !first.window.isDocumentEdited }
        check("native Undo command reaches the engine and restores clean source", undone)
        first.actions.redo()
        check("native Redo reaches the same engine history", undone && wait { first.raw == changed && first.window.isDocumentEdited })
        first.actions.save()
        check("native Save writes the exact engine snapshot and acknowledges clean", wait { first.disk == changed && !first.window.isDocumentEdited }
              && !first.actions.state.undoManager.canUndo)
        first.toggle()
        let snapshot = first.raw
        VisualProbe.holdSaves = true
        first.actions.save()
        check("visual Save freezes a snapshot before asynchronous disk I/O", wait { VisualProbe.saveWaiting })
        first.toggle(1)
        let later = first.raw
        VisualProbe.holdSaves = false
        check("later typing/toggle survives Save acknowledgement as dirty", wait { first.disk == snapshot && first.window.isDocumentEdited }
              && first.raw == later && later != snapshot)
        first.actions.save()
        check("a later explicit visual Save becomes clean", wait { first.disk == later && !first.window.isDocumentEdited })
        first.toggle()
        let draft = first.raw, errors = VisualProbe.errors
        try FileManager.default.removeItem(at: first.file)
        first.actions.saveAndClose()
        check("failed visual Save preserves draft and does not close", wait { VisualProbe.errors > errors }
              && first.raw == draft && first.window.closeCount == 0 && first.window.isDocumentEdited)
        try later.write(to: first.file, atomically: true, encoding: .utf8)
        first.actions.save()
        check("failed visual Save can be retried without lost draft", wait { first.disk == draft && !first.window.isDocumentEdited })
        let external = original.replacingOccurrences(of: "Visual", with: "External")
        try external.write(to: second.file, atomically: true, encoding: .utf8)
        check("clean external change reloads the visual engine and history boundary", wait { second.raw == external && !second.window.isDocumentEdited })
        second.toggle()
        second.actions.discard()
        check("Don't Save keeps last disk contents and closes the visual draft", wait { second.window.closeCount > 0 } && second.disk == external)
        first.toggle()
        let final = first.raw
        first.actions.saveAndClose()
        check("visual Save-and-close waits for acknowledged snapshot", wait { first.disk == final && first.window.closeCount > 0 && !first.window.isDocumentEdited })
        first.teardown(); second.teardown()
        check("visual document previews are cleaned", !(try FileManager.default.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".mv_preview-") })
        print("\(passed) passed, \(failed) failed; controlled native document/revert and disk delay, real GUI panels/IME separate")
        if failed > 0 { exit(1) }
    }
}

@MainActor private final class FileModel {
    var document: MarkdownDocument
    init(_ text: String) { document = MarkdownDocument(text: text) }
    var binding: Binding<MarkdownDocument> { Binding(get: { self.document }, set: { self.document = $0 }) }
}

@MainActor private final class NativeDocument: NSDocument {
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {}
}
@MainActor private final class TestWindow: NSWindow {
    var closeCount = 0
    override func close() { closeCount += 1; super.close() }
}

@MainActor private func spin(_ seconds: Double = 0.02) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}
@MainActor @discardableResult private func wait(_ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(12)
    while !condition() && Date() < deadline { spin() }
    return condition()
}
@MainActor private func findWeb(_ view: NSView) -> WKWebView? {
    if let web = view as? WKWebView { return web }
    return view.subviews.lazy.compactMap(findWeb).first
}
@MainActor private func js(_ web: WKWebView, _ source: String) -> Any? {
    var done = false, output: Any?
    web.evaluateJavaScript(source) { value, error in output = value ?? error; done = true }
    wait { done }
    return output
}

@MainActor private final class Session {
    let file: URL, model: FileModel, hosting: NSHostingView<AnyView>
    let window: TestWindow, native = NativeDocument(), controller: NSWindowController
    let web: WKWebView
    private var tornDown = false
    init(_ file: URL, _ raw: String) throws {
        self.file = file
        try raw.write(to: file, atomically: true, encoding: .utf8)
        model = FileModel(raw)
        hosting = NSHostingView(rootView: AnyView(ContentView(document: model.binding, fileURL: file)))
        window = TestWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        controller = NSWindowController(window: window)
        native.addWindowController(controller)
        native.fileURL = file
        native.fileType = "net.daringfireball.markdown"
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        guard let found = findWeb(hosting) else { fatalError("No production WebView") }
        web = found
        precondition(wait { (js(found, "typeof window._mvBuildTOC === 'function' && !!window._bloctVisual") as? Bool) == true })
        precondition(wait { VisualProbe.actions[file] != nil && window.delegate is CloseProxy })
    }
    var actions: VisualProbe.Actions { VisualProbe.actions[file]! }
    var raw: String { js(web, "window._bloctVisual.session.markdown()") as? String ?? "<missing>" }
    var disk: String { (try? String(contentsOf: file, encoding: .utf8)) ?? "<missing>" }
    func toggle(_ index: Int = 0) {
        let before = raw
        _ = js(web, "document.querySelectorAll('li.task-item input')[\(index)].click(); true")
        precondition(wait { raw != before }, "Task bridge failed")
    }
    func teardown() {
        guard !tornDown else { return }
        tornDown = true
        hosting.rootView = AnyView(EmptyView())
        hosting.layoutSubtreeIfNeeded()
        window.close()
        VisualProbe.actions.removeValue(forKey: file)
        spin(0.1)
    }
}
