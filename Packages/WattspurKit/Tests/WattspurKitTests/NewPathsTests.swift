import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@Suite("New paths")
struct NewPathsTests {
    private let plane = RouteSimplifier.LocalPlane(origin: RoutePoint(latitude: 49.83, longitude: 8.83))
    private let start = Date(timeIntervalSince1970: 1_792_396_800)

    private func at(_ east: Double, _ north: Double) -> RoutePoint {
        RoutePoint(latitude: 49.83 + north / plane.metresPerDegreeLatitude,
                   longitude: 8.83 + east / plane.metresPerDegreeLongitude)
    }

    private func input(_ segments: [[RoutePoint]], days: Double) -> NewPaths.Input {
        NewPaths.Input(id: UUID(), startDate: start.addingTimeInterval(days * 86_400), route: OverviewRoute(segments: segments))
    }

    @Test("The first ride is all new, the same road again is not")
    func repeatRide() throws {
        let first = input([[at(0, 0), at(2_000, 0)]], days: 0)
        let again = input([[at(0, 0), at(2_000, 0)]], days: 1)
        let results = NewPaths.compute([again, first])
        let a = try #require(results[first.id]), b = try #require(results[again.id])
        #expect(abs(a.routeLength - 2_000) < 2)
        #expect(a.share > 0.99)
        #expect(a.stretches.count == 1)
        #expect(b.share < 0.01)
        #expect(b.stretches.isEmpty)
    }

    @Test("GPS noise of a few metres on the same road is not new; a road 120 m away is")
    func noiseAndParallel() throws {
        let road = input([[at(0, 0), at(2_000, 0)]], days: 0)
        let noisy = input([[at(0, 6), at(500, -7), at(1_000, 8), at(1_500, -6), at(2_000, 5)]], days: 1)
        let parallel = input([[at(0, 120), at(2_000, 120)]], days: 2)
        let results = NewPaths.compute([road, noisy, parallel])
        #expect((results[noisy.id]?.share ?? 1) < 0.05)
        #expect((results[parallel.id]?.share ?? 0) > 0.95)
    }

    @Test("Half new: the known half and the new half, with the new stretch for the map")
    func halfNew() throws {
        let known = input([[at(0, 0), at(1_000, 0)]], days: 0)
        let longer = input([[at(0, 0), at(1_000, 0), at(1_000, 1_000)]], days: 1)
        let result = try #require(NewPaths.compute([known, longer])[longer.id])
        #expect(abs(result.share - 0.5) < 0.05)
        #expect(result.stretches.count == 1)
        let stretch = try #require(result.stretches.first)
        let end = plane.project(try #require(stretch.last))
        #expect(abs(end.x - 1_000) < 1 && abs(end.y - 1_000) < 1)
    }

    @Test("Out and back on a new road counts both ways: the ride's own cells become known afterwards")
    func outAndBack() throws {
        let ride = input([[at(0, 0), at(1_000, 0), at(0, 0)]], days: 0)
        #expect((NewPaths.compute([ride])[ride.id]?.share ?? 0) > 0.99)
    }

    @Test("1 000 rides of about 15 km in one go")
    func manyRides() {
        var generator = SystemRandomNumberGenerator()
        let rides = (0..<1_000).map { i in
            var east = Double.random(in: -3_000...3_000, using: &generator)
            var north = Double.random(in: -3_000...3_000, using: &generator)
            let points = (0..<300).map { _ in
                east += Double.random(in: -60...60, using: &generator)
                north += Double.random(in: -60...60, using: &generator)
                return at(east, north)
            }
            return input([points], days: Double(i))
        }
        let clock = ContinuousClock()
        var count = 0
        let elapsed = clock.measure { count = NewPaths.compute(rides).count }
        #expect(count == 1_000)
        let limit: Duration = .seconds(5)
        #expect(elapsed < limit, "New paths for 1 000 rides took \(elapsed)")
    }
}

@MainActor
@Suite("New paths in the library")
struct NewPathsLibraryTests {
    @Test("Parts of a merged ride take part with their own start; sample ride and trash do not")
    func inputs() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let library = RideLibrary(context: container.mainContext)
        let data = try Fixture.data("reinheim-rundfahrt")
        let sample = try #require(library.importSample(data: data, name: "Sample"))
        for week in 1...3 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: week).anonymize(data),
                               fileName: "W\(week).fit")
        }
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
            .filter { !$0.isSample }
        try #require(rides.count == 3)
        let merged = try library.merge([rides[0], rides[1]], name: "Zwei")
        library.moveToTrash(rides[2])

        let all = try container.mainContext.fetch(FetchDescriptor<Ride>())
        let ids = Set(Ride.newPathInputs(all).map(\.id))
        #expect(ids == [rides[0].id, rides[1].id])
        #expect(!ids.contains(merged.id) && !ids.contains(sample.id))

        // The same route a week later: the second part rides only known paths.
        let results = NewPaths.compute(Ride.newPathInputs(all))
        #expect((results[rides[0].id]?.share ?? 0) > 0.99)
        #expect((results[rides[1].id]?.share ?? 1) < 0.01)
    }
}
