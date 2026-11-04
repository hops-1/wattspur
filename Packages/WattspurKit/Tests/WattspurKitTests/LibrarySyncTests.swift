import Foundation
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit

/// The switch for iCloud sync (B-072) and the backup before the first sync (P-22). Sync itself needs the
/// iCloud entitlement and is not tested here.
@MainActor
@Suite("Library sync")
struct LibrarySyncTests {
    @Test("Sync is on only when it is turned on and the app may use iCloud")
    func activeNeedsBoth() {
        #expect(LibrarySync.isActive(requested: true, available: true))
        #expect(!LibrarySync.isActive(requested: true, available: false))
        #expect(!LibrarySync.isActive(requested: false, available: true))
        #expect(!LibrarySync.isActive(requested: false, available: false))
    }

    @Test("Without sync the library opens with no CloudKit container, with sync with Wattspur's")
    func configuration() {
        #expect(LibrarySync.configuration(requested: true, available: false).cloudKitContainerIdentifier == nil)
        #expect(LibrarySync.configuration(requested: false, available: true).cloudKitContainerIdentifier == nil)
        #expect(LibrarySync.configuration(requested: true, available: true).cloudKitContainerIdentifier
                == "iCloud.io.github.hops-1.wattspur")
    }

    @Test("With and without sync it is the same library file as before")
    func sameFile() {
        let before = ModelConfiguration().url
        #expect(LibrarySync.configuration(requested: false, available: false).url == before)
        #expect(LibrarySync.configuration(requested: true, available: true).url == before)
    }

    @Test("A library opens with the configuration without sync and keeps its rides")
    func opensWithoutSync() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")
        do {
            let old = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
            old.mainContext.autosaveEnabled = false
            let library = RideLibrary(context: old.mainContext)
            _ = library.importFile(data: try Fixture.data("reinheim-rundfahrt"),
                                   fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c0001.fit")
            library.save()
        }
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: configuration)
        container.mainContext.autosaveEnabled = false
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Ride>()) == 1)
    }

    @Test("The backup before the first sync lands beside the library and holds it")
    func backupBeforeFirstSync() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "default.store")
        do {
            let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: storeURL))
            container.mainContext.autosaveEnabled = false
            let library = RideLibrary(context: container.mainContext)
            _ = library.importFile(data: try Fixture.data("reinheim-rundfahrt"),
                                   fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c0001.fit")
            library.save()
        }

        let backup = try #require(try LibrarySync.backUpBeforeFirstSync(storeURL: storeURL, appVersion: "1.8.3", build: "1", rideCount: 1))
        #expect(backup.deletingLastPathComponent().standardizedFileURL.path == folder.appending(path: "Backups Before iCloud").standardizedFileURL.path)
        let manifest = try LibraryBackup.inspect(backup, storeName: "default.store")
        #expect(manifest.rideCount == 1)
        #expect(manifest.appVersion == "1.8.3")
    }

    @Test("Without a library there is nothing to back up")
    func noLibraryNoBackup() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-sync-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "default.store")
        #expect(try LibrarySync.backUpBeforeFirstSync(storeURL: storeURL, appVersion: "1.8.3", build: "1", rideCount: 0) == nil)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("Another file for the test library keeps the sync setting")
    func configurationWithURL() {
        let url = FileManager.default.temporaryDirectory.appending(path: "Spike/default.store")
        let configuration = LibrarySync.configuration(requested: true, available: true, url: url)
        #expect(configuration.url == url)
        #expect(configuration.cloudKitContainerIdentifier == "iCloud.io.github.hops-1.wattspur")
        #expect(LibrarySync.configuration(requested: false, available: true, url: url).cloudKitContainerIdentifier == nil)
    }

    @Test("A copy of the library opens in its own folder with the same rides")
    func copyLibrary() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "default.store")
        do {
            let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: storeURL))
            container.mainContext.autosaveEnabled = false
            let library = RideLibrary(context: container.mainContext)
            _ = library.importFile(data: try Fixture.data("reinheim-rundfahrt"),
                                   fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c0001.fit")
            library.save()
        }
        let copy = folder.appending(path: "Spike/default.store")
        try LibraryBackup.copyLibrary(from: storeURL, to: copy)
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(url: copy, cloudKitDatabase: .none))
        container.mainContext.autosaveEnabled = false
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Ride>()) == 1)
        #expect(throws: LibraryBackup.Failure.noLibrary) {
            try LibraryBackup.copyLibrary(from: folder.appending(path: "none.store"), to: folder.appending(path: "x/default.store"))
        }
    }
}
