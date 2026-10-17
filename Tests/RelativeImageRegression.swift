import AppKit
import SwiftUI
import WebKit

@MainActor private final class Recorder { var commits: [String] = [] }

@MainActor private func spin(_ seconds: Double) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

@MainActor @discardableResult
private func wait(_ timeout: Double = 15, until predicate: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() && Date() < deadline { spin(0.02) }
    return predicate()
}

@MainActor private func js(_ webView: WKWebView, _ body: String, timeout: Double = 15) -> Any? {
    var done = false
    var output: Any?
    webView.callAsyncJavaScript(body, arguments: [:], in: nil, in: .page) { result in
        switch result {
        case .success(let value): output = value
        case .failure(let error): output = "JS error: \(error.localizedDescription)"
        }
        done = true
    }
    wait(timeout) { done }
    return output
}

@MainActor private func findWebView(in view: NSView) -> WKWebView? {
    if let webView = view as? WKWebView { return webView }
    for subview in view.subviews {
        if let webView = findWebView(in: subview) { return webView }
    }
    return nil
}

@MainActor private func preview(_ markdown: String, _ fileURL: URL?, _ recorder: Recorder) -> AnyView {
    AnyView(MarkdownWebView(markdown: markdown, fileURL: fileURL, zoomLevel: 1, showTOC: false,
                            isEditMode: false, webViewStore: WebViewStore(),
                            onTextCommit: { recorder.commits.append($0) }))
}

@MainActor private func host(_ markdown: String, _ fileURL: URL?, _ recorder: Recorder) -> NSHostingView<AnyView> {
    let hosting = NSHostingView(rootView: preview(markdown, fileURL, recorder))
    hosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
    hosting.layoutSubtreeIfNeeded()
    return hosting
}

/// Replacing the root view makes SwiftUI call dismantleNSView, as closing a window does.
@MainActor private func dismantle(_ hosting: NSHostingView<AnyView>) {
    hosting.rootView = AnyView(EmptyView())
    hosting.layoutSubtreeIfNeeded()
    spin(0.3)
}

/// The page has rendered and didFinish has injected the TOC script.
@MainActor private func pageReady(_ webView: WKWebView) -> Bool {
    wait { (js(webView, "return typeof window._mvBuildTOC === 'function' && !!document.querySelector('#content h1');") as? Bool) == true }
}

@MainActor private final class ResourceTask: NSObject, @preconcurrency WKURLSchemeTask {
    let request: URLRequest
    var response: URLResponse?
    var data = Data()
    var finished = false
    var error: Error?
    init(_ url: URL, method: String = "GET") {
        var request = URLRequest(url: url)
        request.httpMethod = method
        self.request = request
    }
    func didReceive(_ response: URLResponse) { self.response = response }
    func didReceive(_ data: Data) { self.data.append(data) }
    func didFinish() { finished = true }
    func didFailWithError(_ error: any Error) { self.error = error }
}

