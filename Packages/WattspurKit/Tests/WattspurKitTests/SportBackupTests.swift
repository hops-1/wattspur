import CoreData
import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// The sport in a backup (B-310): a backup keeps cars, motorcycles, running shoes and the kind of a
/// ride without a device, and a backup from before Mac 1.9 and iPhone 1.1, whose rides have no
/// kind, restores with its rides as bicycles. All rides here are made up.
@MainActor
@Suite("Sport in backups")
struct SportBackupTests {
    let root: URL
    let storeURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "wattspur-sport-\(UUID().uuidString)")
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

    private func ride(_ name: String, hour: Double, in context: ModelContext) -> Ride {
        let ride = Ride(name: name, startDate: Date(timeIntervalSince1970: 1_800_000_000 + hour * 3600))
        ride.distance = 10_000
        ride.timerTime = 1800
        context.insert(ride)
        return ride
    }

    private func restore(_ folder: URL) throws {
        try LibraryBackup.stageRestore(from: folder, storeURL: storeURL)
        _ = try #require(try LibraryBackup.applyPendingRestore(storeURL: storeURL))
    }

    /// What the restored library says per ride name: the kind and whether the ride has a device.
    private func kinds() throws -> [String: (kind: BikeKind, hasDevice: Bool, counts: Bool)] {
        try edit(storeURL) { context in
            Dictionary(try context.fetch(FetchDescriptor<Ride>()).map { ($0.name, ($0.deviceKind, $0.bike != nil, $0.countsInTotals)) },
                       uniquingKeysWith: { first, _ in first })
        }
    }

    @Test("A backup keeps the new devices and the kind of a ride without a device")
    func newKindsTravel() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try edit(storeURL) { context in
            let library = RideLibrary(context: context)
            let car = library.makeBike(name: "Nugget", kind: .car)
            let shoes = library.makeBike(name: "Pegasus", kind: .runningShoe)
            let ebike = library.makeBike(name: "Cube")
            ride("Im Auto", hour: 0, in: context).bike = car
            ride("Gelaufen", hour: 1, in: context).bike = shoes
            ride("Mit dem Rad", hour: 2, in: context).bike = ebike
            ride("Motorrad ohne Gerät", hour: 3, in: context).sportRawValue = BikeKind.motorcycle.rawValue
        }
        let folder = try LibraryBackup.create(storeURL: storeURL, in: root, appVersion: "1.9", build: "800", rideCount: 4)

        // After the backup everything is changed; the restore brings back the kinds.
        try edit(storeURL) { context in
            for bike in try context.fetch(FetchDescriptor<Bike>()) { bike.kind = .bike }
            for ride in try context.fetch(FetchDescriptor<Ride>()) { ride.sportRawValue = nil }
        }
        try restore(folder)

        let restored = try kinds()
        #expect(restored["Im Auto"]?.kind == .car && restored["Im Auto"]?.counts == false)
        #expect(restored["Gelaufen"]?.kind == .runningShoe && restored["Gelaufen"]?.counts == false)
        #expect(restored["Mit dem Rad"]?.kind == .bike && restored["Mit dem Rad"]?.counts == true)
        let moto = try #require(restored["Motorrad ohne Gerät"])
        #expect(moto.kind == .motorcycle && !moto.hasDevice && !moto.counts)
    }

    /// The app's model as it was before B-284: `Ride` without `sportRawValue`.
    private func modelBeforeSports() throws -> NSManagedObjectModel {
        let current = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WattspurSchema.models))
        let model = try #require(current.copy() as? NSManagedObjectModel)
        let ride = try #require(model.entitiesByName["Ride"])
        #expect(ride.attributesByName["sportRawValue"] != nil)
        ride.properties = ride.properties.filter { $0.name != "sportRawValue" }
        return model
    }

    @Test("A backup from before the sports restores: its rides are bicycles, a motorcycle stays a vehicle")
    func backupBeforeSports() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        // A library written by Mac 1.8 / iPhone 1.0, with a motorcycle among its bikes.
        let oldFolder = root.appending(path: "Old")
        try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
        let oldStore = oldFolder.appending(path: "default.store")
        let model = try modelBeforeSports()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: oldStore,
                                                       options: [NSPersistentHistoryTrackingKey: true as NSNumber])
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            func bike(_ name: String, _ kind: String) -> NSManagedObject {
                let bike = NSEntityDescription.insertNewObject(forEntityName: "Bike", into: context)
                bike.setValue(UUID(), forKey: "id")
                bike.setValue(name, forKey: "name")
                bike.setValue(kind, forKey: "kindRawValue")
                return bike
            }
            func ride(_ name: String, on bike: NSManagedObject?, hour: Double) {
                let ride = NSEntityDescription.insertNewObject(forEntityName: "Ride", into: context)
                ride.setValue(UUID(), forKey: "id")
                ride.setValue(name, forKey: "name")
                ride.setValue(Date(timeIntervalSince1970: 1_800_000_000 + hour * 3600), forKey: "startDate")
                ride.setValue(10_000.0, forKey: "distance")
                ride.setValue(bike, forKey: "bike")
            }
            ride("Auf dem Rad", on: bike("Cube", "gravel"), hour: 0)
            ride("Auf dem Motorrad", on: bike("Honda", "motorcycle"), hour: 1)
            ride("Ohne Gerät", on: nil, hour: 2)
            try context.save()
        }
        try coordinator.remove(store)
        let folder = try LibraryBackup.create(storeURL: oldStore, in: root, appVersion: "1.8.15", build: "700", rideCount: 3)

        // Restored into a library of today that holds a car ride without a device.
        try edit(storeURL) { context in
            ride("Später im Auto", hour: 5, in: context).sportRawValue = BikeKind.car.rawValue
        }
        try restore(folder)

        let restored = try kinds()
        #expect(restored.count == 3 && restored["Später im Auto"] == nil)
        #expect(restored["Auf dem Rad"]?.kind == .gravel && restored["Auf dem Rad"]?.counts == true)
        #expect(restored["Auf dem Motorrad"]?.kind == .motorcycle && restored["Auf dem Motorrad"]?.counts == false)
        let plain = try #require(restored["Ohne Gerät"])
        #expect(plain.kind == .bike && !plain.hasDevice && plain.counts)
    }
}

