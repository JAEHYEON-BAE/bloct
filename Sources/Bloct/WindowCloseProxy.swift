import AppKit

class CloseProxy: NSObject, NSWindowDelegate {
    weak var window: NSWindow?
    weak var next: NSWindowDelegate?
    var bypass = false
    var hasUnsavedChanges: () -> Bool = { false }
    var onIntercept: () -> Void = {}

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if bypass { bypass = false; return true }
        if hasUnsavedChanges() { onIntercept(); return false }
        return next?.windowShouldClose?(sender) ?? true
    }

    func windowWillClose(_ notification: Notification) {
        // AppKit caches notification selectors when the delegate is installed.
        // SwiftUI can dismantle its dynamic forwarding target in windowWillClose;
        // leaving this proxy registered would then forward a later ordering
        // notification to a target that no longer implements that selector.
        let delegate = next
        if let window, window.delegate === self { window.delegate = nil }
        next = nil
        hasUnsavedChanges = { false }
        onIntercept = {}
        delegate?.windowWillClose?(notification)
    }

    @MainActor func detach() {
        if let window, window.delegate === self { window.delegate = next }
        next = nil
        window = nil
        hasUnsavedChanges = { false }
        onIntercept = {}
    }

    override func responds(to sel: Selector!) -> Bool {
        super.responds(to: sel) || (next?.responds(to: sel) ?? false)
    }
    override func forwardingTarget(for sel: Selector!) -> Any? {
        next?.responds(to: sel) == true ? next : super.forwardingTarget(for: sel)
    }
}
