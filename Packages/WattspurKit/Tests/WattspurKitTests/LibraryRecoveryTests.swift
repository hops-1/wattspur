import Foundation
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit

/// The way out of a library that does not open (B-264, R-41), on real files in a temporary folder.
@MainActor
@Suite("Library recovery")
struct LibraryRecoveryTests {
    let root: URL
    let storeURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "wattspur-recovery-\(UUID().uuidString)")
        let folder = root.appending(path: "Application Support")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storeURL = folder.appending(path: "default.store")
    }

    private func open(_ url: URL) throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        // Saved by hand: an autosave timer that fires after the container is released stops the whole test run.
        container.mainContext.autosaveEnabled = false
        return container
    }

    /// A store file full of junk, like a damaged disk or a broken copy.
    private func writeDamagedStore() throws {
        try Data(repeating: 7, count: 8192).write(to: storeURL)
        try Data(repeating: 3, count: 512).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
        let support = LibraryBackup.supportFolder(for: storeURL)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: support.appending(path: "blob"))
    }

    @Test("A damaged file does not open, is set aside whole, and an empty library opens after it")
    func setsAsideAndStartsEmpty() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try writeDamagedStore()
        #expect(throws: (any Error).self) { _ = try open(storeURL) }

        let now = Date(timeIntervalSince1970: 1_794_200_000)
        let folder = try #require(try LibraryBackup.setAsideDamaged(storeURL: storeURL, now: now))
        let fm = FileManager.default
        #expect(folder.lastPathComponent.hasPrefix("Damaged Library "))
        #expect(fm.fileExists(atPath: folder.appending(path: "default.store").path))
        #expect(fm.fileExists(atPath: folder.appending(path: "default.store-wal").path))
        #expect(fm.fileExists(atPath: folder.appending(path: ".default_SUPPORT/blob").path))
        #expect(!fm.fileExists(atPath: storeURL.path))
        // The old file is kept as it was, byte for byte.
        #expect(try Data(contentsOf: folder.appending(path: "default.store")) == Data(repeating: 7, count: 8192))

        let container = try open(storeURL)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Ride>()) == 0)
    }

    @Test("Without a library file there is nothing to set aside")
    func nothingToSetAside() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try LibraryBackup.setAsideDamaged(storeURL: storeURL) == nil)
    }

    @Test("Twice in the same minute gives two folders")
    func twoFolders() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date.now
        try writeDamagedStore()
        let first = try LibraryBackup.setAsideDamaged(storeURL: storeURL, now: now)
        try writeDamagedStore()
        let second = try LibraryBackup.setAsideDamaged(storeURL: storeURL, now: now)
        #expect(first != nil && second != nil && first != second)
    }

    @Test("Kept folders list backups, replaced and damaged libraries, newest first")
    func keptFolders() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let fm = FileManager.default
        let parent = storeURL.deletingLastPathComponent()
        let backups = LibrarySync.backupFolder(for: storeURL)
        try fm.createDirectory(at: backups.appending(path: "Wattspur Backup 2026-11-01 0800"), withIntermediateDirectories: true)
        try fm.createDirectory(at: parent.appending(path: "Library Before Restore 2026-11-03 0900"), withIntermediateDirectories: true)
        try fm.createDirectory(at: parent.appending(path: "Damaged Library 2026-11-09 1000"), withIntermediateDirectories: true)
        try fm.createDirectory(at: parent.appending(path: "CurvyRoads"), withIntermediateDirectories: true)

        let names = LibraryBackup.keptFolders(storeURL: storeURL).map(\.lastPathComponent)
        #expect(names == ["Damaged Library 2026-11-09 1000", "Library Before Restore 2026-11-03 0900", "Wattspur Backup 2026-11-01 0800"])
    }
}
