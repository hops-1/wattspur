import Foundation
import SwiftData
import Testing
@testable import WattspurKit

@Suite("Source filter")
struct SourceFilterTests {
    @Test("Stored text and filter convert both ways; anything else means all sources", arguments: ["", "x", "FIT ", "csv"])
    func storedValue(text: String) {
        #expect(SourceFilter(rawValue: text) ?? .all == .all)
        #expect(SourceFilter.all.rawValue == "")
    }

    @Test("The choices survive storing")
    func roundTrip() {
        for filter in SourceFilter.allCases {
            #expect(SourceFilter(rawValue: filter.rawValue) == filter)
        }
        #expect(SourceFilter.gpx.isActive && SourceFilter.fit.isActive)
        #expect(!SourceFilter.all.isActive)
    }

    @Test("All admits every ride; Bosch FIT admits everything that is not from a GPX file; GPX only those")
    func admits() {
        for source in [RideSource.fit, .gpx, nil] {
            #expect(SourceFilter.all.admits(source: source))
        }
        #expect(SourceFilter.fit.admits(source: .fit))
        #expect(SourceFilter.fit.admits(source: nil))
        #expect(!SourceFilter.fit.admits(source: .gpx))
        #expect(SourceFilter.gpx.admits(source: .gpx))
        #expect(!SourceFilter.gpx.admits(source: .fit))
        #expect(!SourceFilter.gpx.admits(source: nil))
    }

    @Test("Without a ride from a GPX file the filter does not apply")
    func resolved() {
        #expect(SourceFilter.gpx.resolved(hasGPXRides: true) == .gpx)
        #expect(SourceFilter.gpx.resolved(hasGPXRides: false) == .all)
        #expect(SourceFilter.fit.resolved(hasGPXRides: false) == .all)
        #expect(SourceFilter.all.resolved(hasGPXRides: true) == .all)
    }

    @Test("The map filter takes the source into account, but not for rides picked by hand")
    func mapFilter() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let onlyGPX = MapFilter(source: .gpx)
        #expect(onlyGPX.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, rideSource: .gpx))
        #expect(!onlyGPX.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, rideSource: .fit))
        #expect(!onlyGPX.admits(id: id, startDate: date, countsInStatistics: true, isListed: true))
        let noGPX = MapFilter(source: .fit)
        #expect(noGPX.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, rideSource: .fit))
        #expect(!noGPX.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, rideSource: .gpx))
        // Bike and source apply together.
        let bike = UUID()
        let both = MapFilter(bike: .bike(bike), source: .gpx)
        #expect(both.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, bikeID: bike, rideSource: .gpx))
        #expect(!both.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, bikeID: bike, rideSource: .fit))
        #expect(!both.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, bikeID: UUID(), rideSource: .gpx))
        // Picked by hand (from the list or the analysis): shown whatever the source.
        let picked = MapFilter(selectedIDs: [id], source: .gpx)
        #expect(picked.admits(id: id, startDate: date, countsInStatistics: true, isListed: true, rideSource: .fit))
    }
}

@MainActor
@Suite("Source filter and symbol on rides")
struct SourceFilterRideTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
    }

    private func rides() throws -> [Ride] {
        try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
    }

    @Test("A plain Bosch FIT has no symbol, a GPX ride has one, a Bosch ride with a GPX has the other")
    func badges() throws {
        library.importFile(data: try GPXFixture.fitData("pair-tour1-bosch-flow"), fileName: "Beispielrunde-aab0c480-caec-11f1-9fee-000463be1448.fit")
        library.importFile(data: try GPXFixture.data("pair-tour2-bosch-flow"), fileName: "tour2.gpx")
        let rides = try rides()
        #expect(rides.count == 2)
        let fit = try #require(rides.first { $0.source == .fit })
        let gpx = try #require(rides.first { $0.source == .gpx })
        #expect(fit.sourceBadge == nil)
        #expect(gpx.sourceBadge == .gpx)

        // The komoot file of tour 1 is attached to the Bosch ride.
        let result = library.importFile(data: try GPXFixture.data("pair-tour1-komoot"), fileName: "tour1-komoot.gpx")
        guard case .attached = result.outcome else {
            Issue.record("Expected attached, got \(result.outcome)")
            return
        }
        #expect(fit.sourceBadge == .attachedGPX)
        #expect(fit.source == .fit)
        // The ride still passes the Bosch filter, with its GPX.
        #expect(fit.isFromSource(.fit) && !fit.isFromSource(.gpx))
        #expect(gpx.isFromSource(.gpx) && !gpx.isFromSource(.fit))
        #expect(rides.filter { $0.isFromSource(.all) }.count == 2)
    }

    @Test("The map shows only the rides of the chosen source")
    func map() throws {
        library.importFile(data: try GPXFixture.fitData("pair-tour1-bosch-flow"), fileName: "Beispielrunde-aab0c480-caec-11f1-9fee-000463be1448.fit")
        library.importFile(data: try GPXFixture.data("pair-tour2-bosch-flow"), fileName: "tour2.gpx")
        let rides = try rides()
        #expect(MapOverview(rides, filter: MapFilter()).rides.count == 2)
        #expect(MapOverview(rides, filter: MapFilter(source: .gpx)).rides.count == 1)
        #expect(MapOverview(rides, filter: MapFilter(source: .fit)).rides.count == 1)
    }

    @Test("A ride from a file without power says so; one with power does not")
    func powerData() throws {
        library.importFile(data: try GPXFixture.fitData("pair-tour1-bosch-flow"), fileName: "Beispielrunde-aab0c480-caec-11f1-9fee-000463be1448.fit")
        library.importFile(data: try GPXFixture.data("pair-tour2-bosch-flow"), fileName: "tour2.gpx")
        let rides = try rides()
        #expect(try #require(rides.first { $0.source == .fit }).hasPowerData)
        #expect(try !#require(rides.first { $0.source == .gpx }).hasPowerData)
    }
}
