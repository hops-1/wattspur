import Foundation
import SQLite3

/// A backup of the whole library as a folder, and the way back (P-22).
///
/// The library is one SQLite file plus a folder of larger blobs next to it (SwiftData's
/// `.default_SUPPORT`). A backup copies both: the file through SQLite's own backup call, so it is
/// consistent while the app runs, the folder as it is.
///
/// A restore cannot replace a store that is open. `stageRestore` copies the backup next to the library
/// and `applyPendingRestore` swaps it in at the next start, before the container opens; the library it
/// replaces is kept in a folder beside it, never deleted.
public enum LibraryBackup {
    /// The file `manifest.json` in a backup folder.
    public struct Manifest: Codable, Equatable, Sendable {
        public static let currentFormat = 1

        public var format: Int
        public var createdAt: Date
        public var appVersion: String
        public var build: String
        /// Rides in the library when the backup was made, for the confirmation before a restore.
        public var rideCount: Int?

        public init(format: Int = Manifest.currentFormat, createdAt: Date, appVersion: String, build: String, rideCount: Int?) {
            self.format = format
            self.createdAt = createdAt
            self.appVersion = appVersion
            self.build = build
            self.rideCount = rideCount
        }
    }

    public enum Failure: Error, Equatable {
        /// There is no library file yet (or the app runs on demo data).
        case noLibrary
        /// The folder is not a Wattspur backup.
        case notABackup
        /// The backup was made by a newer format than this version knows.
        case unsupportedFormat(Int)
        /// SQLite refused (code and message), e.g. a damaged file.
        case database(Int32, String)
    }

    static let manifestName = "manifest.json"
    static let pendingName = "Pending Restore"

    // MARK: Back up

