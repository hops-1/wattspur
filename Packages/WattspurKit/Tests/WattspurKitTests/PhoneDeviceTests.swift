import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Devices added and edited on the iPhone (B-290), with the rules of the Mac's editor (`BikeDraft`),
/// in the same store the Mac syncs with. All devices here are made up.
@MainActor
@Suite("Devices on the iPhone")
struct PhoneDeviceTests {
    let container: ModelContainer
    let database: PhoneDatabase

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
    }

    private func bikes() throws -> [Bike] {
        try container.mainContext.fetch(FetchDescriptor<Bike>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    @Test("A device added without a name gets a number and survives the sync merge (B-332)")
    func addedDeviceSurvivesSyncMerge() throws {
        #expect(try bikes().contains { $0.name == "Mein eBike" })
        let id = try #require(database.saveDevice(BikeDraft(), id: nil))
        let second = try #require(database.saveDevice(BikeDraft(), id: nil))
        #expect(try bikes().first { $0.id == id }?.name == "Mein eBike 2")
        #expect(try bikes().first { $0.id == second }?.name == "Mein eBike 3")
        let library = RideLibrary(context: container.mainContext, importers: [], defaultBikeName: "Mein eBike")
        _ = library.mergeSyncDuplicates()
        #expect(try bikes().contains { $0.id == id })
        #expect(try bikes().contains { $0.id == second })
    }

    @Test("A car added on the iPhone is a device of its own, without the e-bike switch")
    func addCar() throws {
        var draft = BikeDraft()
        draft.name = "  Nugget "
        draft.kind = .car
        draft.color = .orange
        draft.isEbike = true
        draft.manufacturer = "Ford"
        draft.model = "Transit Nugget"
        draft.startKilometers = 42_000
        let id = try #require(database.saveDevice(draft, id: nil))

        let car = try #require(try bikes().first { $0.id == id })
        #expect(car.name == "Nugget" && car.kind == .car && car.color == .orange)
        #expect(!car.isEbike)
        #expect(car.manufacturer == "Ford" && car.model == "Transit Nugget" && car.startKilometers == 42_000)
        #expect(car.rider != nil)
        // It comes after the bikes there are, and the iPhone's list shows it with its odometer.
        #expect(try bikes().last?.id == id)
        let state = try database.snapshot(generator: "test")
        #expect(state.bikes.first { $0.id == id }?.startKilometers == 42_000)
        #expect(state.devicesBySport().map(\.sport).contains(.vehicle))
    }

    @Test("Editing keeps the device; an empty name keeps the old one, an impossible odometer is not stored")
    func edit() throws {
        let first = try #require(try bikes().first)
        var draft = try #require(database.deviceDraft(id: first.id))
        #expect(draft.name == "Mein eBike")
        draft.name = "Cube Kathmandu"
        draft.color = .teal
        draft.startKilometers = 1_234.5
        #expect(database.saveDevice(draft, id: first.id) == first.id)
        #expect(first.name == "Cube Kathmandu" && first.color == .teal && first.startKilometers == 1_234.5)

        draft.name = "   "
        draft.startKilometers = 999_999
        database.saveDevice(draft, id: first.id)
        #expect(first.name == "Cube Kathmandu")
        #expect(first.startKilometers == 0)
        #expect(try bikes().count == 1)
        // An unknown device is not made.
        #expect(database.saveDevice(draft, id: UUID()) == nil)
        #expect(try bikes().count == 1)
    }

    @Test("A device is archived and restored; the last open one stays")
    func archive() throws {
        let first = try #require(try bikes().first)
        #expect(!database.canArchive(deviceID: first.id))
        #expect(throws: BikeArchiveError.lastBike) { try database.setArchived(true, deviceID: first.id) }

        var draft = BikeDraft()
        draft.name = "Honda"
        draft.kind = .motorcycle
        let honda = try #require(database.saveDevice(draft, id: nil))
        #expect(database.canArchive(deviceID: first.id) && database.canArchive(deviceID: honda))
        try database.setArchived(true, deviceID: honda)
        #expect(try bikes().first { $0.id == honda }?.isArchived == true)
        #expect(!database.canArchive(deviceID: first.id))
        try database.setArchived(false, deviceID: honda)
        #expect(try bikes().first { $0.id == honda }?.isArchived == false)
    }

    @Test("The draft reads back what was saved, photo included")
    func roundTrip() throws {
        var draft = BikeDraft()
        draft.name = "Pegasus"
        draft.kind = .runningShoe
        draft.color = .pink
        draft.photoData = Data([0xFF, 0xD8, 0xFF, 0x00])
        let id = try #require(database.saveDevice(draft, id: nil))
        let read = try #require(database.deviceDraft(id: id))
        #expect(read.name == "Pegasus" && read.kind == .runningShoe && read.color == .pink)
        #expect(read.photoData == draft.photoData && !read.isEbike && read.startKilometers == nil)
    }

    @Test("An archived device without rides can be deleted; one with rides or not archived cannot (B-322)")
    func delete() throws {
        var draft = BikeDraft()
        draft.name = "Test"
        draft.kind = .motorcycle
        let test = try #require(database.saveDevice(draft, id: nil))
        // Not archived: not deleted, so it is never the active or the last one.
        #expect(throws: BikeDeleteError.notArchived) { try database.deleteDevice(id: test) }
        try database.setArchived(true, deviceID: test)
        try database.deleteDevice(id: test)
        #expect(try bikes().contains { $0.id == test } == false)
        // Gone already: nothing happens.
        try database.deleteDevice(id: test)
    }

    @Test("A device with rides in the list says how many; rides in the trash keep its kind (B-322)")
    func deleteWithRides() throws {
        let library = database.library
        let nugget = library.makeBike(name: "Nugget", kind: .car)
        let listed = Ride(name: "Autobahn", startDate: Date(timeIntervalSince1970: 1_800_000_000))
        let trashed = Ride(name: "Weg", startDate: Date(timeIntervalSince1970: 1_800_100_000))
        container.mainContext.insert(listed)
        container.mainContext.insert(trashed)
        listed.bike = nugget
        trashed.bike = nugget
        trashed.deletedAt = .now
        try container.mainContext.save()
        try database.setArchived(true, deviceID: nugget.id)
        #expect(database.listedRideCount(deviceID: nugget.id) == 1)
        #expect(throws: BikeDeleteError.hasRides(1)) { try database.deleteDevice(id: nugget.id) }

        // Assigned to another device, it can go; the ride in the trash stays a car ride.
        listed.bike = try bikes().first { $0.kind != .car }
        try database.deleteDevice(id: nugget.id)
        #expect(try bikes().contains { $0.name == "Nugget" } == false)
        #expect(trashed.bike == nil && trashed.sportRawValue == "car" && trashed.deviceKind == .car)
    }
}
