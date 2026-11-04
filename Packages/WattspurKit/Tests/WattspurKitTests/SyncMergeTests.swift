import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Merging what two devices made on their own before the first sync (B-216, V-15).
@MainActor
@Suite("Merge after sync")
struct SyncMergeTests {
    let container: ModelContainer
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    private let mac = Date(timeIntervalSince1970: 1_700_000_000)
    private let phone = Date(timeIntervalSince1970: 1_800_000_000)

    private func rider(createdAt: Date) -> Rider {
        let rider = Rider()
        rider.createdAt = createdAt
        context.insert(rider)
        return rider
    }

    private func bike(_ name: String, createdAt: Date, rider: Rider) -> Bike {
        let bike = Bike(name: name)
        bike.createdAt = createdAt
        context.insert(bike)
        bike.rider = rider
        return bike
    }

    private func ride(_ id: String, importedAt: Date, bike: Bike?) -> Ride {
        let ride = Ride(name: "Tour \(id)", startDate: Date(timeIntervalSince1970: 1_750_000_000))
        ride.sourceIdentifier = id
        ride.sourceFormat = "fit"
        ride.importedAt = importedAt
        context.insert(ride)
        ride.bike = bike
        return ride
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test("The Mac's library and a fresh iPhone become one rider and one bike, the Mac's")
    func freshPhone() throws {
        let macRider = rider(createdAt: mac)
        macRider.weightKg = 80
        let cube = bike("Cube Reaction", createdAt: mac, rider: macRider)
        macRider.activeBikeID = cube.id
        _ = ride("a", importedAt: mac, bike: cube)
        let phoneRider = rider(createdAt: phone)
        phoneRider.heightCm = 182
        let phoneBike = bike("Mein eBike", createdAt: phone, rider: phoneRider)
        phoneRider.activeBikeID = phoneBike.id
        try context.save()

        let report = library.mergeSyncDuplicates()

        #expect(report == SyncMergeReport(riders: 1, bikes: 1))
        #expect(try count(Rider.self) == 1)
        #expect(try count(Bike.self) == 1)
        let left = try #require(try context.fetch(FetchDescriptor<Rider>()).first)
        #expect(left.id == macRider.id)
        #expect(left.weightKg == 80)
        #expect(left.heightCm == 182)
        #expect(left.activeBikeID == cube.id)
        #expect(library.bikes().first?.rides?.count == 1)
    }

    @Test("Two bikes with the same name become the older one with all rides")
    func sameName() throws {
        let owner = rider(createdAt: mac)
        let old = bike("Mein eBike", createdAt: mac, rider: owner)
        let new = bike("mein ebike ", createdAt: phone, rider: owner)
        new.batteryWh = 625
        _ = ride("a", importedAt: mac, bike: old)
        _ = ride("b", importedAt: phone, bike: new)
        try context.save()

        #expect(library.mergeSyncDuplicates().bikes == 1)
        let left = try #require(library.bikes().first)
        #expect(library.bikes().count == 1)
        #expect(left.id == old.id)
        #expect(left.rides?.count == 2)
        #expect(left.batteryWh == 625)
    }

    @Test("A default bike with rides, a photo or an older bike before it stays")
    func keepsUsedBikes() throws {
        let owner = rider(createdAt: mac)
        let first = bike("Mein eBike", createdAt: mac, rider: owner)
        let used = bike("Cube", createdAt: phone, rider: owner)
        _ = ride("a", importedAt: phone, bike: used)
        try context.save()
        #expect(library.mergeSyncDuplicates().isEmpty)
        #expect(library.bikes().map(\.id).contains(first.id))
    }

    @Test("Both devices keep the same records, whichever runs first and whatever has synced")
    func sameChoiceEverywhere() throws {
        let a = rider(createdAt: mac), b = rider(createdAt: mac)
        let keeper = a.id.uuidString < b.id.uuidString ? a.id : b.id
        try context.save()
        library.mergeSyncDuplicates()
        #expect(try context.fetch(FetchDescriptor<Rider>()).map(\.id) == [keeper])
    }

    @Test("One goal per measure and period; the oldest stays")
    func goals() throws {
        let old = Goal(metric: .distance, period: .week, target: 100)
        old.createdAt = mac
        let new = Goal(metric: .distance, period: .week, target: 150)
        new.createdAt = phone
        let other = Goal(metric: .distance, period: .month, target: 400)
        [old, new, other].forEach(context.insert)
        try context.save()

        #expect(library.mergeSyncDuplicates().goals == 1)
        let left = try context.fetch(FetchDescriptor<Goal>())
        #expect(left.count == 2)
        #expect(left.contains { $0.id == old.id && $0.target == 100 })
    }

    @Test("The same export imported on both devices stays once, as imported first")
    func rides() throws {
        let owner = rider(createdAt: mac)
        let cube = bike("Cube", createdAt: mac, rider: owner)
        let first = ride("bosch-1", importedAt: mac, bike: cube)
        _ = ride("bosch-1", importedAt: phone, bike: cube)
        _ = ride("bosch-2", importedAt: phone, bike: cube)
        let gpxSame = ride("bosch-1", importedAt: phone, bike: cube)
        gpxSame.sourceFormat = "gpx"
        let noID = ride("", importedAt: phone, bike: cube)
        let noIDTwin = ride("", importedAt: phone, bike: cube)
        try context.save()

        #expect(library.mergeSyncDuplicates().rides == 1)
        let ids = try context.fetch(FetchDescriptor<Ride>()).map(\.id)
        #expect(ids.count == 5)
        #expect(ids.contains(first.id) && ids.contains(gpxSame.id) && ids.contains(noID.id) && ids.contains(noIDTwin.id))
    }

    @Test("A library without doubles is left alone")
    func nothingToDo() throws {
        let owner = rider(createdAt: mac)
        _ = bike("Mein eBike", createdAt: mac, rider: owner)
        _ = ride("a", importedAt: mac, bike: nil)
        try context.save()
        #expect(library.mergeSyncDuplicates().isEmpty)
        #expect(try count(Bike.self) == 1)
    }
}
