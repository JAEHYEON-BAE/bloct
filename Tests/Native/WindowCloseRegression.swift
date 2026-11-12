import AppKit

@MainActor private final class Delegate: NSObject, NSWindowDelegate {
    var resizeCount = 0
    // Objective-C capability queries are nonisolated; this harness runs them on main.
    nonisolated(unsafe) var closeCount = 0
    var allowsClose = false
    override func responds(to selector: Selector!) -> Bool {
        if selector == #selector(windowDidResize(_:)), closeCount > 0 { return false }
        return super.responds(to: selector)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { allowsClose }
    func windowDidResize(_ notification: Notification) { resizeCount += 1 }
    func windowWillClose(_ notification: Notification) {
        closeCount += 1
    }
}

@main struct WindowCloseRegression {
    @MainActor static func main() {
        setbuf(stdout, nil)
        NSApplication.shared.setActivationPolicy(.prohibited)
        var failures = 0
        func check(_ name: String, _ success: Bool) {
            print("\(success ? "PASS" : "FAIL"): \(name)")
            if !success { failures += 1 }
        }
        func makeWindow() -> NSWindow {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            return window
        }
        let window = makeWindow()
        let proxy = CloseProxy()
        let delegate = Delegate()
        proxy.window = window
        proxy.next = delegate
        window.delegate = proxy
        NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
        check("live delegate receives cached window notifications", delegate.resizeCount == 1)
        check("clean close honors the original delegate veto", !proxy.windowShouldClose(window))
        var intercepted = 0
        proxy.hasUnsavedChanges = { true }
        proxy.onIntercept = { intercepted += 1 }
        check("dirty close is intercepted once", !proxy.windowShouldClose(window) && intercepted == 1)
        proxy.bypass = true
        check("approved close bypass is consumed once", proxy.windowShouldClose(window) && !proxy.bypass)

        // A dynamic delegate can stop advertising a selector during teardown.
        // AppKit has already registered the proxy for that notification, so the
        // old proxy aborts below when its forwarding target declines the selector.
        autoreleasepool {
            proxy.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        }
        check("willClose reaches the original delegate exactly once", delegate.closeCount == 1)
        check("willClose unregisters the proxy before later notifications", window.delegate == nil)
        NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
        check("cached notification after target teardown does not crash", delegate.resizeCount == 1)
        window.close()

        // Non-closing view removal must restore the original delegate, without
        // clobbering a delegate installed by another owner in the meantime.
        let otherWindow = makeWindow(), otherProxy = CloseProxy(), otherDelegate = Delegate()
        otherProxy.window = otherWindow
        otherProxy.next = otherDelegate
        otherWindow.delegate = otherProxy
        otherProxy.detach()
        check("view removal restores its original delegate", otherWindow.delegate === otherDelegate)
        let replacement = Delegate()
        otherProxy.window = otherWindow
        otherProxy.next = otherDelegate
        otherWindow.delegate = replacement
        otherProxy.detach()
        check("view removal preserves a replacement delegate", otherWindow.delegate === replacement)
        otherWindow.delegate = nil
        otherWindow.close()
        print("\(failures) failures; real AppKit notification registration and teardown")
        exit(failures == 0 ? 0 : 1)
    }
}
