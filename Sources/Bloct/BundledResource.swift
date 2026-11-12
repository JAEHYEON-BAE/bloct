import Foundation

/// Text resources bundled with the app, read once and kept for the process.
/// A missing file reads as "" so the page can still render without it.
enum BundledResource {
    nonisolated(unsafe) private static var cache: [String: String] = [:]
    private static let lock = NSLock()

    static func text(_ name: String, _ ext: String) -> String {
        let key = name + "." + ext
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let text = Bundle.main.url(forResource: name, withExtension: ext)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        cache[key] = text
        return text
    }
}
