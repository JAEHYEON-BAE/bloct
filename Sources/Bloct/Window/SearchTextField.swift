import AppKit
import SwiftUI

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
