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
        let switchEditor: () -> Void
        let canSwitch: () -> Bool
    }
    static var actions: [URL: Actions] = [:]
    static var holdSaves = false, saveWaiting = false
    static var errors = 0
    static var closeWarnings = 0
    static func attach(_ url: URL?, _ state: DocumentState, _ save: @escaping () -> Void,
                       _ close: @escaping () -> Void, _ discard: @escaping () -> Void,
                       _ undo: @escaping () -> Void, _ redo: @escaping () -> Void,
                       _ requestClose: @escaping () -> Void, _ switchEditor: @escaping () -> Void, _ canSwitch: @escaping () -> Bool) {
        guard let url else { return }
        actions[url] = Actions(state: state, undo: undo, redo: redo, save: save, saveAndClose: close, discard: discard, requestClose: requestClose, switchEditor: switchEditor, canSwitch: canSwitch)
    }
    static func presentError(_ error: Error) { errors += 1; print("PROBE ERROR: \(error)") }
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
        let switching = try Session(root.appendingPathComponent("switching.md"), original)
        let originalWeb = switching.web, originalPage = switching.web.url
        _ = js(switching.web, "window.modePageMarker = 42; true")
        switching.toggle()
        let visualDraft = switching.raw
        switching.switchEditor()
        check("dirty visual mode hands off to Markdown without saving or dropping text",
              wait { !switching.isVisual && switching.raw == visualDraft && switching.window.isDocumentEdited }
              && switching.disk == original && switching.model.document.text == original)
        check("mode switch retains native WebView, page URL and live JS document", switching.web === originalWeb && switching.web.url == originalPage && js(switching.web,"window.modePageMarker") as? Int == 42)
        _ = js(switching.web, "document.querySelector('.mv-task-checkbox').click(); true")
        check("Aa off is read-only with no legacy edit API or textarea", switching.raw == visualDraft
              && js(switching.web,"typeof window._mvSetEditMode === 'undefined' && typeof window._mvStartBlockEdit === 'undefined' && !document.querySelector('textarea,[contenteditable=true]') && Array.from(document.querySelectorAll('.mv-task-checkbox')).every(n=>n.disabled)") as? Bool == true)
        _ = js(switching.web,"window.webkit.messageHandlers.commitEdit.postMessage({text:btoa('forged read edit'),generation:window._mvGeneration}); true")
        spin(0.1)
        check("reading rejects edit bridge commits", switching.actions.state.text == visualDraft)
        switching.actions.undo()
        check("Aa off cannot mutate the draft through native Undo", switching.raw == visualDraft)
        switching.switchEditor()
        check("Aa reentry preserves the unsaved draft and stays dirty", wait { switching.isVisual && switching.raw == visualDraft && switching.window.isDocumentEdited } && switching.disk == original)
        _ = js(switching.web, "let v=window._bloctVisual.view; v.dispatch(v.state.tr.insertText(' extra',v.state.doc.content.size-1)); true")
        let markdownDraft = switching.raw
        check("reentered Aa accepts further input", markdownDraft != visualDraft)
        check("Aa reentry uses the same native WebView and page", switching.web === originalWeb && switching.web.url == originalPage && js(switching.web,"window.modePageMarker") as? Int == 42)
        switching.actions.undo()
        check("mode-boundary Undo returns to the previous draft with its dirty baseline",
              wait { switching.raw == visualDraft && switching.window.isDocumentEdited })
        switching.actions.redo()
        check("mode-boundary Redo restores the carried Markdown draft",
              wait { switching.raw == markdownDraft && switching.window.isDocumentEdited })
        switching.actions.save()
        check("saving after a dirty roundtrip acknowledges the exact carried draft",
              wait { switching.disk == markdownDraft && !switching.window.isDocumentEdited })
        switching.switchEditor()
        check("saved visual mode can still leave and reenter", wait { !switching.isVisual })
        switching.switchEditor()
        check("saved visual reentry stays clean", wait { switching.isVisual && switching.raw == markdownDraft && !switching.window.isDocumentEdited })
        switching.toggle()
        switching.switchEditor()
        check("dirty handoff leaves the file unchanged", wait { !switching.isVisual && switching.window.isDocumentEdited } && switching.disk == markdownDraft)
        switching.actions.discard()
        check("Don't Save after switching preserves the disk baseline", wait { switching.window.closeCount > 0 } && switching.disk == markdownDraft)
        switching.teardown()

        let legacyStart = try Session(root.appendingPathComponent("legacy-start.md"), original, visual: false)
        _ = js(legacyStart.web, "window.keptView=window._bloctVisual.view; let p=document.querySelector('.ProseMirror h1'),r=p.getBoundingClientRect(); p.dispatchEvent(new MouseEvent('click',{bubbles:true,clientX:r.left+20,clientY:r.top+10})); true")
        check("document click enters editing through the native bridge in the same EditorView", wait { legacyStart.isVisual } && js(legacyStart.web,"window.keptView===window._bloctVisual.view") as? Bool == true)
        _ = js(legacyStart.web,"window._bloctVisual.view.dom.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true})); true")
        check("Escape leaves editing through the native bridge without replacing the view", wait { !legacyStart.isVisual } && js(legacyStart.web,"window.keptView===window._bloctVisual.view && !window._bloctVisual.view.editable") as? Bool == true)
        legacyStart.switchEditor()
        legacyStart.toggle()
        let legacySnapshot = legacyStart.raw
        VisualProbe.holdSaves = true
        legacyStart.actions.save()
        check("first Aa Save from Markdown startup freezes its exact snapshot", wait { VisualProbe.saveWaiting })
        legacyStart.toggle(1)
        let legacyLater = legacyStart.raw
        VisualProbe.holdSaves = false
        check("first Aa Save cannot reload away later typing or invalidate acknowledgement", wait { legacyStart.disk == legacySnapshot && legacyStart.window.isDocumentEdited } && legacyStart.raw == legacyLater)
        legacyStart.actions.undo()
        check("first Aa Save keeps engine Undo and its saved baseline", wait { legacyStart.raw == legacySnapshot && !legacyStart.window.isDocumentEdited })
        legacyStart.teardown()

        let readSave = try Session(root.appendingPathComponent("read-save.md"), original)
        readSave.toggle();let readDraft = readSave.raw
        readSave.switchEditor()
        check("Aa off retains a dirty unsaved draft", wait { !readSave.isVisual && readSave.window.isDocumentEdited } && readSave.disk == original)
        readSave.actions.save()
        check("Save after Aa off writes the exact draft while remaining read-only", wait { readSave.disk == readDraft && !readSave.window.isDocumentEdited } && !readSave.isVisual)
        readSave.switchEditor()
        check("Aa reentry after read-mode Save uses the saved baseline", wait { readSave.isVisual && readSave.raw == readDraft && !readSave.window.isDocumentEdited })
        readSave.teardown()

        let preflightDir = root.appendingPathComponent("preflight")
        try FileManager.default.createDirectory(at: preflightDir, withIntermediateDirectories: true)
        let preflight = try Session(preflightDir.appendingPathComponent("legacy-start.md"), original, visual:false)
        let preflightExternal = "# External before Aa\n\n- [ ] changed"
        try preflightExternal.write(to: preflight.file, atomically:true, encoding:.utf8)
        preflight.switchEditor()
        check("entering Aa reads the current clean disk version before editing", wait { preflight.isVisual && preflight.raw == preflightExternal && !preflight.window.isDocumentEdited })
        preflight.teardown()

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
        first.actions.undo()
        spin(0.1)
        first.actions.redo()
        check("native Redo reaches the same engine history after exhausted Undo", undone && wait { first.raw == changed && first.window.isDocumentEdited })
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
    var web: WKWebView { findWeb(hosting)! }
    private var tornDown = false
    init(_ file: URL, _ raw: String, visual: Bool = true) throws {
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
        precondition(wait { (js(found, "typeof window._mvBuildTOC === 'function' && window._mvIsEditing() === \(visual ? "true" : "false")") as? Bool) == true })
        precondition(wait { VisualProbe.actions[file] != nil && window.delegate is CloseProxy })
    }
    var actions: VisualProbe.Actions { VisualProbe.actions[file]! }
    var isVisual: Bool { js(web, "window._mvIsEditing()") as? Bool == true }
    var raw: String { js(web, "window._bloctVisual ? window._bloctVisual.session.markdown() : window._mvRawLines?.join('\\n')") as? String ?? "<missing>" }
    var disk: String { (try? String(contentsOf: file, encoding: .utf8)) ?? "<missing>" }
    func switchEditor() {
        precondition(wait { actions.canSwitch() }, "Mode button still busy")
        actions.switchEditor()
    }
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
