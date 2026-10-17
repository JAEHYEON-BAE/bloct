import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

// Copies of a FileDocument share the cancellation token, including snapshots
// retained by SwiftUI for an implicit save while the window is closing.
final class DocumentWriteProtection: @unchecked Sendable {
    private let lock = NSLock()
    private var discarded = false
    private var sourceURL: URL?
    func trackSource(_ url: URL?) {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        lock.lock(); sourceURL = url; lock.unlock()
    }
    func discard() { lock.lock(); discarded = true; lock.unlock() }
    func validate(text: String? = nil) throws {
        lock.lock()
        let cancelled = discarded
        let url = sourceURL
        lock.unlock()
        if cancelled { throw CocoaError(.userCancelled) }
        // Implicit FileDocument writes may only echo the current source. Existing
        // document edits are saved explicitly by DocumentDisk's coordinated write.
        if let url, let text {
            guard let data = try? Data(contentsOf: url), data == Data(text.utf8) else {
                throw CocoaError(.userCancelled)
            }
        }
    }
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    var text: String
    let writeProtection = DocumentWriteProtection()

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try writeProtection.validate(text: text)
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
