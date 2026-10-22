import AppKit
import SwiftUI
import WebKit

// Hosts the production MarkdownWebView in an NSHostingView so SwiftUI drives the real
// makeNSView / updateNSView / dismantleNSView. This covers behaviour the view performs on
// its own: preview-file creation and cleanup for awkward document locations, the
// navigation policy, the bridge guard, overlapping initial loads and the scripts injected
// on didFinish. Page-level suites in Tests/js run inside such a hosted page.

/// Checks expected to fail until the referenced BUG_FIXES.md item is fixed. Each is
/// reported as XFAIL; an unexpected pass fails the run so the entry gets removed.
private let knownFailures: [String: String] = [:]

@MainActor private final class Recorder { var commits: [String] = [] }

@MainActor private enum Report {
    static var passed = 0, failed = 0, expectedFailures = 0, unexpectedPasses = 0, skipped = 0

    static func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        if let reference = knownFailures[name] {
            if ok {
                unexpectedPasses += 1
                print("XPASS: \(name) (\(reference) appears fixed; remove it from knownFailures)")
            } else {
                expectedFailures += 1
                print("XFAIL: \(name) [\(reference)] -> \(detail())")
            }
        } else if ok {
            passed += 1
            print("PASS: \(name)")
        } else {
            failed += 1
            print("FAIL: \(name) -> \(detail())")
        }
    }

    static func skip(_ name: String, _ reason: String) {
        skipped += 1
        print("SKIP: \(name) (\(reason))")
    }
}

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

@MainActor private func headingText(_ webView: WKWebView) -> String {
    js(webView, "const h = document.querySelector('#content h1'); return h ? h.textContent : '';") as? String ?? ""
}

/// The page has rendered and didFinish has injected the TOC script.
@MainActor private func pageReady(_ webView: WKWebView) -> Bool {
    wait { (js(webView, "return typeof window._mvBuildTOC === 'function' && !!document.querySelector('#content h1');") as? Bool) == true }
}

@MainActor private func bridgeWorks(_ webView: WKWebView, _ recorder: Recorder, token: String) -> Bool {
    _ = js(webView, "window.webkit.messageHandlers.commitEdit.postMessage(btoa('\(token)')); return true;")
    return wait(5) { recorder.commits.contains(token) }
}

@MainActor private func previewFiles(in directory: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        .filter { $0.hasPrefix(".mv_preview-") }
}

// MARK: - Document locations

@MainActor private func documentLocations(root: URL) throws {
    let fm = FileManager.default
    let pixel = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=")!
    let markdown = "# Title\n\n![p](pixel.png)\n\nbody"

    func makeFolder(_ relative: String) throws -> URL {
        let directory = root.appendingPathComponent(relative)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("user owned".utf8).write(to: directory.appendingPathComponent(".mv_preview.html"))
        try pixel.write(to: directory.appendingPathComponent("pixel.png"))
        try Data(markdown.utf8).write(to: directory.appendingPathComponent("doc.md"))
        return directory
    }

    // (label, folder holding the preview, document URL as presented, read-only)
    var cases: [(String, URL?, URL?, Bool)] = []
    for (label, relative) in [("ASCII folder", "plain"),
                              ("Korean folder with spaces", "강의 노트/1주차 (복습)"),
                              ("folder with # % and tilde", "a~b/100% #1"),
                              ("NFD-normalized Korean folder", "강의".decomposedStringWithCanonicalMapping + " 폴더")] {
        let directory = try makeFolder(relative)
        cases.append((label, directory, directory.appendingPathComponent("doc.md"), false))
    }
    let readOnly = try makeFolder("readonly")
    try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly.path)
    cases.append(("read-only folder", readOnly, readOnly.appendingPathComponent("doc.md"), true))
    let target = try makeFolder("symlink-target")
    let link = root.appendingPathComponent("symlink")
    try fm.createSymbolicLink(at: link, withDestinationURL: target)
    cases.append(("folder opened through a symlink", link, link.appendingPathComponent("doc.md"), false))
    cases.append(("new document", nil, nil, false))

    defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path) }

    for (label, directory, fileURL, isReadOnly) in cases {
        let recorder = Recorder()
        let hosting = host(markdown, fileURL, recorder)
        guard let webView = findWebView(in: hosting) else {
            Report.check("\(label): web view is created", false, "no WKWebView in the hosting view")
            continue
        }
        let loaded = pageReady(webView)
        Report.check("\(label): page loads", loaded, "url=\(webView.url?.absoluteString ?? "nil")")
        guard loaded else { dismantle(hosting); continue }
        Report.check("\(label): editor commits reach Swift", bridgeWorks(webView, recorder, token: "bridge"),
                     "url=\(webView.url?.absoluteString ?? "nil")")

        if let directory {
            let image = js(webView, """
                const image = document.querySelector('#content img');
                if (!image) return 'missing';
                try { await image.decode(); return image.naturalWidth === 1 ? 'loaded' : 'width ' + image.naturalWidth; }
                catch (_) { return 'decode failed'; }
                """) as? String
            Report.check("\(label): relative image loads", image == "loaded", image ?? "nil")
            if isReadOnly {
                Report.check("\(label): no preview file is written", previewFiles(in: directory).isEmpty,
                             "\(previewFiles(in: directory))")
            } else {
                Report.check("\(label): one unique preview file is written", previewFiles(in: directory).count == 1,
                             "\(previewFiles(in: directory))")
            }
        }
        dismantle(hosting)
        if let directory {
            Report.check("\(label): preview file is removed on close", previewFiles(in: directory).isEmpty,
                         "\(previewFiles(in: directory))")
            let legacy = try? String(contentsOf: directory.appendingPathComponent(".mv_preview.html"), encoding: .utf8)
            Report.check("\(label): existing .mv_preview.html is untouched", legacy == "user owned", legacy ?? "missing")
        }
    }
}