/// The GPX export names the sport (B-310), so a car ride does not arrive at komoot or Strava as a bike ride.
@Suite("Sport in the GPX export")
struct SportGPXTests {
    @Test("The track type follows the sport")
    func trackType() {
        func type(_ sport: Sport?) -> String {
            let segment = GPXWriter.Segment(startDate: Date(timeIntervalSince1970: 1_800_000_000), samples: [])
            let data = sport.map { GPXWriter.document(name: "Tour", segments: [segment], sport: $0) }
                ?? GPXWriter.document(name: "Tour", segments: [segment])
            let text = String(decoding: data, as: UTF8.self)
            guard let start = text.range(of: "<type>"), let end = text.range(of: "</type>") else { return "" }
            return String(text[start.upperBound..<end.lowerBound])
        }
        #expect(type(nil) == "cycling")
        #expect(type(.cycling) == "cycling")
        #expect(type(.vehicle) == "driving")
        #expect(type(.running) == "running")
    }

    @Test("The exchange format says which version knows the kind of a ride")
    func schemaVersion() throws {
        #expect(RideExchange.schemaVersion == 2)
        let ride = RideExchange.Ride(id: UUID(), name: "Auto", startDate: Date(timeIntervalSince1970: 1_800_000_000), bikeID: nil,
                                     kind: "car", source: "gpx", timerTime: 60, elapsedTime: 60, distance: 1000)
        let library = RideExchange.Library(generatedAt: Date(timeIntervalSince1970: 1_800_000_100), generator: "test",
                                           bikes: [], rides: [ride])
        let data = try RideExchange.encoder().encode(library)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"kind\":\"car\"") && text.contains("\"schemaVersion\":2"))
        let read = try RideExchange.library(from: data)
        #expect(read == library && read.kind(of: read.rides[0]) == .car && read.countedRides.isEmpty)
        // A file of schema 1 still reads; its rides without a bike are cycling.
        let old = Data(#"""
        {"schemaVersion": 1, "generatedAt": "2026-11-02T10:00:00Z", "generator": "x", "bikes": [],
         "rides": [{"id": "6F1C2A4E-0000-4000-8000-000000000001", "name": "Alt", "startDate": "2026-11-01T10:00:00Z",
                    "source": "gpx", "estimated": false, "timerTime": 60, "elapsedTime": 60, "distance": 1000}]}
        """#.utf8)
        let oldLibrary = try RideExchange.library(from: old)
        #expect(oldLibrary.countedRides.count == 1 && oldLibrary.sport(of: oldLibrary.rides[0]) == .cycling)
    }
}
