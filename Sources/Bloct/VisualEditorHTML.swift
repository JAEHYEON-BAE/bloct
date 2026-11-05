import Foundation

extension MarkdownWebView {
    func buildVisualHTML(imageOrigin: String) -> String {
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        func resource(_ name: String, _ ext: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
            return text
        }
        let script = resource("blocks", "js").replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
        let css = resource("visual", "css")
        let base64 = Data(markdown.utf8).base64EncodedString()
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)'; style-src 'unsafe-inline'; img-src bloct-image: https: http: data:; font-src data:; connect-src 'none'; base-uri 'none'; form-action 'none'">
        <style>\(css)</style><script nonce="\(nonce)">\(script)</script></head>
        <body><main id="visual-shell"><div id="content"></div></main>
        <script nonce="\(nonce)">
        (() => {
            const decode = value => new TextDecoder().decode(Uint8Array.from(atob(value), c => c.charCodeAt(0)));
            const post = (name, value) => window.webkit?.messageHandlers[name]?.postMessage(value);
            window._mvGeneration = \(reloadGeneration);
            window._mvImageOrigin = '\(imageOrigin)';
            let generation = window._mvGeneration;
            if (typeof BloctBlocks === 'undefined') {
                document.getElementById('content').textContent = 'Visual editor resources are unavailable. Rebuild the app with Editor dependencies installed.';
                return;
            }
            const imageURL = source => {
                if (/^data:image\\/(?:png|jpeg|gif|webp);base64,/i.test(source)) return source;
                try {
                    const url = new URL(source);
                    if (['https:', 'http:'].includes(url.protocol)) return url.href;
                    if (url.protocol !== 'file:') return null;
                } catch (_) {}
                return source && window._mvImageOrigin ? window._mvImageOrigin + '?src=' + encodeURIComponent(source) : null;
            };
            const editor = BloctBlocks.mountVisualEditor(document.getElementById('content'), decode('\(base64)'), {
                imageURL,
                onChange: dirty => post('editorDirty', {dirty, generation: window._mvGeneration})
            });
            window._bloctVisual = editor;
            editor.setEditable(\(isEditMode ? "true" : "false"));
            window._mvRender = value => {
                const text = decode(value);
                if (generation !== window._mvGeneration) {
                    generation = window._mvGeneration;
                    editor.reload(text);
                } else if (!editor.session.changed && text !== editor.session.markdown()) {
                    editor.reload(text);
                }
                document.querySelectorAll('img[data-source]').forEach(img => {
                    const url = imageURL(img.dataset.source); if (url && img.src !== url) img.src = url;
                });
            };
            window._mvSetEditMode = on => editor.setEditable(on);
            window._mvSearch = {
                highlight: term => editor.search(term), clear: () => editor.search(''),
                navigate: forward => editor.navigate(forward)
            };
        })();
        </script></body></html>
        """
    }
}