// MARK: - Navigation policy

@MainActor private func navigationPolicy(root: URL) throws {
    let directory = root.appendingPathComponent("navigation")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("other".utf8).write(to: directory.appendingPathComponent("other.md"))
    let recorder = Recorder()
    let hosting = host("# Nav\n\n[relative](other.md) [fragment](#nav)", directory.appendingPathComponent("doc.md"), recorder)
    defer { dismantle(hosting) }
    guard let webView = findWebView(in: hosting), pageReady(webView) else {
        Report.check("navigation: page loads", false, "page did not load")
        return
    }
    let start = webView.url
    // External http(s) links are left out: allowing them would open a real browser.
    let attempts = [
        ("clicking a relative .md link", "document.querySelector('a[href=\"other.md\"]').click();"),
        ("clicking a #fragment link", "document.querySelector('a[href=\"#nav\"]').click();"),
        ("script navigation to a local file", "location.href = 'other.md';"),
        ("script navigation to about:blank", "location.href = 'about:blank';"),
        ("location.reload()", "location.reload();"),
        ("history.pushState then back", "history.pushState({}, '', '#x'); history.back();"),
    ]
    for (label, code) in attempts {
        _ = js(webView, code + " return true;")
        spin(0.6)
        let intact = headingText(webView) == "Nav" && webView.url?.path == start?.path
        Report.check("navigation: \(label) keeps the editor page", intact,
                     "url=\(webView.url?.absoluteString ?? "nil") h1=\(headingText(webView))")
    }
    Report.check("navigation: bridge still works afterwards", bridgeWorks(webView, recorder, token: "after"), "no commit")
}

// MARK: - Overlapping initial loads

