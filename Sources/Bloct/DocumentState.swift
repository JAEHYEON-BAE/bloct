import SwiftUI

@MainActor
final class DocumentState: ObservableObject {
    @Published private(set) var text: String
    private let document: Binding<MarkdownDocument>
    weak var undoManager: UndoManager?

    init(document: Binding<MarkdownDocument>) {
        self.document = document
        text = document.wrappedValue.text
    }

    private func apply(_ newText: String) {
        // This state owns undo registration; do not also register the binding update.
        undoManager?.disableUndoRegistration()
        document.wrappedValue.text = newText
        undoManager?.enableUndoRegistration()
        text = newText
    }

    func commit(_ newText: String) {
        guard newText != text else { return }
        let old = text
        apply(newText)
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { target.commit(old) }
        }
        undoManager?.setActionName("Typing")
    }

    func restore(_ savedText: String) {
        apply(savedText)
        undoManager?.removeAllActions(withTarget: self)
    }
}
