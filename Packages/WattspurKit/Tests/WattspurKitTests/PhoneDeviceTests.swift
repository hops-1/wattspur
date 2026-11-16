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
}
