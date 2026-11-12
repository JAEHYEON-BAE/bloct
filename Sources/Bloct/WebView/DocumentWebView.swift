import AppKit
import WebKit

// Keep WebKit's selection/link/editor menus, but route Reload to the document.
final class DocumentWebView: WKWebView, NSMenuItemValidation {
    var reloadDocument: (() -> Void)?
    var documentGeneration = 0
    private var keyMonitor: Any?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeKeyMonitor()
        guard window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "r" else { return event }
            self.reloadDocument?()
            return nil
        }
    }
    func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "r" {
            reloadDocument?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        for item in menu.items where item.title == "Reload" { menu.removeItem(item) }
        menu.addItem(.separator())
        let reload = NSMenuItem(title: "Reload", action: #selector(reloadSource), keyEquivalent: "")
        reload.target = self
        reload.isEnabled = reloadDocument != nil
        menu.addItem(reload)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(reloadSource) || reloadDocument != nil
    }
    @objc private func reloadSource() { reloadDocument?() }
}
