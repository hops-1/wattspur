import CoreData
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
        // Saved by hand: an autosave timer that fires after the container is released stops the whole test run.
        container.mainContext.autosaveEnabled = false
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
        container.mainContext.autosaveEnabled = false
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

        // Before the swap the start can read which backup comes back.
        let staged = try #require(LibraryBackup.pendingManifest(storeURL: storeURL))
        #expect(staged.rideCount == 3)
        #expect(staged.build == "300")

        let kept = try #require(try LibraryBackup.applyPendingRestore(storeURL: storeURL))
        #expect(LibraryBackup.pendingManifest(storeURL: storeURL) == nil)
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

        // Without a library (a new install) the backup's files are moved in as they are.
        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        for name in LibraryBackup.libraryFileNames(for: storeURL) {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent().appending(path: name))
        }
        _ = try LibraryBackup.applyPendingRestore(storeURL: storeURL)
        #expect(try Data(contentsOf: blobs.appending(path: "blob")) == Data("first".utf8))
        #expect(try count(storeURL) == 1)
    }

    // MARK: Restore with iCloud sync (B-265)

    /// Opens the store with the app's schema, runs `body` and saves.
    private func edit(_ url: URL, _ body: (ModelContext) throws -> Void) throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        let context = container.mainContext
        context.autosaveEnabled = false
        try body(context)
        try context.save()
    }

    private func rides(_ url: URL) throws -> [UUID: String] {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        container.mainContext.autosaveEnabled = false
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>())
        return Dictionary(rides.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// The SQLite row of each ride by its `id`: the same row means the object was not replaced.
    private func rows(_ url: URL) throws -> [UUID: Int64] {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: url, options: [NSPersistentHistoryTrackingKey: true as NSNumber])
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            var result: [UUID: Int64] = [:]
            for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Ride")) {
                let id = try #require(object.value(forKey: "id") as? UUID)
                let pk = object.objectID.uriRepresentation().lastPathComponent.dropFirst()
                result[id] = Int64(pk)
            }
            return result
        }
    }

    @Test("A restore into a library writes the backup's state: deleted rides come back, new ones go, changes are undone")
    func restoreRewritesLibrary() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try fill(storeURL, importing: 3) == 3)
        let backedUp = try rides(storeURL)
        let folder = try backup()

        // After the backup: one ride deleted, one renamed, two new.
        let ids = backedUp.keys.sorted { $0.uuidString < $1.uuidString }
        try edit(storeURL) { context in
            for ride in try context.fetch(FetchDescriptor<Ride>()) {
                if ride.id == ids[0] { context.delete(ride) }
                if ride.id == ids[1] { ride.name = "Renamed after the backup" }
            }
        }
        #expect(try fill(storeURL, importing: 2) == 4)
        // The bike goes too; its rides lose it.
        try edit(storeURL) { context in
            for bike in try context.fetch(FetchDescriptor<Bike>()) { context.delete(bike) }
        }
        let untouchedRow = try #require(try rows(storeURL)[ids[2]])

        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        let kept = try #require(try LibraryBackup.applyPendingRestore(storeURL: storeURL))
        #expect(!LibraryBackup.hasPendingRestore(storeURL: storeURL))
        #expect(try rides(storeURL) == backedUp)
        #expect(try count(kept.appending(path: "default.store")) == 4)
        // The bike is back, and the rides point to it again.
        try edit(storeURL) { context in
            let bikes = try context.fetch(FetchDescriptor<Bike>())
            #expect(bikes.count == 1)
            for ride in try context.fetch(FetchDescriptor<Ride>()) { #expect(ride.bike?.id == bikes.first?.id) }
        }
        // The ride nobody touched is still the same object: the iCloud mirror has nothing to send for it.
        #expect(try rows(storeURL)[ids[2]] == untouchedRow)
    }

    @Test("A restore with sync on is written as history, so the iCloud mirror sends it to the other devices")
    func restoreIsRecordedInHistory() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try fill(storeURL, importing: 1) == 1)
        let folder = try backup()
        #expect(try fill(storeURL, importing: 1) == 2)
        let before = try historyCount(storeURL)

        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        _ = try LibraryBackup.applyPendingRestore(storeURL: storeURL)
        #expect(try count(storeURL) == 1)
        #expect(try historyCount(storeURL) > before)
    }

    private func historyCount(_ url: URL) throws -> Int {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: url, options: [NSPersistentHistoryTrackingKey: true as NSNumber])
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            let result = try context.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: .distantPast)) as? NSPersistentHistoryResult
            return (result?.result as? [NSPersistentHistoryTransaction])?.count ?? 0
        }
    }

    @Test("If writing the backup fails, the library is put back as it was and the staged backup is dropped")
    func failedRewritePutsLibraryBack() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(try fill(storeURL, importing: 1) == 1)
        let folder = try backup()
        #expect(try fill(storeURL, importing: 2) == 3)
        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        // The staged copy breaks before the start.
        try Data("not a database".utf8).write(to: LibraryBackup.pendingFolder(for: storeURL).appending(path: "default.store"))

        #expect {
            try LibraryBackup.applyPendingRestore(storeURL: storeURL)
        } throws: { error in
            guard case .restoreFailed(let kept, let putBack, _) = error as? LibraryBackup.Failure else { return false }
            return putBack && kept.lastPathComponent.hasPrefix("Library Before Restore")
        }
        #expect(try count(storeURL) == 3)
        #expect(!LibraryBackup.hasPendingRestore(storeURL: storeURL))
    }

    // MARK: iPhone and Mac (B-302)

    @Test("A backup from one device restores on the other: same format on iPhone and Mac")
    func exchangeBetweenDevices() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        // The iPhone's library, backed up by the iPhone.
        #expect(try fill(storeURL, importing: 2) == 2)
        let folder = try backup()

        // The Mac's library lives elsewhere but has the same file name; it holds other rides.
        let macFolder = root.appending(path: "Mac/Application Support")
        try FileManager.default.createDirectory(at: macFolder, withIntermediateDirectories: true)
        let macStore = macFolder.appending(path: "default.store")
        #expect(try fill(macStore, importing: 4) == 4)

        let manifest = try LibraryBackup.inspect(folder, storeName: macStore.lastPathComponent)
        #expect(manifest.format == LibraryBackup.Manifest.currentFormat)
        try LibraryBackup.stageRestore(from: folder, storeURL: macStore)
        let kept = try #require(try LibraryBackup.applyPendingRestore(storeURL: macStore))
        #expect(try count(macStore) == 2)
        #expect(try count(kept.appending(path: "default.store")) == 4)

        // And back: the Mac's backup restores on the iPhone.
        let macBackup = try LibraryBackup.create(storeURL: macStore, in: root, appVersion: "1.8.12", build: "700", rideCount: 2)
        try LibraryBackup.stageRestore(from: macBackup, storeURL: storeURL)
        _ = try LibraryBackup.applyPendingRestore(storeURL: storeURL)
        #expect(try count(storeURL) == 2)
    }

    @Test("A manifest of the Mac without the automatic flag still reads, and the flag stays out of it")
    func manifestWithoutAutomaticFlag() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let folder = try backup()
        let json = try String(contentsOf: folder.appending(path: "manifest.json"), encoding: .utf8)
        #expect(!json.contains("automatic"))
        #expect(try LibraryBackup.inspect(folder, storeName: "default.store").automatic == nil)
    }

    @Test("An automatic backup is due after a week, or when there was none")
    func automaticIsDue() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        #expect(LibraryBackup.Automatic.isDue(lastBackup: nil, now: now))
        #expect(!LibraryBackup.Automatic.isDue(lastBackup: now.addingTimeInterval(-6 * 24 * 3600), now: now))
        #expect(LibraryBackup.Automatic.isDue(lastBackup: now.addingTimeInterval(-7 * 24 * 3600), now: now))
    }

    @Test("Pruning keeps the newest three automatic backups and never touches other backups")
    func automaticPrune() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try fill(storeURL, importing: 1)
        let destination = root.appending(path: "Backups")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        var automatic: [URL] = []
        for day in 0..<5 {
            automatic.append(try LibraryBackup.create(storeURL: storeURL, in: destination, appVersion: "0.7.0", build: "19",
                                                      rideCount: 1, automatic: true, now: start.addingTimeInterval(Double(day) * 86_400)))
        }
        let byHand = try LibraryBackup.create(storeURL: storeURL, in: destination, appVersion: "0.7.0", build: "19", rideCount: 1,
                                              now: start.addingTimeInterval(-86_400))
        let other = destination.appending(path: "Holiday photos")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)

        let deleted = LibraryBackup.Automatic.prune(in: destination)
        #expect(Set(deleted.map(\.lastPathComponent)) == Set(automatic.prefix(2).map(\.lastPathComponent)))
        let left = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil).map(\.lastPathComponent)
        #expect(Set(left) == Set(automatic.suffix(3).map(\.lastPathComponent) + [byHand.lastPathComponent, "Holiday photos"]))
    }
}
