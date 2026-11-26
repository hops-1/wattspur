import CoreData
import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Planned tours in a backup (B-386): a backup keeps the tours, their trash state and the link of a
/// ride to its tour, and a backup from before Mac 1.11 and iPhone 1.7, which has no tours at all,
/// still restores. All tours and rides here are made up.
@MainActor
@Suite("Planned tours in backups")
struct PlannedTourBackupTests {
    let root: URL
    let storeURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "wattspur-tour-backup-\(UUID().uuidString)")
        let folder = root.appending(path: "Application Support")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storeURL = folder.appending(path: "default.store")
    }

    /// Opens the store with the app's schema, runs `body` and saves. Autosave off: a timer that fires
    /// after the container is gone stops the test run.
    private func edit<T>(_ url: URL, _ body: (ModelContext) throws -> T) throws -> T {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        let context = container.mainContext
        context.autosaveEnabled = false
        let result = try body(context)
        try context.save()
        return result
    }

    /// A track without times going north from an invented place, `count` points 50 m apart.
    private static func untimed(_ name: String, count: Int = 10, longitude: Double = 9.0) -> Data {
        let body = (0..<count).map { i in
            "<trkpt lat=\"\(50 + Double(i) * 50 / 111_320)\" lon=\"\(longitude)\"><ele>\(300 + i)</ele></trkpt>"
        }.joined()
        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Planer" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>\(name)</name><trkseg>\(body)</trkseg></trk></gpx>
        """.utf8)
    }

    private func importTour(_ name: String, count: Int = 10, longitude: Double = 9.0, in context: ModelContext) throws -> UUID {
        let library = RideLibrary(context: context, importers: [GPXRideImporter()])
        let result = library.importFile(data: Self.untimed(name, count: count, longitude: longitude), fileName: "\(name).gpx")
        return try #require(result.outcome.plannedRouteID)
    }

    private func restore(_ folder: URL) throws {
        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        _ = try #require(try LibraryBackup.applyPendingRestore(storeURL: storeURL))
    }

    @Test("A backup keeps the tours with their points, the original file, the trash and a ride's link")
    func toursTravel() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (tower, lake) = try edit(storeURL) { context in
            let tower = try importTour("Zum Turm", in: context)
            let lake = try importTour("Zum See", count: 14, longitude: 9.01, in: context)
            let library = RideLibrary(context: context)
            library.moveToTrash([try #require(library.plannedRoute(withID: lake))], at: Date(timeIntervalSince1970: 1_800_000_000))
            let ride = Ride(name: "Zum Turm gefahren", startDate: Date(timeIntervalSince1970: 1_800_003_600))
            ride.distance = 450
            ride.plannedRouteID = tower
            context.insert(ride)
            return (tower, lake)
        }
        let folder = try LibraryBackup.create(storeURL: storeURL, in: root, appVersion: "1.7", build: "51", rideCount: 1)

        // After the backup: one tour renamed, the other deleted for good, the link gone.
        try edit(storeURL) { context in
            let library = RideLibrary(context: context)
            library.rename(try #require(library.plannedRoute(withID: tower)), to: "Anders")
            context.delete(try #require(library.plannedRoute(withID: lake)))
            for ride in try context.fetch(FetchDescriptor<Ride>()) { ride.plannedRouteID = nil }
        }
        try restore(folder)

        try edit(storeURL) { context in
            let library = RideLibrary(context: context)
            let restoredTower = try #require(library.plannedRoute(withID: tower))
            #expect(restoredTower.name == "Zum Turm")
            #expect(restoredTower.points.count == 10 && restoredTower.pointCount == 10)
            #expect(abs(restoredTower.distance - 450) < 1)
            #expect(restoredTower.sourceFileName == "Zum Turm.gpx")
            #expect(restoredTower.sourceData == Self.untimed("Zum Turm"))
            #expect(!restoredTower.isInTrash)

            let restoredLake = try #require(library.plannedRoute(withID: lake))
            #expect(restoredLake.isInTrash && restoredLake.points.count == 14)
            #expect(library.plannedRoutes().map(\.id) == [tower])
            #expect(Set(library.plannedRoutes(includingTrash: true).map(\.id)) == [tower, lake])

            let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
            #expect(ride.plannedRouteID == tower)
        }
    }

    @Test("A tour imported after the backup is gone after the restore, like a ride")
    func newerTourGoes() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let tower = try edit(storeURL) { try importTour("Zum Turm", in: $0) }
        let folder = try LibraryBackup.create(storeURL: storeURL, in: root, appVersion: "1.7", build: "51", rideCount: 0)
        let later = try edit(storeURL) { try importTour("Später", count: 12, longitude: 9.02, in: $0) }
        try restore(folder)

        try edit(storeURL) { context in
            let library = RideLibrary(context: context)
            #expect(library.plannedRoute(withID: tower) != nil)
            #expect(library.plannedRoute(withID: later) == nil)
        }
    }

    /// The app's model as it was before B-372: no `PlannedRoute`, and `Ride` without `plannedRouteID`.
    private func modelBeforeTours() throws -> NSManagedObjectModel {
        let current = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models))
        let model = try #require(current.copy() as? NSManagedObjectModel)
        #expect(model.entitiesByName["PlannedRoute"] != nil)
        model.entities = model.entities.filter { $0.name != "PlannedRoute" }
        let ride = try #require(model.entitiesByName["Ride"])
        #expect(ride.attributesByName["plannedRouteID"] != nil)
        ride.properties = ride.properties.filter { $0.name != "plannedRouteID" }
        return model
    }

    @Test("A backup from before the tours restores: its rides come back, the tours of today are gone")
    func backupBeforeTours() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        // A library written by Mac 1.10.5 / iPhone 1.6.9.
        let oldFolder = root.appending(path: "Old")
        try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
        let oldStore = oldFolder.appending(path: "default.store")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try modelBeforeTours())
        let store = try coordinator.addPersistentStore(type: .sqlite, at: oldStore,
                                                       options: [NSPersistentHistoryTrackingKey: true as NSNumber])
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for (index, name) in ["Erste Runde", "Zweite Runde"].enumerated() {
                let ride = NSEntityDescription.insertNewObject(forEntityName: "Ride", into: context)
                ride.setValue(UUID(), forKey: "id")
                ride.setValue(name, forKey: "name")
                ride.setValue(Date(timeIntervalSince1970: 1_800_000_000 + Double(index) * 3600), forKey: "startDate")
                ride.setValue(10_000.0, forKey: "distance")
            }
            try context.save()
        }
        try coordinator.remove(store)
        let folder = try LibraryBackup.create(storeURL: oldStore, in: root, appVersion: "1.10.5", build: "1049", rideCount: 2)

        // Restored into a library of today that holds a tour.
        _ = try edit(storeURL) { try importTour("Zum Turm", in: $0) }
        try restore(folder)

        try edit(storeURL) { context in
            let names = Set(try context.fetch(FetchDescriptor<Ride>()).map(\.name))
            #expect(names == ["Erste Runde", "Zweite Runde"])
            #expect(try context.fetch(FetchDescriptor<Ride>()).allSatisfy { $0.plannedRouteID == nil })
            #expect(try context.fetchCount(FetchDescriptor<PlannedRoute>()) == 0)
        }
    }
}
