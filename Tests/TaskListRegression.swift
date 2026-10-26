import AppKit
import SwiftUI
import WebKit

// Temporary source instrumentation exposes production actions and pauses disk
// writes. It does not replace the parser, bridge, state, Undo or save algorithm.
@MainActor enum TaskListProbe {
    struct Actions {
        let state: DocumentState
        let save: () -> Void
        let saveAndClose: () -> Void
        let discard: () -> Void
    }
    static var actions: [URL: Actions] = [:]
    static var holdSaves = false, saveWaiting = false
    static var errors = 0
    static func attach(_ url: URL?, _ state: DocumentState, _ save: @escaping () -> Void,
                       _ close: @escaping () -> Void, _ discard: @escaping () -> Void) {
        guard let url else { return }
        actions[url] = Actions(state: state, save: save, saveAndClose: close, discard: discard)
    }
    static func presentError(_ error: Error) { errors += 1 }
    static func beforeSave() async {
        saveWaiting = true
        while holdSaves { try? await Task.sleep(for: .milliseconds(10)) }
        saveWaiting = false
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
        precondition(wait { (js(found, "typeof window._mvBuildTOC === 'function' && !!document.querySelector('.mv-task-checkbox')") as? Bool) == true })
        precondition(wait { TaskListProbe.actions[file] != nil && window.delegate is CloseProxy })
    }
    var actions: TaskListProbe.Actions { TaskListProbe.actions[file]! }
    var raw: String { js(web, "window._mvRawLines.join('\\n')") as? String ?? "<missing>" }
    var disk: String { (try? String(contentsOf: file, encoding: .utf8)) ?? "<missing>" }
    func toggle(_ index: Int = 0) {
        let before = actions.state.text
        _ = js(web, "document.querySelectorAll('.mv-task-checkbox')[\(index)].click(); true")
        precondition(wait { actions.state.text != before }, "Task bridge failed")
    }
    func teardown() {
        guard !tornDown else { return }
        tornDown = true
        hosting.rootView = AnyView(EmptyView())
        hosting.layoutSubtreeIfNeeded()
        window.close()
        TaskListProbe.actions.removeValue(forKey: file)
        spin(0.1)
    }
}

@main struct TaskListRegression {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-tasks-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var failures = 0, passed = 0
        func check(_ name: String, _ ok: Bool) {
            if ok { passed += 1 } else { failures += 1 }
            print("\(ok ? "PASS" : "FAIL"): \(name)")
        }
        let original = "# Tasks\n\n- [ ] 한글 😀\n- [X] same\n  - [ ] same\n"
        let first = try Session(root.appendingPathComponent("first.md"), original)
        let second = try Session(root.appendingPathComponent("second.md"), original)
        defer { first.teardown(); second.teardown() }
        first.toggle()
        let one = first.raw
        first.toggle(2)
        let two = first.raw
        check("real bridge reaches DocumentState without publishing/autosaving", first.actions.state.text == two
              && first.model.document.text == original && first.disk == original && first.window.isDocumentEdited)
        check("two documents isolate drafts and checked nodes", second.raw == original && second.actions.state.text == original && !second.window.isDocumentEdited)
        first.actions.state.undoManager.undo()
        check("one toggle takes exactly one native Undo", wait { first.raw == one })
        first.actions.state.undoManager.undo()
        check("two native Undos restore source and clean flag", wait { first.raw == original && !first.window.isDocumentEdited }
              && !first.actions.state.undoManager.canUndo)
        first.actions.state.undoManager.redo()
        first.actions.state.undoManager.redo()
        check("native Redo restores both task states", wait { first.raw == two } && !first.actions.state.undoManager.canRedo)
        first.actions.save()
        check("explicit production Save writes exact task source", wait { first.disk == two && !first.window.isDocumentEdited })
        let reopened = try Session(root.appendingPathComponent("reopened.md"), first.disk)
        check("reopened saved source renders matching checked nodes", reopened.raw == two
              && (js(reopened.web, "Array.from(document.querySelectorAll('.mv-task-checkbox')).map(n => n.checked).join(',')") as? String) == "true,true,true")
        reopened.teardown()

        first.toggle()
        let snapshot = first.raw
        TaskListProbe.holdSaves = true
        first.actions.save()
        check("production Save can be paused with a stable snapshot", wait { TaskListProbe.saveWaiting })
        first.toggle(2)
        let later = first.raw
        TaskListProbe.holdSaves = false
        check("toggle during Save remains a later dirty change", wait { first.disk == snapshot && first.window.isDocumentEdited }
              && first.actions.state.text == later && later != snapshot)
        first.actions.save()
        check("later toggle can be explicitly saved", wait { first.disk == later && !first.window.isDocumentEdited })

        first.toggle()
        let draft = first.raw
        let errors = TaskListProbe.errors
        try FileManager.default.removeItem(at: first.file)
        first.actions.saveAndClose()
        check("failed Save preserves draft and window", wait { TaskListProbe.errors > errors }
              && first.actions.state.text == draft && first.raw == draft && first.window.contentView != nil
              && first.window.isDocumentEdited && first.window.closeCount == 0)
        try later.write(to: first.file, atomically: true, encoding: .utf8)
        first.actions.save()
        check("failed task save can be retried", wait { first.disk == draft && !first.window.isDocumentEdited })

        second.toggle()
        second.actions.discard()
        check("Don't Save restores last saved state without a write", wait { second.actions.state.text == original }
              && second.disk == original && !second.actions.state.undoManager.canUndo && second.window.closeCount > 0)

        first.toggle()
        let closedSaved = first.raw
        first.actions.saveAndClose()
        check("Save-and-close writes task snapshot and closes after success", wait { first.disk == closedSaved && !first.window.isDocumentEdited && first.window.closeCount > 0 })
        let rapid = try Session(root.appendingPathComponent("rapid.md"), original)
        _ = js(rapid.web, "const input = document.querySelector('.mv-task-checkbox'); input.click(); input.click(); input.click(); true")
        check("native disk preflight drains rapid clicks to latest draft", wait { rapid.actions.state.text == original.replacingOccurrences(of: "- [ ] 한글", with: "- [x] 한글") })
        for _ in 0..<3 { rapid.actions.state.undoManager.undo() }
        check("three queued toggles remain three native Undo steps", wait { rapid.raw == original } && !rapid.actions.state.undoManager.canUndo)
        rapid.teardown()
        first.teardown(); second.teardown()
        check("document previews are cleaned", !(try FileManager.default.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".mv_preview-") })
        print("\(passed) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