// Use the production SwiftUI view and inspect actual image decoding; no XFAIL/SKIP.
@main
struct RelativeImageRegression {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let fm = FileManager.default
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let imageData = try Data(contentsOf: root.appendingPathComponent("pixel.png"))
        var passed = 0, failed = 0
        func check(_ name: String, _ ok: Bool) {
            if ok { passed += 1 } else { failed += 1 }
            print("\(ok ? "PASS" : "FAIL") \(name)")
        }
        for folder in ["plain/docs/chapter", "한글 공백/docs/chapter", "readonly/docs/chapter"] {
            let directory = root.appendingPathComponent(folder, isDirectory: true)
            try fm.createDirectory(at: directory.appendingPathComponent("images"), withIntermediateDirectories: true)
            for destination in [directory.appendingPathComponent("pixel.png"),
                                directory.appendingPathComponent("images/pixel.png"),
                                directory.deletingLastPathComponent().appendingPathComponent("pixel.png"),
                                directory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("pixel.png")] {
                try imageData.write(to: destination)
            }
            let paths = ["pixel.png", "./pixel.png", "images/pixel.png", "../pixel.png", "../../pixel.png", "../chapter/pixel.png"]
            let markdown = "# Relative image probe\n\n" + paths.map { "\($0)\n\n![\($0)](\($0))" }.joined(separator: "\n\n")
            let document = directory.appendingPathComponent("probe.md")
            try Data(markdown.utf8).write(to: document)
            let readOnly = folder.hasPrefix("readonly/")
            if readOnly { try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path) }
            defer { if readOnly { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) } }
            for iteration in 1...3 {
                let hosting = host(markdown, document, Recorder())
                guard let webView = findWebView(in: hosting), pageReady(webView) else {
                    print("FAIL page: \(folder), iteration \(iteration)")
                    failed += 1
                    dismantle(hosting)
                    continue
                }
                let result = js(webView, """
                    return JSON.stringify(await Promise.all(Array.from(document.querySelectorAll('#content img')).map(async image => {
                        let decoded = false, error = '';
                        try { await image.decode(); decoded = true; } catch (e) { error = e.name + ': ' + e.message; }
                        return {src: image.getAttribute('data-mv-image-source') || image.getAttribute('src'), resolved: image.src, decoded,
                                complete: image.complete, naturalWidth: image.naturalWidth, error};
                    })));
                    """) as? String ?? "[]"
                let rows = (try? JSONSerialization.jsonObject(with: Data(result.utf8))) as? [[String: Any]] ?? []
                print("PAGE \(folder) iteration=\(iteration) url=\(webView.url?.absoluteString ?? "nil")")
                print(result)
                if rows.count != paths.count { print("FAIL image count: \(rows.count)"); failed += 1 }
                for row in rows {
                    let src = row["src"] as? String ?? "?"
                    let target = URL(fileURLWithPath: src, relativeTo: directory).standardizedFileURL
                    let exists = fm.fileExists(atPath: target.path)
                    let loaded = (row["decoded"] as? Bool == true) && ((row["naturalWidth"] as? Int ?? 0) > 0)
                    let ok = exists && loaded
                    if ok { passed += 1 } else { failed += 1 }
                    print("\(ok ? "PASS" : "FAIL") \(folder) #\(iteration) \(src): exists=\(exists) decoded=\(loaded)")
                }
                dismantle(hosting)
            }
        }
        let originalPassed = passed, originalFailed = failed
        print("BASELINE: \(originalPassed) passed, \(originalFailed) failed (54 image expectations)")

        // Different pixels/dimensions make accidental cross-document resolution observable.
        let directory = root.appendingPathComponent("extended", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = directory.appendingPathComponent("probe.md")
        try imageData.write(to: directory.appendingPathComponent("한글 공백 #100%.png"))
        let bitmap = NSBitmapImageRep(data: imageData)!
        try bitmap.representation(using: .jpeg, properties: [:])!.write(to: directory.appendingPathComponent("photo.jpg"))
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"16\"><rect width=\"32\" height=\"16\" fill=\"green\"/></svg>"
        try Data(svg.utf8).write(to: directory.appendingPathComponent("vector.svg"))
        try? fm.removeItem(at: directory.appendingPathComponent("linked.png"))
        try fm.createSymbolicLink(at: directory.appendingPathComponent("linked.png"),
                                 withDestinationURL: root.appendingPathComponent("pixel.png"))
        let source = "# Extended\n\n![encoded](%ED%95%9C%EA%B8%80%20%EA%B3%B5%EB%B0%B1%20%23100%25.png)\n\n![jpeg](photo.jpg)\n\n![svg](vector.svg)\n\n![custom](../pixel.png){width=48}\n\n<img src=\"한글 공백 %23100%25.png\">\n\n![symlink](linked.png)\n\n![absolute](\(root.appendingPathComponent("pixel.png").absoluteString))"
        try Data(source.utf8).write(to: document)
        let recorder = Recorder()
        let hosting = host(source, document, recorder)
        guard let webView = findWebView(in: hosting), pageReady(webView) else {
            print("FAIL extended page load"); exit(1)
        }
        let widths = js(webView, """
            return await Promise.all(Array.from(document.querySelectorAll('#content img')).map(async image => {
                try { await image.decode(); return image.naturalWidth; } catch (_) { return 0; }
            }));
            """) as? [Int]
        print("EXTENDED decoded widths: \(String(describing: widths))")
        check("JPEG/SVG, encoded/raw Korean # % paths, custom syntax, symlink and absolute file image decode",
              widths == [96, 96, 32, 96, 96, 96, 96])
        let copyOK = js(webView, """
            const image = document.querySelector('#content img[alt="custom"]');
            const selection = getSelection(), range = document.createRange();
            range.selectNode(image); selection.removeAllRanges(); selection.addRange(range);
            let copied = '';
            const event = new Event('copy', {bubbles: true, cancelable: true});
            Object.defineProperty(event, 'clipboardData', {value: {setData: (_, text) => {copied = text;}}});
            document.dispatchEvent(event); selection.removeAllRanges();
            return copied.includes('![custom](../pixel.png)') && !copied.includes('bloct-image:');
            """) as? Bool
        check("copy uses the original Markdown image URL", copyOK == true)

        let edited = "# Edited\n\n![new image](vector.svg)"
        _ = js(webView, """
            window._mvSetEditMode(true);
            window._mvStartBlockEdit(document.querySelector('#content .mv-block'), 0, false);
            const editor = document.getElementById('mv-block-editor');
            editor.value = '# Edited'; editor.dispatchEvent(new Event('input', {bubbles:true}));
            window._mvCloseEditor(true); return true;
            """)
        check("editing a block preserves original image references in the Swift commit",
              wait { recorder.commits.last?.contains("![custom](../pixel.png)") == true })
        hosting.rootView = preview(edited, document, recorder)
        hosting.layoutSubtreeIfNeeded()
        check("live replacement decodes a newly referenced image", wait {
            (js(webView, "const i=document.querySelector('#content img'); try { await i.decode(); return i.naturalWidth === 32; } catch (_) {return false;}") as? Bool) == true
        })
        try Data(edited.utf8).write(to: document)
        dismantle(hosting)
        let reopened = host(try String(contentsOf: document, encoding: .utf8), document, Recorder())
        if let reopenedWebView = findWebView(in: reopened), pageReady(reopenedWebView) {
            check("saved source reopens with its image", (js(reopenedWebView, "const i=document.querySelector('#content img'); try {await i.decode(); return i.naturalWidth === 32;} catch (_) {return false;}") as? Bool) == true)
        } else { check("saved source reopens with its image", false) }
        dismantle(reopened)

        let otherDirectory = root.appendingPathComponent("other-document", isDirectory: true)
        try fm.createDirectory(at: otherDirectory, withIntermediateDirectories: true)
        let small = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=")!
        try small.write(to: otherDirectory.appendingPathComponent("pixel.png"))
        let first = host("# First\n\n![p](pixel.png)", root.appendingPathComponent("first.md"), Recorder())
        let second = host("# Second\n\n![p](pixel.png)", otherDirectory.appendingPathComponent("second.md"), Recorder())
        if let a = findWebView(in: first), let b = findWebView(in: second), pageReady(a), pageReady(b) {
            let aWidth = js(a, "const i=document.querySelector('img'); await i.decode(); return i.naturalWidth;") as? Int
            let bWidth = js(b, "const i=document.querySelector('img'); await i.decode(); return i.naturalWidth;") as? Int
            check("same relative name in two documents resolves independently", aWidth == 96 && bWidth == 1)
            let foreign = js(a, "return document.querySelector('img').src;") as? String ?? ""
            let literal = String(data: try JSONSerialization.data(withJSONObject: [foreign]), encoding: .utf8)!
            check("another document's resource token is rejected", (js(b, "const i=new Image(); i.src=\(literal)[0]; try {await i.decode(); return false;} catch (_) {return true;}") as? Bool) == true)
            // Save As changes the base even when the Markdown text is unchanged.
            first.rootView = preview("# First\n\n![p](pixel.png)", otherDirectory.appendingPathComponent("moved.md"), Recorder())
            first.layoutSubtreeIfNeeded()
            check("document location change re-resolves unchanged image source", wait {
                (js(a, "const i=document.querySelector('img'); try {await i.decode(); return i.naturalWidth === 1;} catch (_) {return false;}") as? Bool) == true
            })
        } else { check("two document pages load", false) }
        dismantle(first); dismantle(second)

        // Assert that non-images never cross the native response boundary, even if the
        // page directly requests the scheme, rather than merely failing image decoding.
        let loader = LocalImageLoader()
        loader.setDocumentURL(document)
        func resourceURL(_ source: String, host: String? = nil) -> URL {
            var parts = URLComponents()
            parts.scheme = LocalImageLoader.scheme
            parts.host = host ?? loader.host
            parts.path = "/"
            parts.queryItems = [URLQueryItem(name: "src", value: source)]
            return parts.url!
        }
        try Data("private text".utf8).write(to: directory.appendingPathComponent("secret.md"))
        try fm.createDirectory(at: directory.appendingPathComponent("directory.png"), withIntermediateDirectories: true)
        for (label, url, method) in [
            ("non-image file", resourceURL("secret.md"), "GET"),
            ("directory named .png", resourceURL("directory.png"), "GET"),
            ("missing image", resourceURL("missing.png"), "GET"),
            ("remote source", resourceURL("https://example.invalid/image.png"), "GET"),
            ("foreign token", resourceURL("vector.svg", host: "foreign"), "GET"),
            ("POST request", resourceURL("vector.svg"), "POST")
        ] {
            let task = ResourceTask(url, method: method)
            loader.webView(webView, start: task)
            _ = wait { task.finished || task.error != nil }
            check("loader rejects \(label) without sending bytes", task.error != nil && task.response == nil && task.data.isEmpty)
        }
        let oldURL = resourceURL("vector.svg")
        loader.invalidate()
        let task = ResourceTask(oldURL)
        loader.webView(webView, start: task)
        check("closed loader revokes the old token", task.error != nil && task.data.isEmpty)
        check("owned previews are cleaned after all documents close", !fm.enumerator(atPath: root.path)!.allObjects.contains {
            ($0 as? String)?.components(separatedBy: "/").last?.hasPrefix(".mv_preview-") == true
        })
        PreviewFiles.removeAll()
        print("RESULT: \(passed) passed, \(failed) failed, 0 skipped (image and resource regression expectations)")
        if failed > 0 { exit(1) }
    }
}
