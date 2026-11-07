import AppKit
import SwiftUI
import WebKit

@main
struct WebKitRegression {
    @MainActor static func wait(_ label: String, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(25)
        while !predicate() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(predicate(), "Timed out: \(label)")
    }

    @MainActor static func js(_ webView: WKWebView, _ body: String,
                              arguments: [String: Any] = [:]) -> Any? {
        var done = false
        var output: Any?
        var failure: Error?
        webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) { result in
            switch result {
            case .success(let value): output = value
            case .failure(let error): failure = error
            }
            done = true
        }
        wait("JavaScript", until: { done })
        precondition(failure == nil, "JavaScript failed: \(String(describing: failure))")
        return output
    }

    @MainActor static func check(_ webView: WKWebView, _ expression: String, _ label: String) {
        precondition(js(webView, "return !!(\(expression));") as? Bool == true, label)
        print("PASS: \(label)")
    }

    @MainActor static func main() throws {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let view = MarkdownWebView(markdown: "# Initial\n\nText", fileURL: nil,
                                   zoomLevel: 1, showTOC: false, webViewStore: WebViewStore())
        // All rendering assets are bundled; no CDN or test renderer is involved.
        let html = view.buildHTML()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bloct-webkit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            PreviewFiles.removeAll()
            try? FileManager.default.removeItem(at: directory)
        }
        let page = try PreviewFiles.create(html: html, in: directory)
        let coordinator = MarkdownWebView.Coordinator()
        coordinator.showTOC = false
        var commits: [String] = []
        coordinator.onTextCommit = { commits.append($0) }
        let config = WKWebViewConfiguration()
        for name in ["openExternal", "closeTOC", "scrollPosition", "commitEdit", "editorDirty"] {
            config.userContentController.add(coordinator, name: name)
        }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 800), configuration: config)
        webView.navigationDelegate = coordinator
        coordinator.loadInitialPage(html, in: webView, previewURL: page, baseURL: directory)
        wait("file page load", until: { coordinator.isPageLoaded })
        check(webView, "typeof DOMPurify !== 'undefined' && DOMPurify.isSupported && document.querySelector('h1').textContent === 'Initial'", "bundled sanitizer and initial renderer load under CSP")

        func render(_ raw: String) {
            _ = js(webView, "window._mvRender(md); return true;", arguments: ["md": Data(raw.utf8).base64EncodedString()])
        }
        let fixture = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
            + "\n## Heading $\\frac{a}{b}$\n"
        render(fixture)
        check(webView, "document.querySelectorAll('.katex-display').length === 2 && !document.querySelector('.katex-error')", "state-space matrix and later equation render completely in Markdown mode")
        let metrics = """
            await document.fonts.ready;
            return Array.from(document.querySelectorAll('#content .katex')).map(e => {
                const style=getComputedStyle(e);
                const boxes=Array.from(e.querySelectorAll('.katex-html > .katex-base'),n=>n.getBoundingClientRect());
                return {tex:e.querySelector('annotation').textContent,display:!!e.closest('.katex-display'),
                    font:style.fontFamily,size:style.fontSize,width:boxes.reduce((sum,r)=>sum+r.width,0),height:Math.max(...boxes.map(r=>r.height))};
            });
            """
        let baseline = js(webView, metrics) as! [[String:Any]]
        let visual = WKWebView(frame: webView.frame, configuration: WKWebViewConfiguration())
        visual.loadHTMLString(MarkdownWebView(markdown: fixture, fileURL: nil, zoomLevel: 1,
            showTOC: false, webViewStore: WebViewStore(), visualEditing: true).buildHTML(), baseURL: directory)
        wait("visual math page", until: { !visual.isLoading && js(visual,"return !!window._bloctVisual;") as? Bool == true })
        check(visual,"document.querySelectorAll('.katex-display').length === 2 && !document.querySelector('.katex-error')", "Aa mode retains the whole state-space matrix and following equation")
        let actual = js(visual, metrics) as! [[String:Any]]
        precondition(baseline.count==11 && actual.count==baseline.count)
        precondition(zip(baseline,actual).allSatisfy { a,b in
            a["tex"] as? String == b["tex"] as? String && a["display"] as? Bool == b["display"] as? Bool
        },"math TeX/display mode changed")
        print("PASS: identical original TeX and display/inline mode across Aa (11 equations)")
        for (a,b) in zip(baseline,actual) {
            if abs((a["width"] as! Double)-(b["width"] as! Double))>=0.1
                || abs((a["height"] as! Double)-(b["height"] as! Double))>=0.1
                || a["size"] as? String != b["size"] as? String {
                print("METRIC baseline \(a) visual \(b)")
            } else if a["font"] as? String != b["font"] as? String {
                print("METRIC baseline \(a) visual \(b)")
            }
        }
        precondition(zip(baseline,actual).allSatisfy { a,b in
            a["font"] as? String == b["font"] as? String && a["size"] as? String == b["size"] as? String
            && abs((a["width"] as! Double)-(b["width"] as! Double))<0.1
            && abs((a["height"] as! Double)-(b["height"] as! Double))<0.1
        },"math font or glyph geometry changed")
        print("PASS: identical math font/size and glyph geometry across Aa (11 equations, <0.1px)")
        let fixtureJSON = String(data: try JSONSerialization.data(withJSONObject: [fixture]), encoding:.utf8)!
        check(visual, "window._bloctVisual.session.markdown() === \(fixtureJSON)[0] && !window._bloctVisual.session.changed", "Aa display preserves exact Markdown and clean state")
        check(visual,"document.querySelectorAll('.visual-math[role=button]').length===11 && !document.querySelector('.visual-math button')", "formula surfaces are accessible click targets without Edit controls")
        visual.stopLoading()
        render("MVMATH0X MVCODE0X MVMATH999X MVCODE999X and $x$ and `safe`")
        check(webView, "document.getElementById('content').textContent.includes('MVMATH0X MVCODE0X MVMATH999X MVCODE999X')", "literal internal-looking placeholders remain unchanged")
        render("**bold** and `code` and $x$\n\n$$y$$")
        check(webView, "!!document.querySelector('.katex-display') && document.querySelectorAll('.katex').length === 2 && !document.querySelector('script[src],link[href]')", "bundled math renders inline/display without external resources")
        _ = js(webView, "window.savedMathRuntime=window.katex; delete window.katex;window._mvStale=true;return true;")
        render("**bold** and `code` and $x$\n\n$$y$$")
        check(webView, "document.querySelector('strong').textContent === 'bold' && document.querySelector('code').textContent === 'code' && document.getElementById('content').textContent.includes('$x$') && document.getElementById('content').textContent.includes('$$y$$')", "Markdown and offline inline/display math survive sanitizing")
        _ = js(webView, "window.katex=window.savedMathRuntime;delete window.savedMathRuntime;return true;")
        // A KaTeX-shaped fixture checks the sanitizer's MathML/SVG/style compatibility.
        let mathHTML = "<span class=\"katex\"><span class=\"katex-mathml\"><math><semantics><mi>x</mi><annotation encoding=\"application/x-tex\">x</annotation></semantics></math></span><span class=\"katex-html\" style=\"height:1em\">x<svg><path d=\"M0 0\"></path></svg></span></span>"
        _ = js(webView, "document.getElementById('content').innerHTML = _mvSanitize(html); return true;", arguments: ["html": mathHTML])
        check(webView, "!!document.querySelector('.katex annotation') && !!document.querySelector('.katex svg path')", "sanitizer preserves math markup")

        let attack = #"<img src="missing" onerror="window.webkit.messageHandlers.commitEdit.postMessage(btoa('changed'))"><svg onload="window._mvPwned=1"></svg><a href="javascript:window._mvPwned=2">bad</a><iframe srcdoc="<script>parent._mvPwned=3</script>"></iframe><base href="https://example.invalid/"><meta http-equiv="refresh" content="0;url=https://example.invalid"><form><textarea id="mv-block-editor">fake</textarea></form><div class="mv-block mv-hl" id="toc" data-start="0">fake</div>"#
        render(attack)
        _ = js(webView, "await new Promise(r => setTimeout(r, 100)); return true;")
        check(webView, "!document.querySelector('#content [onerror], #content [onload], #content iframe, #content base, #content meta, #content form, #content textarea, #content [data-start]:not(.mv-block):not(#mv-append-zone), #content #toc') && !document.querySelector('#content a').hasAttribute('href') && !window._mvPwned", "untrusted HTML loses executable attributes, dangerous URLs and editor impersonation")
        check(webView, "document.querySelectorAll('#content .mv-block').length === 1", "user HTML cannot create editor blocks")
        wait("bridge callbacks drain", until: { !webView.isLoading })
        precondition(commits.isEmpty, "Untrusted HTML must not commit edits")
        print("PASS: malicious HTML cannot send an edit through the native bridge")

        render("![x\" onerror=\"window._mvPwned=4](file:///tmp/picture.png){width=30,height=40,align=center}")
        check(webView, "document.querySelector('#content img').getAttribute('src') === 'file:///tmp/picture.png' && !document.querySelector('#content img').hasAttribute('onerror') && document.querySelector('#content img').style.width === '30px'", "custom image attributes are escaped and local image URLs survive")
        render("![x](images/picture.png)")
        check(webView, "document.querySelector('#content img').getAttribute('src') === 'images/picture.png'", "relative local images survive sanitizing")

        let pixel = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=")!
        try pixel.write(to: directory.appendingPathComponent("pixel.png"))
        render("![pixel](pixel.png)")
        let imageLoaded = js(webView, """
            const image = document.querySelector('#content img');
            try { await image.decode(); return image.naturalWidth === 1; }
            catch (_) { return false; }
            """) as? Bool
        precondition(imageLoaded == true, "Local image must load from an owned preview origin")
        print("PASS: relative local image actually loads from the unique preview file")

        // CSP must also block an event attribute and non-nonced script deliberately
        // inserted outside the sanitizer by this trusted test driver.
        _ = js(webView, """
            const img = document.createElement('img');
            img.setAttribute('onerror', 'window._mvCSPFailed = true');
            img.src = 'missing-csp-test'; document.body.appendChild(img);
            const s = document.createElement('script');
            s.textContent = 'window._mvCSPFailed = true'; document.body.appendChild(s);
            await new Promise(r => setTimeout(r, 100));
            return true;
            """)
        check(webView, "!window._mvCSPFailed", "CSP independently blocks event handlers and untrusted inline scripts")
        _ = js(webView, "location.href = 'https://example.invalid/'; await new Promise(r => setTimeout(r, 100)); return true;")
        precondition(webView.url == page, "Navigation must not replace the bridge-owning page")
        print("PASS: remote page navigation is blocked")

        // Verify native bridge integration for a legitimate commit as well.
        _ = js(webView, "window.webkit.messageHandlers.commitEdit.postMessage(btoa('legitimate')); await new Promise(r => setTimeout(r, 100)); return true;")
        wait("legitimate commit", until: { commits == ["legitimate"] })
        print("PASS: authorized preview can still commit through the native bridge")

        let inlineCoordinator = MarkdownWebView.Coordinator()
        let inlineConfig = WKWebViewConfiguration()
        for name in ["closeTOC", "scrollPosition", "commitEdit", "editorDirty", "openExternal"] {
            inlineConfig.userContentController.add(inlineCoordinator, name: name)
        }
        let inlineView = WKWebView(frame: .zero, configuration: inlineConfig)
        inlineView.navigationDelegate = inlineCoordinator
        inlineCoordinator.loadInitialPage(html, in: inlineView, previewURL: nil, baseURL: nil)
        wait("inline page load", until: { inlineCoordinator.isPageLoaded })
        check(inlineView, "!!document.querySelector('h1')", "new-document inline HTML load works with navigation policy")
        var inlineCommit = false
        inlineCoordinator.onTextCommit = { inlineCommit = $0 == "new document" }
        _ = js(inlineView, "window.webkit.messageHandlers.commitEdit.postMessage(btoa('new document')); await new Promise(r => setTimeout(r, 100)); return true;")
        wait("inline commit", until: { inlineCommit })
        print("PASS: new-document inline page retains native bridge access")
        let emptySwitch = js(inlineView, """
            window._mvRender('');
            try {
                const result = await window._mvSwitchEditor(true, '');
                return {ok: result.text === '' && !!window._bloctVisual};
            } catch (error) { return {ok:false,error:String(error),stack:error.stack}; }
            """) as! [String: Any]
        print("Empty document Aa: \(emptySwitch)")
        precondition(emptySwitch["ok"] as? Bool == true, "Empty document Aa failed")
        _ = js(inlineView, "await window._mvSwitchEditor(false, ''); return true;")
        let layoutSuite = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
        var layoutFailures = 0
        for width in [900, 640] {
            webView.frame.size.width = CGFloat(width)
            for toc in [false, true] {
                let report = js(webView, layoutSuite, arguments: ["toc": toc]) as! String
                let data = try JSONSerialization.jsonObject(with: Data(report.utf8)) as! [String: Any]
                for result in data["results"] as! [[String: Any]] {
                    let pass = result["pass"] as? Bool == true
                    print("\(pass ? "PASS" : "FAIL") [layout \(width), TOC \(toc)]: \(result["name"]!)")
                    if !pass { layoutFailures += 1; print(result["detail"] ?? "") }
                }
            }
        }
        precondition(layoutFailures == 0, "Editor-switch layout failures: \(layoutFailures)")

        let appearanceSuite = try String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)
        var appearanceFailures = 0
        for width in [900, 640] {
            webView.frame.size.width = CGFloat(width)
            for dark in [false, true] {
                webView.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                for zoom in [1.0, 1.25] {
                    webView.pageZoom = zoom
                    for toc in [false, true] {
                        let report = js(webView, appearanceSuite, arguments: ["toc":toc,"dark":dark]) as! String
                        let data = try JSONSerialization.jsonObject(with: Data(report.utf8)) as! [String: Any]
                        for result in data["results"] as! [[String: Any]] {
                            let pass = result["pass"] as? Bool == true
                            print("\(pass ? "PASS" : "FAIL") [appearance \(width), dark \(dark), zoom \(zoom), TOC \(toc)]: \(result["name"]!)")
                            if !pass { appearanceFailures += 1; print(result["detail"] ?? "") }
                        }
                    }
                }
            }
        }
        if let output = ProcessInfo.processInfo.environment["BLOCT_APPEARANCE_SNAPSHOTS"] {
            webView.appearance = NSAppearance(named: .aqua)
            webView.pageZoom = 1
            webView.frame.size.width = 900
            let sample="Paragraph **bold** *italic* `code` [link](https://example.invalid) and  multiple   spaces.\nsoft line\\\nhard line"
            render(sample)
            _ = js(webView,"document.body.style.paddingLeft=''; document.getElementById('toc').style.transform='translateX(-220px)'; window.scrollTo(0,0); return true;")
            for visual in [false,true] {
                if visual { _ = js(webView,"await window._mvSwitchEditor(true, source); window.scrollTo(0,0); return true;",arguments:["source":sample]) }
                let rect = js(webView,"const r=document.querySelector('#content p').getBoundingClientRect(); return [r.x,r.y,r.width,r.height];") as! [Double]
                let config=WKSnapshotConfiguration()
                config.rect=NSRect(x:rect[0],y:rect[1],width:rect[2],height:rect[3])
                config.afterScreenUpdates=false
                var complete=false
                webView.takeSnapshot(with:config) { image,error in
                    precondition(error == nil, "Snapshot failed: \(String(describing:error))")
                    let png=NSBitmapImageRep(data:image!.tiffRepresentation!)!.representation(using:.png,properties:[:])!
                    try! png.write(to:URL(fileURLWithPath:output+"-\(visual ? "after" : "before").png"))
                    complete=true
                }
                wait("appearance snapshot",until:{complete})
            }
            _ = js(webView,"await window._mvSwitchEditor(false, source); return true;",arguments:["source":sample])
        }
        precondition(appearanceFailures == 0, "Editor appearance failures: \(appearanceFailures)")

    }
}
