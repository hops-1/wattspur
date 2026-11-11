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
        /// Made by the automatic backup on the iPhone (B-302), which only ever deletes its own backups.
        /// Absent in other backups; older versions ignore it, so the format stays 1.
        public var automatic: Bool?

        public init(format: Int = Manifest.currentFormat, createdAt: Date, appVersion: String, build: String, rideCount: Int?,
                    automatic: Bool? = nil) {
            self.format = format
            self.createdAt = createdAt
            self.appVersion = appVersion
            self.build = build
            self.rideCount = rideCount
            self.automatic = automatic
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
        /// Writing the backup into the library failed (B-265). `kept` holds the library as it was before;
        /// `putBack` says whether it is in place again. The staged backup is dropped.
        case restoreFailed(kept: URL, putBack: Bool, detail: String)
        /// Files of the backup are still in iCloud Drive, not on this device (B-302): `missing` of them. Their
        /// download has been started; the restore can be tried again in a moment.
        case notDownloaded(missing: Int)
        /// The library file refers to ride data that is not in the backup's blob folder: `missing` files. Such a
        /// backup is never written into the library, it would leave rides without their data (11.11.2026).
        case incomplete(missing: Int)
    }

    static let manifestName = "manifest.json"
    static let pendingName = "Pending Restore"

    // MARK: Back up

    /// Writes a backup folder into `destination` and returns it. `automatic` marks a backup of the iPhone's
    /// automatic backup (B-302), so `Automatic.prune` may delete it later.
    @discardableResult
    public static func create(
        storeURL: URL, in destination: URL, appVersion: String, build: String, rideCount: Int?, automatic: Bool = false,
        now: Date = .now
    ) throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { throw Failure.noLibrary }
        let folder = uniqueFolder(named: "Wattspur Backup \(timestamp(now))", in: destination)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
            let copy = folder.appending(path: storeURL.lastPathComponent)
            try copyDatabase(from: storeURL, to: copy)
            try copySupport(of: copy, from: supportFolder(for: storeURL), to: supportFolder(for: copy))
            let manifest = Manifest(createdAt: now, appVersion: appVersion, build: build, rideCount: rideCount,
                                    automatic: automatic ? true : nil)
            try encoder.encode(manifest).write(to: folder.appending(path: manifestName))
        } catch {
            try? fm.removeItem(at: folder) // no half backup
            throw error
        }
        return folder
    }

    /// Copies the library at `storeURL` (file and blob folder) to `destination`, a store URL in another
    /// folder that must not hold a library yet. For the test library of a debug build (V-15).
    public static func copyLibrary(from storeURL: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { throw Failure.noLibrary }
        let folder = destination.deletingLastPathComponent()
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try copyDatabase(from: storeURL, to: destination)
            let support = supportFolder(for: storeURL)
            if fm.fileExists(atPath: support.path) {
                try fm.copyItem(at: support, to: supportFolder(for: destination))
            }
        } catch {
            for name in libraryFileNames(for: destination) {
                try? fm.removeItem(at: folder.appending(path: name))
            }
            throw error
        }
    }

    /// Reads the manifest of a backup folder and checks that the library file is there and opens.
    public static func inspect(_ backup: URL, storeName: String) throws -> Manifest {
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: backup.appending(path: manifestName)),
              let manifest = try? decoder.decode(Manifest.self, from: data),
              fm.fileExists(atPath: backup.appending(path: storeName).path)
        else { throw Failure.notABackup }
        guard manifest.format <= Manifest.currentFormat else { throw Failure.unsupportedFormat(manifest.format) }
        let store = backup.appending(path: storeName)
        if isNotDownloaded(store) {
            startDownloading([store])
            throw Failure.notDownloaded(missing: 1)
        }
        try checkDatabase(at: store)
        try checkExternalData(storeURL: store)
        return manifest
    }

    /// Throws unless every blob the library file refers to is there and, in iCloud Drive, downloaded. Starts the
    /// download of the files that are only in iCloud. On 11.11.2026 a backup made on the iPhone was restored on the
    /// Mac while 189 of its 332 blobs were still in iCloud: the copy waited, and the rides of the missing blobs lost
    /// their data.
    static func checkExternalData(storeURL: URL) throws {
        let folder = supportFolder(for: storeURL).appending(path: "_EXTERNAL_DATA")
        let fm = FileManager.default
        var absent = 0
        var inCloud: [URL] = []
        for name in try externalDataNames(storeURL: storeURL) {
            let file = folder.appending(path: name)
            if !fm.fileExists(atPath: file.path) {
                absent += 1
            } else if isNotDownloaded(file) {
                inCloud.append(file)
            }
        }
        if absent > 0 { throw Failure.incomplete(missing: absent) }
        if !inCloud.isEmpty {
            startDownloading(inCloud)
            throw Failure.notDownloaded(missing: inCloud.count)
        }
    }

    /// Copies the blob folder of a library for the library file `store` (already copied): only the blobs that file
    /// refers to, and whatever else the folder holds besides `_EXTERNAL_DATA`. SwiftData leaves blobs of old values
    /// behind; on 11.11.2026 a backup held 346 blobs, its library needed 259, and the restore waited for the 87 others
    /// to come down from iCloud Drive.
    static func copySupport(of store: URL, from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) where item.lastPathComponent != "_EXTERNAL_DATA" {
            try fm.copyItem(at: item, to: destination.appending(path: item.lastPathComponent))
        }
        let names = try externalDataNames(storeURL: store)
        guard !names.isEmpty else { return }
        let blobs = source.appending(path: "_EXTERNAL_DATA")
        let target = destination.appending(path: "_EXTERNAL_DATA")
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        // A blob that is missing here is left out; `checkExternalData` then says what is missing.
        for name in names.sorted() where fm.fileExists(atPath: blobs.appending(path: name).path) {
            try fm.copyItem(at: blobs.appending(path: name), to: target.appending(path: name))
        }
    }

    /// A file in iCloud Drive whose content is not on this device yet.
    private static func isNotDownloaded(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true, let status = values.ubiquitousItemDownloadingStatus
        else { return false }
        return status != .current
    }

    private static func startDownloading(_ urls: [URL]) {
        for url in urls { try? FileManager.default.startDownloadingUbiquitousItem(at: url) }
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
            let staged = pending.appending(path: storeURL.lastPathComponent)
            try fm.copyItem(at: backup.appending(path: storeURL.lastPathComponent), to: staged)
            try copySupport(of: staged, from: supportFolder(for: backup.appending(path: storeURL.lastPathComponent)),
                            to: supportFolder(for: staged))
            // Stays in the pending folder, so the start after the restore can say which backup came back.
            try fm.copyItem(at: backup.appending(path: manifestName), to: pending.appending(path: manifestName))
            // The copy must hold every blob, whatever the copy did with files still in iCloud.
            try checkExternalData(storeURL: pending.appending(path: storeURL.lastPathComponent))
        } catch {
            try? fm.removeItem(at: pending)
            throw error
        }
    }

    public static func hasPendingRestore(storeURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: pendingFolder(for: storeURL).appending(path: storeURL.lastPathComponent).path)
    }

    /// The manifest of the staged backup, to read before `applyPendingRestore` (which removes it).
    public static func pendingManifest(storeURL: URL) -> Manifest? {
        guard let data = try? Data(contentsOf: pendingFolder(for: storeURL).appending(path: manifestName)) else { return nil }
        return try? decoder.decode(Manifest.self, from: data)
    }

    public static func cancelPendingRestore(storeURL: URL) {
        try? FileManager.default.removeItem(at: pendingFolder(for: storeURL))
    }

    /// Puts a staged restore in place. Call it before the container opens. Returns the folder that now
    /// holds the library as it was before, or `nil` if nothing was staged.
    ///
    /// With a library in place, the backup is written into it as changes (`rewrite`, B-265), with or
    /// without iCloud sync: the library keeps its own sync state, and iCloud then gives every device the
    /// backup's state. A copy of the library goes into “Library Before Restore …” first; if writing fails,
    /// that copy is put back and `Failure.restoreFailed` says so. Without a library (a new install) the
    /// backup's files are moved in.
    @discardableResult
    public static func applyPendingRestore(storeURL: URL, now: Date = .now) throws -> URL? {
        guard hasPendingRestore(storeURL: storeURL) else { return nil }
        // A staged backup without all its blobs is dropped, never written in: it would empty rides (11.11.2026).
        // A file that does not read at all goes the usual way below and fails there.
        do {
            try checkExternalData(storeURL: pendingFolder(for: storeURL).appending(path: storeURL.lastPathComponent))
        } catch let failure as Failure {
            if case .incomplete = failure {
                cancelPendingRestore(storeURL: storeURL)
                throw failure
            }
        }
        if FileManager.default.fileExists(atPath: storeURL.path) {
            return try rewritePendingRestore(storeURL: storeURL, now: now)
        }
        return try swapPendingRestore(storeURL: storeURL, now: now)
    }

    private static func rewritePendingRestore(storeURL: URL, now: Date) throws -> URL {
        let fm = FileManager.default
        let pending = pendingFolder(for: storeURL)
        let parent = storeURL.deletingLastPathComponent()
        let old = uniqueFolder(named: "Library Before Restore \(timestamp(now))", in: parent)
        let oldStore = old.appending(path: storeURL.lastPathComponent)
        try copyLibrary(from: storeURL, to: oldStore)
        do {
            try rewrite(storeURL: storeURL, from: pending.appending(path: storeURL.lastPathComponent))
        } catch {
            // Never a half library: the copy goes back in place.
            let detail = (error as NSError).localizedDescription
            cancelPendingRestore(storeURL: storeURL)
            for name in libraryFileNames(for: storeURL) {
                try? fm.removeItem(at: parent.appending(path: name))
            }
            let putBack = (try? copyLibrary(from: oldStore, to: storeURL)) != nil
            throw Failure.restoreFailed(kept: old, putBack: putBack, detail: detail)
        }
        try? fm.removeItem(at: pending)
        return old
    }

    private static func swapPendingRestore(storeURL: URL, now: Date) throws -> URL {
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
    static func libraryFileNames(for storeURL: URL) -> [String] {
        let name = storeURL.lastPathComponent
        return [name, name + "-wal", name + "-shm", supportFolder(for: storeURL).lastPathComponent]
    }

    static func uniqueFolder(named name: String, in parent: URL) -> URL {
        var url = parent.appending(path: name)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = parent.appending(path: "\(name) \(n)")
            n += 1
        }
        return url
    }

    static func timestamp(_ date: Date) -> String {
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

    static var decoder: JSONDecoder {
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
        // The app (or a container closing just now) may hold a write lock for a moment: wait for it instead of failing.
        sqlite3_busy_timeout(from, 5000)
        sqlite3_busy_timeout(to, 5000)
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

    /// The names of the blob files the library file refers to. SwiftData (Core Data) keeps a large value of an
    /// `externalStorage` attribute as a file in `_EXTERNAL_DATA` and writes `0x02` and the file's UUID into the
    /// column; a small one stays in the column after `0x01`.
    static func externalDataNames(storeURL: URL) throws -> Set<String> {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        let uri = storeURL.absoluteString + "?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else { throw failure(db) }

        func rows(_ sql: String) throws -> [[String]] {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure(db) }
            var result: [[String]] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append((0..<sqlite3_column_count(statement)).map { column in
                    sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
                })
            }
            return result
        }

        // The app's own tables (Z…), not Core Data's (Z_…) or the iCloud mirror's (ANSCK…).
        let columns = try rows("""
            SELECT m.name, p.name FROM sqlite_master m JOIN pragma_table_info(m.name) p
            WHERE m.type = 'table' AND m.name LIKE 'Z%' AND m.name NOT LIKE 'Z\\_%' ESCAPE '\\' AND p.type = 'BLOB'
            """)
        var names: Set<String> = []
        for column in columns where column.count == 2 {
            let table = column[0].replacingOccurrences(of: "\"", with: "\"\"")
            let name = column[1].replacingOccurrences(of: "\"", with: "\"\"")
            let sql = "SELECT CAST(substr(\"\(name)\", 2) AS TEXT) FROM \"\(table)\" WHERE substr(\"\(name)\", 1, 1) = x'02'"
            for row in try rows(sql) {
                if let value = row.first, UUID(uuidString: value) != nil { names.insert(value) }
            }
        }
        return names
    }

    private static func failure(_ db: OpaquePointer?) -> Failure {
        .database(sqlite3_errcode(db), db.map { String(cString: sqlite3_errmsg($0)) } ?? "")
    }
}
