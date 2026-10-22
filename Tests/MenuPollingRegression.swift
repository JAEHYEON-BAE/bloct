import AppKit
import SwiftUI
import WebKit

// Count the real ContentView body and coordinated reads in temporary, instrumented
// source copies. This catches idle focused-command republishing that page-only
// WebKit tests cannot see; it does not claim to verify visible menu tracking.
@MainActor enum MenuPollingProbe {
    static var bodies = 0
    static var reads = 0
    static func recordBody() { bodies += 1 }
}

@MainActor private final class Model {
    var document = MarkdownDocument(text: "# Original\n\nbody")
    var binding: Binding<MarkdownDocument> {
        Binding(get: { self.document }, set: { self.document = $0 })
    }
}

@MainActor private func spin(_ seconds: Double, mode: RunLoop.Mode = .default) {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        _ = RunLoop.current.run(mode: mode, before: min(deadline, Date().addingTimeInterval(0.02)))
    }
}

@MainActor private func webView(in view: NSView) -> WKWebView? {
    if let result = view as? WKWebView { return result }
    return view.subviews.lazy.compactMap { webView(in: $0) }.first
}

@MainActor private func js(_ view: WKWebView, _ source: String) -> Any? {
    var done = false
    var value: Any?
    view.evaluateJavaScript(source) { result, _ in value = result; done = true }
    let deadline = Date().addingTimeInterval(5)
    while !done && Date() < deadline { spin(0.02) }
    return value
}

@main struct MenuPollingRegression {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-menu-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("document.md")
        let model = Model()
        try model.document.text.write(to: file, atomically: true, encoding: .utf8)
        let hosting = NSHostingView(rootView: AnyView(ContentView(document: model.binding, fileURL: file)))
        hosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        hosting.layoutSubtreeIfNeeded()
        guard let web = webView(in: hosting) else { fatalError("no production web view") }
        spin(2)
        var failures = 0
        func check(_ label: String, _ ok: Bool, _ detail: String = "") {
            print("\(ok ? "PASS" : "FAIL"): \(label) \(detail)")
            if !ok { failures += 1 }
        }
        check("ContentView renders", (js(web, "document.querySelector('#content h1')?.textContent") as? String) == "Original")

        let initialBodies = MenuPollingProbe.bodies, initialReads = MenuPollingProbe.reads
        spin(3.2)
        check("idle polling continues", MenuPollingProbe.reads - initialReads >= 4,
              "reads=\(MenuPollingProbe.reads - initialReads)")
        check("unchanged file does not rebuild ContentView / focused commands", MenuPollingProbe.bodies == initialBodies,
              "bodyUpdates=\(MenuPollingProbe.bodies - initialBodies)")

        // Drain any read already in flight before isolating event tracking.
        spin(0.1)
        let trackingReads = MenuPollingProbe.reads
        spin(2, mode: .eventTracking)
        check("automatic polling pauses in event tracking", MenuPollingProbe.reads == trackingReads,
              "reads=\(MenuPollingProbe.reads - trackingReads)")

        try "# External\n\nchanged".write(to: file, atomically: true, encoding: .utf8)
        spin(1.5)
        check("external replacement still reloads", (js(web, "document.querySelector('#content h1')?.textContent") as? String) == "External")

        // A committed draft must survive periodic reads without publishing to disk.
        _ = js(web, "window.webkit.messageHandlers.commitEdit.postMessage({text:btoa('# Draft\\n\\nunsaved'),generation:window._mvGeneration}); true")
        spin(0.5)
        let draftBodies = MenuPollingProbe.bodies
        spin(1.5)
        check("draft survives unchanged disk polling", (js(web, "window._mvRawLines.join('\\n')") as? String) == "# Draft\n\nunsaved")
        check("draft polling does not rebuild commands", MenuPollingProbe.bodies == draftBodies,
              "bodyUpdates=\(MenuPollingProbe.bodies - draftBodies)")
        let diskText = try String(contentsOf: file, encoding: .utf8)
        check("draft does not reach FileDocument or disk", model.document.text == "# Original\n\nbody"
              && diskText == "# External\n\nchanged")

        hosting.rootView = AnyView(EmptyView())
        hosting.layoutSubtreeIfNeeded()
        spin(0.3)
        let closedReads = MenuPollingProbe.reads
        spin(1.3)
        check("closed view stops polling", MenuPollingProbe.reads == closedReads)
        check("owned preview cleaned on close", !(try FileManager.default.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".mv_preview-") })
        print("\(failures) failures")
        if failures > 0 { exit(1) }
    }
}
