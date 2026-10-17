import Foundation

// Compare bytes, not timestamps: atomic replacement and same-time writes both count.
// Coordination keeps the final comparison and write in the same accessor. Writers
// that ignore NSFileCoordinator can still race an atomic write (as with NSDocument).
enum DocumentDisk {
    enum Conflict: LocalizedError {
        case changed
        var errorDescription: String? { "The file changed on disk. Reload it or save your edits as a copy." }
    }

    static func readAsync(_ url: URL) async throws -> String {
        try await Task.detached(priority: .utility) { try read(url) }.value
    }

    static func saveAsync(_ text: String, to url: URL, replacing expected: String) async throws {
        try await Task.detached(priority: .userInitiated) { try save(text, to: url, replacing: expected) }.value
    }

    static func read(_ url: URL) throws -> String {
        var coordinationError: NSError?
        var result: Result<String, Error> = .failure(CocoaError(.fileReadUnknown))
        // Inspect the source without asking presenters to autosave first.
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { location in
            result = Result { try String(contentsOf: location, encoding: .utf8) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    static func save(_ text: String, to url: URL, replacing expected: String) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .failure(CocoaError(.fileWriteUnknown))
        // Updating contents uses no replacing/deleting option, even for an atomic
        // write. .forReplacing tells NSDocument its file is being deleted.
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { location in
            result = Result {
                // Missing/unreadable files must never be recreated over an unknown version.
                guard try Data(contentsOf: location) == Data(expected.utf8) else { throw Conflict.changed }
                try Data(text.utf8).write(to: location, options: .atomic)
            }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }

}
