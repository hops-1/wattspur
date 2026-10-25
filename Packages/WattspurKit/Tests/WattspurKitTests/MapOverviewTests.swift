import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@Suite("Map of all rides: filter and visible area")
struct MapOverviewTests {
    private let start = Date(timeIntervalSince1970: 1_792_396_800)

    private func ride(_ points: [(Double, Double)], days: Double = 0, km: Double = 10, hours: Double = 0.5,
                      ascent: Int = 100, speed: Double = 5) -> MapRide {
        let route = OverviewRoute(segments: [points.map { RoutePoint(latitude: $0.0, longitude: $0.1) }])
        let figures = RideFigures(startDate: start.addingTimeInterval(days * 86_400), distance: km * 1000,
                                  timerTime: hours * 3600, totalAscent: ascent, averageSpeed: speed)
        return MapRide(id: UUID(), name: "Ride", figures: figures, route: route)!
    }

    private let area = GeoBounds(minLatitude: 49.80, maxLatitude: 49.90, minLongitude: 8.80, maxLongitude: 8.90)

    @Test("A line through the area counts even without a point inside it")
    func crossing() {
        #expect(area.intersects(from: RoutePoint(latitude: 49.85, longitude: 8.70), to: RoutePoint(latitude: 49.85, longitude: 9.00)))
        #expect(area.intersects(from: RoutePoint(latitude: 49.70, longitude: 8.85), to: RoutePoint(latitude: 50.00, longitude: 8.85)))
        #expect(!area.intersects(from: RoutePoint(latitude: 49.95, longitude: 8.70), to: RoutePoint(latitude: 49.95, longitude: 9.00)))
        // Diagonal past the corner.
        #expect(!area.intersects(from: RoutePoint(latitude: 49.95, longitude: 8.75), to: RoutePoint(latitude: 49.85, longitude: 8.70)))
    }

    @Test("Whole rides touching the area count with their totals, time-weighted averages")
    func tiles() {
        let inside = ride([(49.85, 8.85), (49.86, 8.86)], km: 20, hours: 1, ascent: 200, speed: 6)
        let through = ride([(49.85, 8.60), (49.85, 9.10)], km: 40, hours: 3, ascent: 300, speed: 4)
        let outside = ride([(48.00, 8.00), (48.10, 8.10)], km: 99, hours: 5)
        let overview = MapOverview(rides: [inside, through, outside])
        #expect(Set(overview.rides(touching: area).map(\.id)) == [inside.id, through.id])
        let tiles = overview.aggregate(touching: area)
        let expectedSpeed: Double = (6 * 3600 + 4 * 3 * 3600) / (4 * 3600)
        #expect(tiles.rideCount == 2)
        #expect(tiles.distance == 60_000)
        #expect(tiles.timerTime == 4 * 3600)
        #expect(tiles.ascent == 500)
        #expect(abs((tiles.averageSpeed ?? 0) - expectedSpeed) < 0.000_1)
    }

    @Test("Rides are newest first; the bounds cover all routes")
    func orderAndBounds() throws {
        let old = ride([(49.0, 8.0), (49.1, 8.1)], days: 0)
        let new = ride([(50.0, 9.0), (50.2, 9.3)], days: 3)
        let overview = MapOverview(rides: [old, new])
        #expect(overview.rides.map(\.id) == [new.id, old.id])
        let bounds = try #require(overview.bounds)
        #expect(bounds == GeoBounds(minLatitude: 49.0, maxLatitude: 50.2, minLongitude: 8.0, maxLongitude: 9.3))
        #expect(MapOverview(rides: []).bounds == nil)
    }

    @Test("Filter: period for all rides; selected rides ignore the period and may include the sample")
    func filter() {
        let id = UUID()
        let october = DateInterval(start: start, duration: 31 * 86_400)
        let period = MapFilter(interval: october)
        #expect(period.admits(id: id, startDate: start, countsInStatistics: true, isListed: true))
        #expect(!period.admits(id: id, startDate: start.addingTimeInterval(-86_400), countsInStatistics: true, isListed: true))
        // Sample ride, trash and parts never count in "all rides".
        #expect(!MapFilter().admits(id: id, startDate: start, countsInStatistics: false, isListed: true))

        let selected = MapFilter(interval: october, selectedIDs: [id])
        #expect(selected.admits(id: id, startDate: start.addingTimeInterval(-400 * 86_400), countsInStatistics: false, isListed: true))
        #expect(!selected.admits(id: UUID(), startDate: start, countsInStatistics: true, isListed: true))
        #expect(!selected.admits(id: id, startDate: start, countsInStatistics: false, isListed: false))
    }
}

@MainActor
@Suite("Map of all rides in the library")
struct MapOverviewLibraryTests {
    @Test("Sample ride only when selected, rides without GPS and still preparing are counted apart")
    func library() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let library = RideLibrary(context: container.mainContext)
        let data = try Fixture.data("reinheim-rundfahrt")
        let sample = try #require(library.importSample(data: data, name: "Sample"))
        library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: 1).anonymize(data), fileName: "A.fit")
        library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: 2).anonymize(data), fileName: "B.fit")
        library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: 3).anonymize(data), fileName: "C.fit")
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
        try #require(rides.count == 4)
        let others = rides.filter { !$0.isSample }
        // One ride without GPS, one still waiting for its route.
        others[0].overviewRouteData = nil
        others[1].overviewRouteVersion = 0

        let all = MapOverview(rides, filter: MapFilter())
        #expect(all.rides.map(\.id) == [others[2].id])
        #expect(all.withoutGPS == 1)
        #expect(all.preparing == 1)

        let selected = MapOverview(rides, filter: MapFilter(selectedIDs: [sample.id, others[2].id]))
        #expect(Set(selected.rides.map(\.id)) == [sample.id, others[2].id])
    }
}
