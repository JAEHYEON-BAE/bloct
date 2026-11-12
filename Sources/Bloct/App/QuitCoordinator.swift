import AppKit

// Prompt one document at a time. Save / Don't Save continues the quit; Cancel
// stops the sequence without leaving alerts attached to the other windows.
@MainActor
func interceptUnsavedWindowsForQuit() -> Bool {
    let unsaved = NSApp.windows.filter {
        ($0.delegate as? CloseProxy)?.hasUnsavedChanges() == true
    }
    guard !unsaved.isEmpty else { return false }
    AppDelegate.isQuitting = true
    if let window = unsaved.first {
        window.makeKeyAndOrderFront(nil)
        (window.delegate as? CloseProxy)?.onIntercept()
    }
    return true
}

@MainActor
func handleQuit() {
    if !interceptUnsavedWindowsForQuit() {
        AppDelegate.isQuitting = false
        NSApp.terminate(nil)
    }
}
