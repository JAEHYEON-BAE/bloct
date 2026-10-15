import AppKit

// NSDocument's delegate API reports both write errors and Save-panel cancellation.
// Keep the delegate alive until AppKit calls back, including asynchronous sheets.
@MainActor
final class DocumentSaveOperation: NSObject {
    private var keepAlive: DocumentSaveOperation?
    private let completion: (Bool) -> Void

    private init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    static func save(_ document: NSDocument, completion: @escaping (Bool) -> Void) {
        let operation = DocumentSaveOperation(completion: completion)
        operation.keepAlive = operation
        document.save(withDelegate: operation,
                      didSave: #selector(didSave(_:success:contextInfo:)),
                      contextInfo: nil)
    }

    @objc private func didSave(_ document: NSDocument, success: Bool,
                               contextInfo: UnsafeMutableRawPointer?) {
        defer { keepAlive = nil }
        completion(success)
    }
}

// Run a save only after SwiftUI has observed the staged FileDocument value.
// The request is idempotent because view updates may deliver the same value again.
@MainActor
final class StagedDocumentSave {
    let text: String
    private var action: (@MainActor () -> Void)?

    init(text: String, action: @escaping @MainActor () -> Void) {
        self.text = text
        self.action = action
    }

    func run() {
        guard let action else { return }
        self.action = nil
        DispatchQueue.main.async { action() }
    }
}