/// Updates arrive before the initial page finishes. Keep one native bootstrap and
/// render the newest snapshot when it finishes, including for shared about:blank URLs.
@MainActor private func overlappingInitialLoads(root: URL) throws {
    for (label, delay) in [("in the same run loop", 0.0), ("150 ms later", 0.15)] {
        for fileBacked in [true, false] {
            let name = "double load \(label) (\(fileBacked ? "file" : "new document"))"
            let directory = root.appendingPathComponent("double-\(Int(delay * 1000))-\(fileBacked)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = fileBacked ? directory.appendingPathComponent("doc.md") : nil
            let recorder = Recorder()
            let hosting = host("# FIRST\n\nv1", fileURL, recorder)
            if delay > 0 { spin(delay) }
            hosting.rootView = preview("# SECOND\n\nv2", fileURL, recorder)
            hosting.layoutSubtreeIfNeeded()
            guard let webView = findWebView(in: hosting) else {
                Report.check("\(name): page shows the latest text", false, "no web view")
                continue
            }
            wait(8) { !headingText(webView).isEmpty }
            spin(0.5)
            let heading = headingText(webView)
            Report.check("\(name): page shows the latest text", heading == "SECOND",
                         "h1=\(heading.isEmpty ? "<no page>" : heading) url=\(webView.url?.absoluteString ?? "nil")")
            if !heading.isEmpty {
                Report.check("\(name): bridge works", bridgeWorks(webView, recorder, token: "double"), "no commit")
            }
            dismantle(hosting)
            if fileBacked {
                Report.check("\(name): every preview file is removed on close", previewFiles(in: directory).isEmpty,
                             "\(previewFiles(in: directory))")
            }
        }
    }
}

// Hold a real didFinish callback so updates can be exercised both before policy
// and after WebKit finishes, without depending on CDN/process startup timing.
@MainActor private final class InitialLoadGate: NSObject, WKNavigationDelegate {
    let target: MarkdownWebView.Coordinator
    var finished: WKNavigation?
    var decisions = 0
    init(_ target: MarkdownWebView.Coordinator) { self.target = target }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        decisions += 1
        target.webView(webView, decidePolicyFor: action, decisionHandler: decisionHandler)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished = navigation }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        target.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        target.webView(webView, didFail: navigation, withError: error)
    }
}

