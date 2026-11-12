import AppKit
import WebKit

// Executes the browser bundle only. This is not a visual editor/IME test and
// deliberately does not launch or modify the user's Bloct installation.
@main
struct BlockModelWebKit {
    @MainActor static func wait(_ label: String, until predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(25)
        while !predicate() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(predicate(), "Timed out: \(label)")
    }

    @MainActor static func evaluate(_ view: WKWebView, _ source: String) -> Any? {
        var complete = false
        var output: Any?
        var failure: Error?
        view.callAsyncJavaScript(source, arguments: [:], in: nil, in: .page) { result in
            switch result {
            case .success(let value): output = value
            case .failure(let error): failure = error
            }
            complete = true
        }
        wait("JavaScript", until: { complete })
        precondition(failure == nil, "JavaScript: \(String(describing: failure))")
        return output
    }

    @MainActor static func main() throws {
        setbuf(stdout, nil)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 700, height: 600), configuration: config)
        var visualCount = 0
        for mode in ["file", "inline"] {
            let html = try String(contentsOf: directory.appendingPathComponent("index.html"), encoding: .utf8)
            if mode == "file" {
                webView.loadFileURL(directory.appendingPathComponent("index.html"), allowingReadAccessTo: directory)
            } else {
                // The app's new/read-only document boot path uses inline HTML.
                let bundle = try String(contentsOf: directory.appendingPathComponent("blocks.js"), encoding: .utf8)
                let embedded = html.replacingOccurrences(of: #"src="blocks.js">"#,
                    with: ">" + bundle.replacingOccurrences(of: "</script", with: "<\\/script"))
                webView.loadHTMLString(embedded, baseURL: nil)
            }
            wait("\(mode) page", until: { !webView.isLoading })
            let result = evaluate(webView, #"""
                const {BlockSession, importMarkdown} = BloctBlocks;
                const s = new BlockSession('\uFEFF# 한글😀\r\n\r\n- [ ] same\r\n- [X] same\r\n');
                const checks = [];
                const check = (name, value) => { if (!value) throw new Error(name); checks.push(name); };
                check('semantic import and BOM', s.doc.firstChild.type.name === 'heading' && s.doc.attrs.bom === '\uFEFF');
                let item;
                s.doc.descendants(n => {if (n.type.name === 'list_item' && n.attrs.checked === false) item = n;});
                const before = s.markdown(), id = item.attrs.id, reference = s.reference(id);
                check('reject forged target', !s.execute({...reference}, {type:'setChecked', checked:true}));
                check('task transaction', s.execute(reference, {type:'setChecked', checked:true}));
                const after = s.markdown();
                check('one source character', before.length === after.length && [...before].filter((c,i) => c !== [...after][i]).length === 1);
                check('undo exact source', s.undo() && s.markdown() === before && !s.dirty);
                check('redo', s.redo() && s.markdown() === after);
                check('stale target rejected', !s.execute(reference, {type:'setChecked', checked:false}));
                const empty = new BlockSession('');
                check('empty H2 conversion', empty.execute(empty.reference(empty.doc.firstChild.attrs.id), {type:'setType',kind:'heading',level:2}) && empty.markdown() === '## ');
                check('empty heading reimport', importMarkdown(empty.markdown()).doc.firstChild.type.name === 'heading');
                return checks;
                """#) as? [String]
            precondition(result?.count == 9)
            for name in result! { print("PASS [\(mode)]: \(name)") }
            if CommandLine.arguments.count > 2 {
                let suite = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
                let css = try String(contentsOf: directory.appendingPathComponent("visual.css"), encoding: .utf8)
                let cssJSON = String(data: try JSONSerialization.data(withJSONObject: [css]), encoding: .utf8)!
                _ = evaluate(webView, "const style=document.createElement('style');style.textContent=\(cssJSON)[0];document.head.append(style);return true;")
                let output = evaluate(webView, suite) as! String
                let data = try JSONSerialization.jsonObject(with: Data(output.utf8)) as! [String: Any]
                let results = data["results"] as! [[String: Any]]
                var failed = 0
                for check in results {
                    let pass = check["pass"] as? Bool == true
                    print("\(pass ? "PASS" : "FAIL") [\(mode)]: \(check["name"]!) \(check["detail"] ?? "")")
                    if !pass { failed += 1 }
                }
                visualCount += results.count
                precondition(failed == 0, "\(failed) visual checks failed")
            }
        }
        webView.stopLoading()
        print("18 passed, 0 failed; browser bundle only, no visual/IME/native-save coverage")
        if visualCount > 0 { print("\(visualCount) visual DOM/input simulation checks passed; real IME/native Save separate") }
    }
}
