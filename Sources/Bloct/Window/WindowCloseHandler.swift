import SwiftUI

// MARK: - Window close interception

final class CloseHandlerView: NSView {
    var proxy: CloseProxy?
    var onReady: ((CloseProxy) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let proxy, proxy.window !== window {
            proxy.detach()
            self.proxy = nil
        }
        guard let win = window, proxy == nil else { return }
        let p = CloseProxy()
        p.window = win
        proxy = p
        DispatchQueue.main.async { [weak self, weak win] in
            guard let self, let win, self.window === win, self.proxy === p else { return }
            p.next = win.delegate
            win.delegate = p
            self.onReady?(p)
        }
    }
}

struct WindowCloseHandler: NSViewRepresentable {
    var hasUnsavedChanges: Bool
    var onIntercept: () -> Void
    var onReady: (CloseProxy) -> Void

    func makeNSView(context: Context) -> CloseHandlerView { CloseHandlerView() }

    static func dismantleNSView(_ view: CloseHandlerView, coordinator: ()) {
        view.proxy?.detach()
        view.proxy = nil
        view.onReady = nil
    }

    func updateNSView(_ v: CloseHandlerView, context: Context) {
        if v.proxy == nil { v.onReady = onReady }
        v.proxy?.hasUnsavedChanges = { hasUnsavedChanges }
        v.proxy?.onIntercept = onIntercept
    }
}
