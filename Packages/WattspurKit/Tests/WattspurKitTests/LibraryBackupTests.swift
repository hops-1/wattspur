import Foundation
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit

/// Back up, restore and the start-up swap (P-22) on real store files in a temporary folder.
@MainActor
@Suite("Library backup")
struct LibraryBackupTests {
    let root: URL
    let storeURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "wattspur-backup-\(UUID().uuidString)")
        let folder = root.appending(path: "Application Support")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storeURL = folder.appending(path: "default.store")
    }

    /// Opens the store file with the app's schema, imports `rides` copies of the fixture ride and returns the number
    /// of rides afterwards. The container is released again, so the files are closed.
    private func fill(_ url: URL, importing rides: Int = 0) throws -> Int {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        let library = RideLibrary(context: container.mainContext)
        let data = try Fixture.data("reinheim-rundfahrt")
        for index in 0..<rides {
            let name = "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c\(String(format: "%04d", index)).fit"
            _ = library.importFile(data: data, fileName: name, detectDuplicates: false)
        }
        library.save()
        return try container.mainContext.fetchCount(FetchDescriptor<Ride>())
    }

    private func count(_ url: URL) throws -> Int {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        return try container.mainContext.fetchCount(FetchDescriptor<Ride>())
    }

    private func backup(now: Date = .now) throws -> URL {
        let destination = root.appending(path: "Backups")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return try LibraryBackup.create(storeURL: storeURL, in: destination, appVersion: "1.7.1", build: "300", rideCount: 3, now: now)
    }

    @Test("A backup holds the library, the manifest and a library that opens")
    func createsBackup() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try fill(storeURL, importing: 3) == 3)

        let folder = try backup()
        let manifest = try LibraryBackup.inspect(folder, storeName: "default.store")
        #expect(manifest.appVersion == "1.7.1")
        #expect(manifest.build == "300")
        #expect(manifest.rideCount == 3)
        #expect(try count(folder.appending(path: "default.store")) == 3)
    }

    @Test("Two backups in the same minute get different folders")
    func uniqueNames() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let now = Date.now
        let first = try backup(now: now)
        let second = try backup(now: now)
        #expect(first != second)
    }

    @Test("Without a library there is nothing to back up")
    func noLibrary() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: LibraryBackup.Failure.noLibrary) {
            try LibraryBackup.create(storeURL: storeURL, in: root, appVersion: "1", build: "1", rideCount: nil)
        }
    }

    @Test("A folder that is not a backup is refused")
    func refusesOtherFolders() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let other = root.appending(path: "Other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        #expect(throws: LibraryBackup.Failure.notABackup) {
            try LibraryBackup.inspect(other, storeName: "default.store")
        }
        // A manifest alone is not enough.
        let manifest = LibraryBackup.Manifest(createdAt: .now, appVersion: "1", build: "1", rideCount: nil)
        try JSONEncoder().encode(manifest).write(to: other.appending(path: "manifest.json"))
        #expect(throws: LibraryBackup.Failure.notABackup) {
            try LibraryBackup.inspect(other, storeName: "default.store")
        }
    }

    @Test("A damaged library file is refused")
    func refusesDamagedStore() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let folder = try backup()
        try Data(repeating: 7, count: 4096).write(to: folder.appending(path: "default.store"))
        #expect(throws: (any Error).self) {
            try LibraryBackup.inspect(folder, storeName: "default.store")
        }
    }

    @Test("A backup made by a newer format is refused")
    func refusesNewerFormat() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let folder = try backup()
        var manifest = try LibraryBackup.inspect(folder, storeName: "default.store")
        manifest.format = LibraryBackup.Manifest.currentFormat + 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: folder.appending(path: "manifest.json"))
        #expect(throws: LibraryBackup.Failure.unsupportedFormat(2)) {
            try LibraryBackup.inspect(folder, storeName: "default.store")
        }
    }

    @Test("A restore is swapped in at the next start and the old library is kept")
    func restoreSwapsLibrary() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try fill(storeURL, importing: 2) == 2)
        let folder = try backup()
        // The library changes after the backup.
        #expect(try fill(storeURL, importing: 3) == 5)

        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        #expect(LibraryBackup.hasPendingRestore(storeURL: storeURL))
        // Staging alone leaves the library as it is.
        #expect(try count(storeURL) == 5)

        let kept = try #require(try LibraryBackup.applyPendingRestore(storeURL: storeURL))
        #expect(!LibraryBackup.hasPendingRestore(storeURL: storeURL))
        #expect(try count(storeURL) == 2)
        #expect(try count(kept.appending(path: "default.store")) == 5)

        // A second start does nothing.
        #expect(try LibraryBackup.applyPendingRestore(storeURL: storeURL) == nil)
    }

    @Test("A restore that is cancelled leaves nothing behind")
    func cancelRestore() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let folder = try backup()
        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        LibraryBackup.cancelPendingRestore(storeURL: storeURL)
        #expect(!LibraryBackup.hasPendingRestore(storeURL: storeURL))
        #expect(try LibraryBackup.applyPendingRestore(storeURL: storeURL) == nil)
        #expect(try count(storeURL) == 1)
    }

    @Test("The folder of larger blobs goes into the backup and comes back with a restore")
    func blobFolderTravels() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let blobs = storeURL.deletingLastPathComponent().appending(path: ".default_SUPPORT/_EXTERNAL_DATA")
        try FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: blobs.appending(path: "blob"))

        let folder = try backup()
        #expect(try Data(contentsOf: folder.appending(path: ".default_SUPPORT/_EXTERNAL_DATA/blob")) == Data("first".utf8))

        try Data("second".utf8).write(to: blobs.appending(path: "blob"))
        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        _ = try LibraryBackup.applyPendingRestore(storeURL: storeURL)
        #expect(try Data(contentsOf: blobs.appending(path: "blob")) == Data("first".utf8))
    }
}
