import Foundation

/// Builds the document page from page.html and the bundled scripts and styles.
/// All markup and page code live in those resource files; Swift supplies only
/// the CSP nonce and a JSON configuration object.
enum PageTemplate {
    /// Values the page reads from its `mv-page-config` JSON block.
    struct Config: Encodable {
        struct Editor: Encodable {
            let generation: Int
            let visual: Bool
            let automatic: Bool
            let baseline: String
        }
        /// Base64 UTF-8 document text, as `window._mvRender` takes it.
        let markdown: String
        let imageOrigin: String
        let editor: Editor
    }

    static func html(config: Config, nonce: String = UUID().uuidString) -> String {
        let editorStyles = BundledResource.text("visual", "css")
        let values: [String: String] = [
            "nonce": nonce,
            "styles": BundledResource.text("style", "css"),
            "editor-styles": editorStyles.isEmpty ? BundledResource.text("math", "css") : editorStyles,
            "editor-bundle": script(BundledResource.text("blocks", "js")),
            "purify": script(BundledResource.text("purify.min", "js")),
            "marked": script(BundledResource.text("marked.min", "js")),
            "math": script(BundledResource.text("math", "js")),
            "config": json(config),
            // Editor/src/host/*.js joined in order by Editor/build-resources.mjs.
            "page-script": script(BundledResource.text("host", "js")),
        ]
        return fill(BundledResource.text("page", "html"), with: values)
    }

    /// Replaces each `{{name}}` of the template in one pass, so inserted text is
    /// never searched for placeholders. Unknown names are left as they are.
    static func fill(_ template: String, with values: [String: String]) -> String {
        var output = ""
        var rest = template[...]
        while let open = rest.range(of: "{{") {
            output += rest[..<open.lowerBound]
            guard let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) else {
                rest = rest[open.lowerBound...]
                break
            }
            let name = String(rest[open.upperBound..<close.lowerBound])
            output += values[name] ?? String(rest[open.lowerBound..<close.upperBound])
            rest = rest[close.upperBound...]
        }
        return output + rest
    }

    /// Inline script text cannot contain a closing script tag.
    private static func script(_ text: String) -> String {
        text.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
    }

    /// JSON inside a script element: `<` is escaped so no text can end the element.
    private static func json(_ config: Config) -> String {
        let data = (try? JSONEncoder().encode(config)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "<", with: "\\u003c")
    }
}