@MainActor private func initialLoadLifecycle(root: URL) throws {
    let fm = FileManager.default
    for kind in ["file", "new", "readonly", "moved"] {
        let directory = root.appendingPathComponent("bootstrap-\(kind)")
        let destination = directory.appendingPathComponent("destination")
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for (folder, width) in [(directory, 7), (destination, 13)] {
            try "<svg xmlns='http://www.w3.org/2000/svg' width='\(width)' height='3'><rect width='100%' height='100%' fill='green'/></svg>"
                .write(to: folder.appendingPathComponent("pixel.svg"), atomically: true, encoding: .utf8)
        }
        if kind == "readonly" { try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path) }
        defer { if kind == "readonly" { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) } }
        let file = kind == "new" ? nil : directory.appendingPathComponent("doc.md")
        let latestFile = kind == "moved" ? destination.appendingPathComponent("doc.md") : file
        let recorder = Recorder()
        func snapshot(_ text: String, _ source: URL?, generation: Int = 0, edit: Bool = false) -> AnyView {
            AnyView(MarkdownWebView(markdown: text, fileURL: source, zoomLevel: 1, showTOC: true,
                isEditMode: edit, webViewStore: WebViewStore(), onTextCommit: { recorder.commits.append($0) },
                reloadGeneration: generation))
        }
        let hosting = NSHostingView(rootView: snapshot("# FIRST\n\nold", file))
        hosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        hosting.layoutSubtreeIfNeeded()
        guard let web = findWebView(in: hosting), let coordinator = web.navigationDelegate as? MarkdownWebView.Coordinator,
              let navigation = coordinator.pageLoad?.navigation else {
            Report.check("bootstrap \(kind): native navigation exists", false)
            dismantle(hosting)
            continue
        }
        let gate = InitialLoadGate(coordinator)
        web.navigationDelegate = gate
        for i in 1...5 {
            hosting.rootView = snapshot("# UPDATE \(i)\n\n중간 원문", file)
            hosting.layoutSubtreeIfNeeded()
        }
        Report.check("bootstrap \(kind): rapid updates retain one native navigation",
                     coordinator.pageLoad?.navigation === navigation)
        let finished = wait { gate.finished != nil }
        Report.check("bootstrap \(kind): real navigation finishes", finished)
        guard let completed = gate.finished else { dismantle(hosting); continue }

        let latest = "# LATEST\n\n최신 원문 📝" + (latestFile == nil ? "" : "\n\n![relative](pixel.svg)")
        hosting.rootView = snapshot(latest, latestFile, generation: 4, edit: true)
        hosting.layoutSubtreeIfNeeded()
        let unrelatedWeb = WKWebView(frame: .zero)
        let unrelated = unrelatedWeb.loadHTMLString("<p>unrelated</p>", baseURL: nil)!
        coordinator.webView(web, didFinish: unrelated)
        coordinator.webView(web, didFailProvisionalNavigation: unrelated, withError: URLError(.cancelled))
        coordinator.webView(web, didFail: unrelated, withError: URLError(.cancelled))
        Report.check("bootstrap \(kind): unrelated finish/failure cannot complete or reset the load",
                     !coordinator.isPageLoaded && coordinator.pageLoad?.navigation === navigation)
        coordinator.webView(web, didFinish: completed)
        Report.check("bootstrap \(kind): latest text and TOC render", wait {
            headingText(web) == "LATEST" && (js(web, "return document.querySelector('#toc a')?.textContent;") as? String) == "LATEST"
        })
        Report.check("bootstrap \(kind): source and generation are current",
            coordinator.fileURL == latestFile && (js(web, "return window._mvGeneration;") as? Int) == 4)
        Report.check("bootstrap \(kind): edit mode is current", (js(web, "return window._mvEditMode;") as? Bool) == true)
        Report.check("bootstrap \(kind): only one initial policy decision", gate.decisions == 1, "\(gate.decisions)")
        if latestFile != nil {
            let expectedWidth = kind == "moved" ? 13 : 7
            Report.check("bootstrap \(kind): relative image uses latest location", (js(web, """
                const image = document.querySelector('#content img');
                try { await image.decode(); return image.naturalWidth; } catch (_) { return 0; }
                """) as? Int) == expectedWidth)
        }
        let oldCount = recorder.commits.count
        _ = js(web, "window.webkit.messageHandlers.commitEdit.postMessage({text:btoa('stale'),generation:0}); return true;")
        spin(0.1)
        Report.check("bootstrap \(kind): old document generation cannot commit", recorder.commits.count == oldCount)
        _ = js(web, "window.webkit.messageHandlers.commitEdit.postMessage({text:btoa('current'),generation:4}); return true;")
        Report.check("bootstrap \(kind): latest generation can commit", wait { recorder.commits.last == "current" })

        // A duplicate completion or a late failure must not reinstall listeners or
        // reset a page that has already finished.
        _ = js(web, "window._mvBuildTOC = () => { window._unexpectedFinish = true; }; return true;")
        coordinator.webView(web, didFinish: completed)
        coordinator.webView(web, didFail: completed, withError: URLError(.cancelled))
        Report.check("bootstrap \(kind): duplicate completion and late failure are ignored",
            coordinator.isPageLoaded && (js(web, "return !!window._unexpectedFinish;") as? Bool) == false)

        // Verify the same allowlist after overlapping updates, including inline
        // pages whose legitimate URL is always about:blank.
        web.navigationDelegate = coordinator
        for code in ["location.href = 'about:blank';", "location.href = 'https://example.invalid/';", "location.reload();",
                     "history.pushState({}, '', '#x'); history.back();"] {
            _ = js(web, code + " return true;")
            spin(0.15)
        }
        Report.check("bootstrap \(kind): script/reload/history navigation remains blocked", headingText(web) == "LATEST")
        unrelatedWeb.stopLoading()
        dismantle(hosting)
        coordinator.webView(web, didFinish: completed)
        coordinator.webView(web, didFail: completed, withError: URLError(.cancelled))
        Report.check("bootstrap \(kind): closed view ignores late callbacks", !coordinator.isPageLoaded && coordinator.pageLoad == nil)
        Report.check("bootstrap \(kind): preview files removed", previewFiles(in: directory).isEmpty)
    }
}

