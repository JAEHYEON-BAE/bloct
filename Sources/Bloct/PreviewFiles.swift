import Foundation

@MainActor
enum PreviewFiles {
    private static var owned: Set<URL> = []

    static func create(html: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(".mv_preview-\(UUID().uuidString).html")
        // Exclusive creation: never overwrite an existing file, even on collision.
        try Data(html.utf8).write(to: url, options: .withoutOverwriting)
        owned.insert(url)
        return url
    }

    static func remove(_ url: URL) {
        guard owned.contains(url) else { return }
        do {
            try FileManager.default.removeItem(at: url)
            owned.remove(url)
        } catch {
            // Keep ownership so application termination can retry cleanup.
        }
    }

    static func removeAll() {
        for url in Array(owned) { remove(url) }
    }
}
