import AppKit
import SwiftUI

@MainActor
private final class ControlledDocument: NSDocument {
    weak var saveDelegate: NSObject?
    var selector: Selector?
    var context: UnsafeMutableRawPointer?

    override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?,
                       contextInfo: UnsafeMutableRawPointer?) {
        saveDelegate = delegate as? NSObject
        selector = didSaveSelector
        context = contextInfo
    }

    func finish(_ success: Bool) {
        guard let delegate = saveDelegate, let selector else {
            fatalError("Save callback delegate was released before completion")
        }
        typealias Callback = @convention(c) (AnyObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void
        let callback = unsafeBitCast(delegate.method(for: selector), to: Callback.self)
        callback(delegate, selector, self, success, context)
    }
}

@main
struct NativeRegression {
    @MainActor static func main() throws {
        let undo = UndoManager()
        undo.groupsByEvent = false
        var backing = MarkdownDocument(text: "original")
        var bindingUndoRegistrations = 0
        let binding = Binding(get: { backing }, set: { value in
            if undo.isUndoRegistrationEnabled { bindingUndoRegistrations += 1 }
            backing = value
        })
        let state = DocumentState(document: binding)
        state.undoManager = undo
        undo.beginUndoGrouping()
        state.commit("edited")
        undo.endUndoGrouping()
        precondition(state.text == "edited" && backing.text == "edited")
        undo.undo()
        precondition(state.text == "original" && backing.text == "original", "Undo must update the file model")
        undo.redo()
        precondition(state.text == "edited" && backing.text == "edited", "Redo must update the file model")
        precondition(bindingUndoRegistrations == 0, "Binding updates must not duplicate undo actions")
        state.restore("original")
        precondition(backing.text == "original" && state.text == "original" && !undo.canUndo)
        print("PASS: commit, Undo, Redo and discard keep the file model synchronized")

        for success in [false, true] {
            let document = ControlledDocument()
            var result: Bool?
            DocumentSaveOperation.save(document) { result = $0 }
            precondition(result == nil, "Must wait for AppKit completion")
            precondition(document.saveDelegate != nil, "Delegate must survive an asynchronous save")
            document.finish(success)
            precondition(result == success, "Must preserve AppKit's success/cancellation result")
            precondition(document.saveDelegate == nil, "Delegate must release after completion")
        }
        print("PASS: save completion waits, forwards failure/success and releases its delegate")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-native-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = directory.appendingPathComponent(".mv_preview.html")
        try Data("user file".utf8).write(to: legacy)
        let first = try PreviewFiles.create(html: "first", in: directory)
        let second = try PreviewFiles.create(html: "second", in: directory)
        precondition(first != second)
        let firstText = try String(contentsOf: first, encoding: .utf8)
        precondition(firstText == "first")
        let secondText = try String(contentsOf: second, encoding: .utf8)
        precondition(secondText == "second")
        PreviewFiles.remove(legacy)
        PreviewFiles.remove(first)
        precondition(FileManager.default.fileExists(atPath: second.path))
        PreviewFiles.removeAll()
        precondition(!FileManager.default.fileExists(atPath: second.path))
        let legacyText = try String(contentsOf: legacy, encoding: .utf8)
        precondition(legacyText == "user file")
        print("PASS: independent previews, owned cleanup and preservation of existing files")
    }
}
