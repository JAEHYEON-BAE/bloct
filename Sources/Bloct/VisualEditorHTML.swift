import Foundation

extension MarkdownWebView {
    private func editorResource(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
    func visualEditorStyles() -> String { editorResource("visual", "css") }
    func visualEditorBundle() -> String {
        editorResource("blocks", "js").replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
    }
    func visualEditorBootstrap() -> String {
        let baseline = Data((savedMarkdown ?? markdown).utf8).base64EncodedString()
        return editorResource("editor-switch", "js") + """
        \nwindow._mvInstallEditorSwitch?.({
            generation: \(reloadGeneration), visual: \(visualEditing ? "true" : "false"), automatic: \(automaticEditing ? "true" : "false"),
            baseline: new TextDecoder().decode(Uint8Array.from(atob('\(baseline)'), c => c.charCodeAt(0)))
        });
        """
    }
}
