import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@Suite("Bike filter")
struct BikeFilterTests {
    let a = UUID()
    let b = UUID()

    @Test("Stored text and filter convert both ways; anything else means all bikes", arguments: ["", "x", "not-a-uuid", "12345"])
    func storedValue(text: String) {
        #expect(BikeFilter(rawValue: text) == .all)
        #expect(BikeFilter.all.rawValue == "")
    }

    @Test("A bike's filter survives storing")
    func roundTrip() {
        let filter = BikeFilter.bike(a)
        #expect(BikeFilter(rawValue: filter.rawValue) == filter)
        #expect(filter.bikeID == a)
        #expect(filter.isActive)
        #expect(!BikeFilter.all.isActive)
    }

    @Test("All admits every ride; a bike admits only its own, and not rides without a bike")
    func admits() {
        #expect(BikeFilter.all.admits(bikeID: a) && BikeFilter.all.admits(bikeID: nil))
        #expect(BikeFilter.bike(a).admits(bikeID: a))
        #expect(!BikeFilter.bike(a).admits(bikeID: b))
        #expect(!BikeFilter.bike(a).admits(bikeID: nil))
    }

    @Test("Without two bikes, or for a bike that is gone, the filter does not apply")
    func resolved() {
        #expect(BikeFilter.bike(a).resolved(knownBikeIDs: [a, b]) == .bike(a))
        #expect(BikeFilter.bike(a).resolved(knownBikeIDs: [a]) == .all)
        #expect(BikeFilter.bike(a).resolved(knownBikeIDs: [b, UUID()]) == .all)
        #expect(BikeFilter.all.resolved(knownBikeIDs: [a, b]) == .all)
    }

    @Test("The map filter takes the bike into account, but not for rides picked by hand")
    func mapFilter() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let onBike = MapFilter(bike: .bike(a))
        #expect(onBike.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, bikeID: a))
        #expect(!onBike.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, bikeID: b))
        #expect(!onBike.admits(id: id, startDate: date, countsInStatistics: true, isListed: true))
        // Picked by hand (from the list or the analysis): shown whatever the bike.
        let picked = MapFilter(selectedIDs: [id], bike: .bike(a))
        #expect(picked.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, bikeID: b))
    }
}

@MainActor
@Suite("Bike filter on rides")
struct BikeFilterRideTests {
    @Test("Rides are told apart by their bike, also for the map")
    func ridesAndMap() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let library = RideLibrary(context: container.mainContext)
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        let data = try Fixture.data("reinheim-rundfahrt")
        for weeks in 1...3 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: weeks).anonymize(data), fileName: "R\(weeks).fit")
        }
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
        library.assign([rides[0]], to: gravel)
        #expect(rides.filter { $0.isOnBike(.bike(gravel.id)) }.count == 1)
        #expect(rides.filter { $0.isOnBike(.bike(first.id)) }.count == 2)
        #expect(rides.filter { $0.isOnBike(.all) }.count == 3)

        let onGravel = MapOverview(rides, filter: MapFilter(bike: .bike(gravel.id)))
        #expect(onGravel.rides.map(\.id) == [rides[0].id])
        #expect(MapOverview(rides, filter: MapFilter(bike: .bike(first.id))).rides.count == 2)
        #expect(MapOverview(rides, filter: MapFilter()).rides.count == 3)
    }
}
