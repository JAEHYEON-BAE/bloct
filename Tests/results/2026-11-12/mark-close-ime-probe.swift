// One-off probe for BUG_FIXES.md #52. Types into the mounted editor through the
// WKWebView text input client, as the Korean IME does: "i:" insertText,
// "m:" setMarkedText, "c:" doCommand, "j:" page script.
// Usage: probe <folder with index.html, blocks.js, math.js, visual.css> <scenarios.json>
import AppKit
import WebKit

@main
struct Probe {
    @MainActor static func spin(_ s: Double) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }
    @MainActor static func js(_ view: WKWebView, _ source: String) -> Any? {
        var done = false; var out: Any?
        view.callAsyncJavaScript(source, arguments: [:], in: nil, in: .page) { r in
            if case .success(let v) = r { out = v } else if case .failure(let e) = r { out = "ERR \(e)" }
            done = true
        }
        let deadline = Date().addingTimeInterval(10)
        while !done && Date() < deadline { spin(0.01) }
        return out
    }
    @MainActor static func main() throws {
        setbuf(stdout, nil)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let dir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 700, height: 600), configuration: WKWebViewConfiguration())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = web
        window.makeFirstResponder(web)
        let client = web as AnyObject as! NSTextInputClient
        let none = NSRange(location: NSNotFound, length: 0)
        // Scenario steps: "i:text" insertText, "m:text" setMarkedText.
        let scenarios: [(String, String, [String])] = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as! [[Any]] |> { $0.map { ($0[0] as! String, $0[1] as! String, $0[2] as! [String]) } }
        for (name, source, steps) in scenarios {
            web.loadFileURL(dir.appendingPathComponent("index.html"), allowingReadAccessTo: dir)
            spin(0.3); while web.isLoading { spin(0.05) }
            _ = js(web, """
                const host=document.getElementById('host');
                window.e=BloctBlocks.mountVisualEditor(host,\(String(data: try JSONSerialization.data(withJSONObject: [source]), encoding: .utf8)!)[0],{trailingParagraph:false});
                e.focus();const v=e.view,end=v.state.doc.content.size-1;
                v.dispatch(v.state.tr.setSelection(v.state.selection.constructor.near(v.state.doc.resolve(end),-1)));
                window.log=[];
                for(const t of ['compositionstart','compositionupdate','compositionend','beforeinput'])v.dom.addEventListener(t,ev=>log.push(t+':'+(ev.data??'')+(ev.inputType?'/'+ev.inputType:'')),true);
                return true;
                """)
            spin(0.2)
            for step in steps {
                let text = String(step.dropFirst(2))
                if step.hasPrefix("i:") { client.insertText(text, replacementRange: none) }
                else if step.hasPrefix("c:") { client.doCommand(by: Selector(text)) }
                else if step.hasPrefix("j:") { _ = js(web, text) }
                else { client.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0), replacementRange: none) }
                spin(0.12)
            }
            spin(0.3)
            let out = js(web, """
                const nodes=[];e.session.doc.lastChild.forEach(n=>nodes.push((n.text||n.type.name)+'['+n.marks.map(m=>m.type.name).join(',')+']'));
                let md;try{md=e.session.markdown();}catch(x){md='ERR '+x;}
                return JSON.stringify({focus:e.view.hasFocus(),nodes,md,html:e.view.dom.lastElementChild.innerHTML,title:document.title,log:''});
                """)
            print("\(name): \(out ?? "nil")")
        }
        exit(0)
    }
}
infix operator |>: AdditionPrecedence
func |> <A, B>(a: A, f: (A) -> B) -> B { f(a) }
