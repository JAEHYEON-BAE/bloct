import AppKit

// Safety net for quit paths that bypass the menu (e.g. dock right-click → Quit).
// The main ⌘Q path is handled by QuitCommands above, before SwiftUI can hide windows.
class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var isQuitting = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        interceptUnsavedWindowsForQuit() ? .terminateCancel : .terminateNow
    }
}
