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

private final class ObservingPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue = {
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1; return queue
    }()
    private let lock = NSLock()
    private var saves = 0, deletions = 0
    init(url: URL) { presentedItemURL = url }
    func savePresentedItemChanges(completionHandler: @escaping ((any Error)?) -> Void) {
        lock.lock(); saves += 1; lock.unlock(); completionHandler(nil)
    }
    func accommodatePresentedItemDeletion(completionHandler: @escaping ((any Error)?) -> Void) {
        lock.lock(); deletions += 1; lock.unlock(); completionHandler(nil)
    }
    var notifications: (Int, Int) {
        lock.lock(); defer { lock.unlock() }; return (saves, deletions)
    }
}

@main
struct NativeRegression {
    @MainActor static func main() throws {
        let closingModel = MarkdownDocument(text: "discarded")
        let pendingSnapshot = closingModel
        closingModel.writeProtection.discard()
        do { try pendingSnapshot.writeProtection.validate(); fatalError("Discard must cancel retained native snapshots") }
        catch let error as CocoaError { precondition(error.code == .userCancelled) }
        print("PASS: discarded FileDocument snapshots reject delayed native writes")
        var draftBacking = MarkdownDocument(text: "saved")
        let draft = DocumentState(document: Binding(get: { draftBacking }, set: { draftBacking = $0 }))
        draft.commit("unconfirmed draft")
        precondition(draftBacking.text == "saved", "Unconfirmed edits must not reach FileDocument autosave or its Undo stack")

        var backing = MarkdownDocument(text: "original")
        var fileModelWrites = 0
        let binding = Binding(get: { backing }, set: { value in
            // Count every publication to the file model; draft edits must not publish.
            fileModelWrites += 1
            backing = value
        })
        let state = DocumentState(document: binding)
        let undo = state.undoManager
        state.commit("A")
        state.commit("B")
        state.commit("B") // Save's JS snapshot must not register another edit.
        precondition(state.text == "B" && backing.text == "original" && fileModelWrites == 0)
        undo.undo()
        precondition(state.text == "A", "First Undo must undo exactly one block commit")
        undo.undo()
        precondition(state.text == "original" && !undo.canUndo, "Two edits must take exactly two Undo steps")
        undo.redo()
        precondition(state.text == "A")
        undo.redo()
        precondition(state.text == "B" && !undo.canRedo)
        state.stageForSave(state.text)
        precondition(backing.text == "B" && fileModelWrites == 1)
        // A later edit must not mutate the snapshot an in-flight save is writing.
        state.commit("C while saving")
        precondition(backing.text == "B" && state.text == "C while saving")
        state.restore("B")
        precondition(backing.text == "B" && state.text == "B" && !undo.canUndo)
        state.commit("failed save draft")
        state.stageForSave(state.text)
        state.stageForSave("B") // Cancellation/failure restores only the file snapshot.
        precondition(state.text == "failed save draft" && backing.text == "B")
        state.restore("B")
        let writesBeforeDiscard = fileModelWrites
        print("PASS: exactly one Undo per commit, Redo, isolated save snapshots and discard")

        // Drain a run-loop turn as FileDocument would: abandoned edits must never
        // be delivered to a delayed model setter or an autosave consumer.
        for _ in 0..<25 {
            state.commit("abandoned")
            state.restore("B")
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
            precondition(backing.text == "B" && fileModelWrites == writesBeforeDiscard)
        }
        print("PASS: 25 delayed discard cycles never publish abandoned drafts")

        var stagedCalls = 0
        let staged = StagedDocumentSave(text: "snapshot") { stagedCalls += 1 }
        staged.run()
        staged.run()
        precondition(stagedCalls == 0, "Save must wait until the view update has completed")
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        precondition(stagedCalls == 1, "Repeated view updates must start the save only once")
        print("PASS: staged save starts once after the SwiftUI observation boundary")

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
        let source = directory.appendingPathComponent("source.md")
        try Data("version A".utf8).write(to: source)
        let timestamp = try FileManager.default.attributesOfItem(atPath: source.path)[.modificationDate] as! Date
        try Data("version B".utf8).write(to: source, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: timestamp], ofItemAtPath: source.path)
        let reloaded = try DocumentDisk.read(source)
        precondition(reloaded == "version B", "Same-time atomic replacement must be read by content")
        let protected = MarkdownDocument(text: "version B")
        protected.writeProtection.trackSource(source)
        try protected.writeProtection.validate(text: "version B")
        do { try protected.writeProtection.validate(text: "version A"); fatalError("Implicit stale write must fail") }
        catch let error as CocoaError { precondition(error.code == .userCancelled) }
        do {
            try DocumentDisk.save("stale draft", to: source, replacing: "version A")
            fatalError("Stale save must fail")
        } catch DocumentDisk.Conflict.changed {}
        let preserved = try DocumentDisk.read(source)
        precondition(preserved == "version B", "Conflict must preserve the external writer")
        let presenter = ObservingPresenter(url: source)
        NSFileCoordinator.addFilePresenter(presenter)
        _ = try DocumentDisk.read(source)
        try DocumentDisk.save("saved C", to: source, replacing: "version B")
        let notifications = presenter.notifications
        NSFileCoordinator.removeFilePresenter(presenter)
        precondition(notifications.0 == 0 && notifications.1 == 0,
                     "Inspect/update must not request presenter autosave or announce deletion")
        print("PASS: disk inspection/update never asks the file presenter to autosave or delete")
        let saved = try DocumentDisk.read(source)
        precondition(saved == "saved C")
        try FileManager.default.removeItem(at: source)
        do { try protected.writeProtection.validate(text: "saved C"); fatalError("Implicit deleted-file recreation must fail") }
        catch let error as CocoaError { precondition(error.code == .userCancelled) }
        do {
            try DocumentDisk.save("recreate stale draft", to: source, replacing: "saved C")
            fatalError("Deleted file must not be recreated by Save")
        } catch {}
        precondition(!FileManager.default.fileExists(atPath: source.path))
        print("PASS: same-time atomic replacement, coordinated conflict rejection, successful save and deleted-file protection")

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