    /// Writes a backup folder into `destination` and returns it.
    @discardableResult
    public static func create(
        storeURL: URL, in destination: URL, appVersion: String, build: String, rideCount: Int?, now: Date = .now
    ) throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { throw Failure.noLibrary }
        let folder = uniqueFolder(named: "Wattspur Backup \(timestamp(now))", in: destination)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
            try copyDatabase(from: storeURL, to: folder.appending(path: storeURL.lastPathComponent))
            let support = supportFolder(for: storeURL)
            if fm.fileExists(atPath: support.path) {
                try fm.copyItem(at: support, to: folder.appending(path: support.lastPathComponent))
            }
            let manifest = Manifest(createdAt: now, appVersion: appVersion, build: build, rideCount: rideCount)
            try encoder.encode(manifest).write(to: folder.appending(path: manifestName))
        } catch {
            try? fm.removeItem(at: folder) // no half backup
            throw error
        }
        return folder
    }

    /// Reads the manifest of a backup folder and checks that the library file is there and opens.
    public static func inspect(_ backup: URL, storeName: String) throws -> Manifest {
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: backup.appending(path: manifestName)),
              let manifest = try? decoder.decode(Manifest.self, from: data),
              fm.fileExists(atPath: backup.appending(path: storeName).path)
        else { throw Failure.notABackup }
        guard manifest.format <= Manifest.currentFormat else { throw Failure.unsupportedFormat(manifest.format) }
        try checkDatabase(at: backup.appending(path: storeName))
        return manifest
    }

    // MARK: Restore

    /// Copies the backup beside the library, to be swapped in at the next start.
    public static func stageRestore(from backup: URL, storeURL: URL) throws {
        _ = try inspect(backup, storeName: storeURL.lastPathComponent)
        let fm = FileManager.default
        let pending = pendingFolder(for: storeURL)
        try? fm.removeItem(at: pending)
        try fm.createDirectory(at: pending, withIntermediateDirectories: true)
        do {
            try fm.copyItem(at: backup.appending(path: storeURL.lastPathComponent), to: pending.appending(path: storeURL.lastPathComponent))
            let support = supportFolder(for: storeURL)
            let source = backup.appending(path: support.lastPathComponent)
            if fm.fileExists(atPath: source.path) {
                try fm.copyItem(at: source, to: pending.appending(path: support.lastPathComponent))
            }
        } catch {
            try? fm.removeItem(at: pending)
            throw error
        }
    }

    public static func hasPendingRestore(storeURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: pendingFolder(for: storeURL).appending(path: storeURL.lastPathComponent).path)
    }

    public static func cancelPendingRestore(storeURL: URL) {
        try? FileManager.default.removeItem(at: pendingFolder(for: storeURL))
    }

    /// Swaps a staged restore in. Call it before the container opens. Returns the folder that now holds
    /// the replaced library, or `nil` if nothing was staged. If anything fails, the library stays as it was.
    @discardableResult
    public static func applyPendingRestore(storeURL: URL, now: Date = .now) throws -> URL? {
        guard hasPendingRestore(storeURL: storeURL) else { return nil }
        let fm = FileManager.default
        let pending = pendingFolder(for: storeURL)
        let parent = storeURL.deletingLastPathComponent()
        let old = uniqueFolder(named: "Library Before Restore \(timestamp(now))", in: parent)
        try fm.createDirectory(at: old, withIntermediateDirectories: false)

        let names = libraryFileNames(for: storeURL)
        var moved: [String] = []
        do {
            for name in names where fm.fileExists(atPath: parent.appending(path: name).path) {
                try fm.moveItem(at: parent.appending(path: name), to: old.appending(path: name))
                moved.append(name)
            }
            for name in names where fm.fileExists(atPath: pending.appending(path: name).path) {
                try fm.moveItem(at: pending.appending(path: name), to: parent.appending(path: name))
            }
        } catch {
            // Put back what was moved away, drop what was moved in.
            for name in names {
                try? fm.removeItem(at: parent.appending(path: name))
            }
            for name in moved {
                try? fm.moveItem(at: old.appending(path: name), to: parent.appending(path: name))
            }
            try? fm.removeItem(at: old)
            throw error
        }
        try? fm.removeItem(at: pending)
        return old
    }

    // MARK: Files

    /// SwiftData keeps larger blobs (`externalStorage`) in `.<store>_SUPPORT` next to the file.
    static func supportFolder(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appending(path: ".\(storeURL.deletingPathExtension().lastPathComponent)_SUPPORT")
    }

    static func pendingFolder(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appending(path: pendingName)
    }

    /// The store, its journal files and the blob folder.
    private static func libraryFileNames(for storeURL: URL) -> [String] {
        let name = storeURL.lastPathComponent
        return [name, name + "-wal", name + "-shm", supportFolder(for: storeURL).lastPathComponent]
    }

    private static func uniqueFolder(named name: String, in parent: URL) -> URL {
        var url = parent.appending(path: name)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = parent.appending(path: "\(name) \(n)")
            n += 1
        }
        return url
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return formatter.string(from: date)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: SQLite

    /// Copies a database that may be open elsewhere, including what still sits in its journal.
    private static func copyDatabase(from source: URL, to destination: URL) throws {
        var from: OpaquePointer?
        var to: OpaquePointer?
        defer {
            sqlite3_close(from)
            sqlite3_close(to)
        }
        guard sqlite3_open_v2(source.path, &from, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { throw failure(from) }
        guard sqlite3_open_v2(destination.path, &to, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else { throw failure(to) }
        guard let backup = sqlite3_backup_init(to, "main", from, "main") else { throw failure(to) }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else { throw failure(to) }
        // The copy is a single file, so it opens without journal files beside it (it is read in place, e.g. from a disk that is read-only).
        guard sqlite3_exec(to, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else { throw failure(to) }
    }

    /// Opens the file read-only, without touching the folder, and runs SQLite's quick check.
    private static func checkDatabase(at url: URL) throws {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        let uri = url.absoluteString + "?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else { throw failure(db) }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK else { throw failure(db) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0),
              String(cString: text) == "ok"
        else { throw Failure.notABackup }
    }

    private static func failure(_ db: OpaquePointer?) -> Failure {
        .database(sqlite3_errcode(db), db.map { String(cString: sqlite3_errmsg($0)) } ?? "")
    }
}
