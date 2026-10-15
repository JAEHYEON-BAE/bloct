import SwiftUI

@MainActor
final class DocumentState: ObservableObject {
    @Published private(set) var text: String
    private let document: Binding<MarkdownDocument>
    // FileDocument registers its own asynchronous undo actions. Draft edits use an
    // independent stack so those actions cannot add invisible undo steps.
    let undoManager = UndoManager()

    init(document: Binding<MarkdownDocument>) {
        self.document = document
        text = document.wrappedValue.text
        undoManager.groupsByEvent = false
    }

    // Only explicit Save may publish a draft to the file model. In particular,
    // closing a window must never let FileDocument autosave an abandoned draft.
    func stageForSave(_ snapshot: String) {
        document.wrappedValue.text = snapshot
    }

    func commit(_ newText: String) {
        guard newText != text else { return }
        let old = text
        text = newText
        let isReplaying = undoManager.isUndoing || undoManager.isRedoing
        if !isReplaying { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.commit(old) }
        }
        undoManager.setActionName("Typing")
        if !isReplaying { undoManager.endUndoGrouping() }
    }

    func restore(_ savedText: String) {
        text = savedText
        undoManager.removeAllActions()
    }
}
