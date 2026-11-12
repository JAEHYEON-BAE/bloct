import Foundation

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