@MainActor private func closeDuringInitialLoad(root: URL) throws {
    for fileBacked in [true, false] {
        let directory = root.appendingPathComponent("close-loading-\(fileBacked)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let hosting = host("# Closing", fileBacked ? directory.appendingPathComponent("doc.md") : nil, Recorder())
        guard let web = findWebView(in: hosting), let coordinator = web.navigationDelegate as? MarkdownWebView.Coordinator,
              let navigation = coordinator.pageLoad?.navigation else {
            Report.check("close loading \(fileBacked): native navigation exists", false)
            continue
        }
        dismantle(hosting) // Before any policy callback can consume the request.
        coordinator.webView(web, didFinish: navigation)
        coordinator.webView(web, didFailProvisionalNavigation: navigation, withError: URLError(.cancelled))
        coordinator.loadInitialPage("<p>late</p>", in: web, previewURL: nil, baseURL: nil)
        Report.check("close loading \(fileBacked): callbacks and new loads are rejected",
                     !coordinator.isPageLoaded && coordinator.pageLoad == nil && web.navigationDelegate == nil)
        Report.check("close loading \(fileBacked): preview removed", previewFiles(in: directory).isEmpty)
    }
}

@MainActor private func retryFailedInitialLoad(root: URL) throws {
    for fileBacked in [true, false] {
        let directory = root.appendingPathComponent("retry-loading-\(fileBacked)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = fileBacked ? directory.appendingPathComponent("doc.md") : nil
        let recorder = Recorder()
        let hosting = host("# FIRST", file, recorder)
        guard let web = findWebView(in: hosting), let coordinator = web.navigationDelegate as? MarkdownWebView.Coordinator,
              let oldNavigation = coordinator.pageLoad?.navigation else {
            Report.check("retry \(fileBacked): initial navigation exists", false)
            continue
        }
        let oldPreview = coordinator.tempHTMLURL
        let gate = InitialLoadGate(coordinator)
        web.navigationDelegate = gate
        // Use real navigation identities but control delivery: policy cancellation
        // is silent for loadHTMLString on some WebKit versions, so it cannot be
        // used as a portable way to produce didFailProvisionalNavigation.
        guard wait(until: { gate.finished != nil }) else {
            Report.check("retry \(fileBacked): original navigation finishes in WebKit", false)
            dismantle(hosting)
            continue
        }
        coordinator.webView(web, didFailProvisionalNavigation: oldNavigation, withError: URLError(.cannotLoadFromNetwork))
        Report.check("retry \(fileBacked): failure callback releases bootstrap", coordinator.pageLoad == nil)
        if let oldPreview {
            Report.check("retry \(fileBacked): failed preview removed", !FileManager.default.fileExists(atPath: oldPreview.path))
        }
        gate.finished = nil
        hosting.rootView = preview("# RETRY\n\nlatest", file, recorder)
        hosting.layoutSubtreeIfNeeded()
        let navigation = coordinator.pageLoad?.navigation
        Report.check("retry \(fileBacked): new navigation identity", navigation != nil && navigation !== oldNavigation)
        guard wait(until: { gate.finished != nil }), let current = gate.finished else {
            Report.check("retry \(fileBacked): replacement navigation finishes", false)
            dismantle(hosting)
            continue
        }
        coordinator.webView(web, didFinish: oldNavigation)
        coordinator.webView(web, didFailProvisionalNavigation: oldNavigation, withError: URLError(.cancelled))
        coordinator.webView(web, didFail: oldNavigation, withError: URLError(.cancelled))
        Report.check("retry \(fileBacked): old callbacks cannot change replacement state",
                     !coordinator.isPageLoaded && coordinator.pageLoad?.navigation === navigation)
        coordinator.webView(web, didFinish: current)
        Report.check("retry \(fileBacked): latest content and bridge recover", pageReady(web)
                     && headingText(web) == "RETRY" && bridgeWorks(web, recorder, token: "retry"))
        dismantle(hosting)
        Report.check("retry \(fileBacked): preview cleanup", previewFiles(in: directory).isEmpty)
    }
}

// Exercise the production bridge and DOM gating, including stale callbacks after
// a disk revision has replaced the page. Actual Cmd+R/menu routing is tested in CUA.
@MainActor private func reloadGuards(root: URL) throws {
    let directory = root.appendingPathComponent("reload-guards")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let recorder = Recorder()
    var allowEdit = false
    var editChecks = 0
    var reloadRequests = 0
    let view = MarkdownWebView(markdown: "# Reload guards\n\nbody", fileURL: directory.appendingPathComponent("doc.md"),
        zoomLevel: 1, showTOC: false, isEditMode: true, webViewStore: WebViewStore(),
        onTextCommit: { recorder.commits.append($0) },
        onReload: { reloadRequests += 1 },
        onBeforeEdit: { reply in editChecks += 1; reply(allowEdit) })
    let hosting = NSHostingView(rootView: AnyView(view))
    hosting.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
    hosting.layoutSubtreeIfNeeded()
    defer { dismantle(hosting) }
    guard let webView = findWebView(in: hosting), pageReady(webView) else {
        Report.check("reload: page loads", false); return
    }
    _ = js(webView, "window._mvStartBlockEdit(document.querySelector('.mv-block'), 0); return true;")
    spin(0.15)
    Report.check("reload: denied disk preflight prevents block edit", editChecks == 1 &&
        (js(webView, "return !document.getElementById('mv-block-editor');") as? Bool) == true)
    allowEdit = true
    _ = js(webView, "window._mvStartBlockEdit(document.querySelector('.mv-block'), 0); return true;")
    Report.check("reload: accepted disk preflight opens block", wait {
        (js(webView, "return !!document.getElementById('mv-block-editor');") as? Bool) == true
    })
    Report.check("reload: IME composition is explicitly tracked", (js(webView, """
        const ta = document.getElementById('mv-block-editor');
        ta.dispatchEvent(new CompositionEvent('compositionstart'));
        const started = window._mvComposing;
        ta.dispatchEvent(new CompositionEvent('compositionend'));
        return started && !window._mvComposing;
        """) as? Bool) == true)
    _ = js(webView, "document.dispatchEvent(new KeyboardEvent('keydown',{key:'r',metaKey:true,bubbles:true,cancelable:true})); return true;")
    Report.check("reload: Cmd+R from the page invokes native reload once", wait { reloadRequests == 1 })
    (webView as? DocumentWebView)?.documentGeneration = 2
    _ = js(webView, "window.webkit.messageHandlers.commitEdit.postMessage({text:btoa('stale'),generation:1}); return true;")
    spin(0.1)
    Report.check("reload: obsolete page generation cannot restore stale draft", !recorder.commits.contains("stale"))
    _ = js(webView, "window.webkit.messageHandlers.commitEdit.postMessage({text:btoa('current'),generation:2}); return true;")
    Report.check("reload: current generation can commit", wait { recorder.commits.contains("current") })
}

// MARK: - Page suites (Tests/js)

@MainActor private func pageSuites(root: URL, scripts: URL) throws {
    let files = try FileManager.default.contentsOfDirectory(at: scripts, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "js" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    for script in files {
        let suite = script.deletingPathExtension().lastPathComponent
        let directory = root.appendingPathComponent("suite-\(suite)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recorder = Recorder()
        let hosting = host("# Suite\n\nready", directory.appendingPathComponent("doc.md"), recorder)
        defer { dismantle(hosting) }
        guard let webView = findWebView(in: hosting), pageReady(webView) else {
            Report.check("\(suite): page loads", false, "page did not load")
            continue
        }
        let source = try String(contentsOf: script, encoding: .utf8)
        let output = js(webView, source, timeout: 90)
        guard let json = output as? String,
              let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let results = object["results"] as? [[String: Any]] else {
            Report.check("\(suite): suite completes", false, String(describing: output))
            continue
        }
        for result in results {
            let name = "\(suite): \(result["name"] as? String ?? "?")"
            let detail = result["detail"] as? String ?? ""
            if result["skip"] as? Bool == true {
                Report.skip(name, detail)
            } else {
                Report.check(name, result["pass"] as? Bool == true, detail)
            }
        }
    }
}

@main
struct HostedRegression {
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let scripts = URL(fileURLWithPath: CommandLine.arguments[1])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-hosted-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            // Scrolling in the test pages stores positions keyed by document path.
            for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix("scrollPos:") && key.contains("bloct-hosted-") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        try documentLocations(root: root)
        try navigationPolicy(root: root)
        try overlappingInitialLoads(root: root)
        try initialLoadLifecycle(root: root)
        try closeDuringInitialLoad(root: root)
        try retryFailedInitialLoad(root: root)
        try reloadGuards(root: root)
        try pageSuites(root: root, scripts: scripts)

        print("\n\(Report.passed) passed, \(Report.failed) failed, \(Report.expectedFailures) known failures, "
              + "\(Report.unexpectedPasses) unexpected passes, \(Report.skipped) skipped")
        if Report.failed > 0 || Report.unexpectedPasses > 0 { exit(1) }
    }
}
