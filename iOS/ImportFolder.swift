import Foundation
import Observation

/// The folder “Wattspur Import” in iCloud Drive, shared with the Mac (V-14, later B-209/B-212).
///
/// The user picks it once in the Files dialog; a bookmark keeps the access across launches, so
/// the app needs no iCloud entitlement (which the free Personal Team does not offer). Reads and
/// writes go through `NSFileCoordinator`, so iCloud never syncs a half-written file and a file
/// that is not downloaded yet is fetched first.
@MainActor @Observable
final class ImportFolder {
    nonisolated enum FolderError: LocalizedError {
        case noFolder
        case noAccess

        var errorDescription: String? {
            switch self {
            case .noFolder: String(localized: "No folder chosen.")
            case .noAccess: String(localized: "The folder can no longer be opened. Choose it again.")
            }
        }
    }

    private static let bookmarkKey = "importFolderBookmark"

    /// The chosen folder, or `nil` before the first choice.
    private(set) var url: URL?
    /// What went wrong when the bookmark was last saved or resolved.
    private(set) var problem: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restore()
    }

    /// Remembers a folder picked with `fileImporter`.
    func use(_ picked: URL) {
        let accessing = picked.startAccessingSecurityScopedResource()
        defer { if accessing { picked.stopAccessingSecurityScopedResource() } }
        do {
            defaults.set(try picked.bookmarkData(), forKey: Self.bookmarkKey)
            url = picked
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }

    func forget() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        url = nil
        problem = nil
    }

    /// Resolves the saved bookmark; a stale one (folder moved or renamed) is saved again.
    func restore() {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        do {
            let resolved = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            url = resolved
            problem = nil
            if stale { use(resolved) }
        } catch {
            url = nil
            problem = error.localizedDescription
        }
    }

    /// Runs `body` while the app may access the folder.
    func withAccess<T>(_ body: (URL) throws -> T) throws -> T {
        guard let url else { throw FolderError.noFolder }
        guard url.startAccessingSecurityScopedResource() else { throw FolderError.noAccess }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body(url)
    }

    /// Writes a file at a path inside the folder (e.g. “iPhone/Test/a.txt”), creating subfolders.
    @discardableResult
    func write(_ data: Data, to relativePath: String) throws -> URL {
        try withAccess { folder in
            let target = folder.appending(path: relativePath)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            var coordinatorError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing,
                                           error: &coordinatorError) { url in
                do { try data.write(to: url, options: .atomic) } catch { writeError = error }
            }
            if let error = coordinatorError ?? writeError { throw error }
            return target
        }
    }

    /// Reads a file inside the folder; iCloud downloads it first if it is only a placeholder.
    func read(_ relativePath: String) throws -> Data {
        guard let url else { throw FolderError.noFolder }
        return try Self.coordinatedRead(relativePath, in: url)
    }

    /// The same off the main thread: a file iCloud still has to download can take a while.
    func readInBackground(_ relativePath: String) async throws -> Data {
        guard let url else { throw FolderError.noFolder }
        return try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedRead(relativePath, in: url)
        }.value
    }

    nonisolated private static func coordinatedRead(_ relativePath: String, in folder: URL) throws -> Data {
        guard folder.startAccessingSecurityScopedResource() else { throw FolderError.noAccess }
        defer { folder.stopAccessingSecurityScopedResource() }
        let target = folder.appending(path: relativePath)
        try? FileManager.default.startDownloadingUbiquitousItem(at: target)
        var coordinatorError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: target, options: [], error: &coordinatorError) { url in
            result = Result { try Data(contentsOf: url) }
        }
        if let coordinatorError { throw coordinatorError }
        return try result.get()
    }

    /// The names directly in the folder or a subfolder, placeholders (“.Ride.fit.icloud”) included.
    func contents(of relativePath: String = "") throws -> [String] {
        try withAccess { folder in
            let directory = relativePath.isEmpty ? folder : folder.appending(path: relativePath)
            return try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        }
    }
}
