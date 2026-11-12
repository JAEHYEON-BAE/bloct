import AppKit

// No applicationWillTerminate implementation: ownership must be sufficient to
// clean previews, even when an app delegate does not forward that callback.
@MainActor private final class TerminationDelegate: NSObject, NSApplicationDelegate {
    let directory: URL
    let cancelFirst: Bool
    var attempts = 0
    init(directory: URL, cancelFirst: Bool) {
        self.directory = directory
        self.cancelFirst = cancelFirst
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.terminate(nil)
        // Only a cancelled termination returns to this point.
        let previews = try! FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(".mv_preview-") && $0 != ".mv_preview-foreign.html" }
        guard cancelFirst && previews.count == 2 else { exit(2) }
        print("PASS: cancelled Quit keeps both live previews")
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        attempts += 1
        return cancelFirst && attempts == 1 ? .terminateCancel : .terminateNow
    }
}

@main struct PreviewTerminationRegression {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--child" {
            let directory = URL(fileURLWithPath: CommandLine.arguments[2])
            let scenario = CommandLine.arguments[3]
            let app = NSApplication.shared
            app.setActivationPolicy(.prohibited)
            _ = try PreviewFiles.create(html: "first live preview", in: directory)
            if scenario != "single" {
                _ = try PreviewFiles.create(html: "second live preview", in: directory)
            }
            let delegate = TerminationDelegate(directory: directory, cancelFirst: scenario == "cancel")
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
            exit(3) // A successful terminate must exit the process, not return.
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-preview-termination-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var failures = 0
        func check(_ name: String, _ ok: Bool) {
            print("\(ok ? "PASS" : "FAIL"): \(name)")
            if !ok { failures += 1 }
        }
        for scenario in ["single", "multiple", "cancel"] {
            let directory = root.appendingPathComponent(scenario)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let legacy = directory.appendingPathComponent(".mv_preview.html")
            let foreign = directory.appendingPathComponent(".mv_preview-foreign.html")
            try "user legacy file".write(to: legacy, atomically: true, encoding: .utf8)
            try "other session file".write(to: foreign, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = ["--child", directory.path, scenario]
            try process.run()
            process.waitUntilExit()
            check("\(scenario): real AppKit Quit exits normally", process.terminationReason == .exit && process.terminationStatus == 0)
            let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .filter { $0.hasPrefix(".mv_preview-") && $0 != ".mv_preview-foreign.html" }
            check("\(scenario): no owned previews after process exit (remaining: \(remaining.count))", remaining.isEmpty)
            let legacyText = try String(contentsOf: legacy, encoding: .utf8)
            let foreignText = try String(contentsOf: foreign, encoding: .utf8)
            check("\(scenario): legacy and other-session files are untouched", legacyText == "user legacy file" && foreignText == "other session file")
        }
        print("\(failures) failures; 3 real process terminations without delegate cleanup")
        exit(failures == 0 ? 0 : 1)
    }
}
