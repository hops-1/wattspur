import Foundation
import SwiftData
import Testing
@testable import WattspurKit

@Suite("Overview routes for the map of all rides")
struct OverviewRouteTests {
    /// Points on a line going north from Reinheim, `step` metres apart, with `offsets` metres to the east.
    private func points(_ offsets: [Double], step: Double = 100) -> [RoutePoint] {
        let plane = RouteSimplifier.LocalPlane(origin: RoutePoint(latitude: 49.83, longitude: 8.83))
        return offsets.enumerated().map { i, east in
            RoutePoint(latitude: 49.83 + Double(i) * step / plane.metresPerDegreeLatitude,
                       longitude: 8.83 + east / plane.metresPerDegreeLongitude)
        }
    }

    /// Largest distance of any original point from the simplified line, in metres.
    private func maxDeviation(_ original: [RoutePoint], _ simplified: [RoutePoint]) -> Double {
        let plane = RouteSimplifier.LocalPlane(origin: original[0])
        let line = simplified.map(plane.project)
        return original.map(plane.project).map { p in
            zip(line, line.dropFirst()).map { RouteSimplifier.distanceToSegment(p, $0, $1) }.min() ?? 0
        }.max() ?? 0
    }

    @Test("A straight line keeps only start and end")
    func straightLine() {
        let line = points(Array(repeating: 0, count: 50))
        #expect(RouteSimplifier.simplify(line, tolerance: 5) == [line[0], line[49]])
    }

    @Test("Corners beyond the tolerance stay, wiggles within it go")
    func corners() {
        let wiggle = points([0, 3, 0, -3, 0])
        #expect(RouteSimplifier.simplify(wiggle, tolerance: 5).count == 2)
        let zigzag = points([0, 40, 0, 40, 0])
        #expect(RouteSimplifier.simplify(zigzag, tolerance: 5) == zigzag)
    }

    @Test("A loop whose start and end meet keeps its far side")
    func loop() {
        let plane = RouteSimplifier.LocalPlane(origin: RoutePoint(latitude: 49.83, longitude: 8.83))
        let circle = (0...36).map { i in
            let angle = Double(i) / 36 * 2 * .pi
            return RoutePoint(latitude: 49.83 + 500 * sin(angle) / plane.metresPerDegreeLatitude,
                              longitude: 8.83 + 500 * (1 - cos(angle)) / plane.metresPerDegreeLongitude)
        }
        let simplified = RouteSimplifier.simplify(circle, tolerance: 5)
        #expect(simplified.count > 10)
        #expect(maxDeviation(circle, simplified) <= 5.5)
    }

    @Test("Empty, single and repeated points; samples without GPS give no route")
    func edgeCases() {
        #expect(RouteSimplifier.simplify([], tolerance: 5).isEmpty)
        let one = points([0])
        #expect(RouteSimplifier.simplify(one, tolerance: 5) == one)
        #expect(RouteSimplifier.simplify(one + one + one, tolerance: 5) == one)
        let noGPS = OverviewRoute(samples: [RideSample(time: 0, distance: 0), RideSample(time: 1, distance: 5)])
        #expect(noGPS.isEmpty)
        #expect(OverviewRoute(samplesData: nil).isEmpty)
    }

    @Test("The sample ride: every GPS point within 5 m, far fewer points")
    func sampleRide() throws {
        let ride = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
        let all = RideSeries.route(from: ride.samples, maxPoints: .max)
        let route = OverviewRoute(samples: ride.samples)
        let simplified = try #require(route.segments.first)
        #expect(route.segments.count == 1)
        #expect(simplified.first == all.first)
        #expect(simplified.last == all.last)
        // The test measures in a plane around the start, the simplifier around the middle latitude.
        let slack = 0.5
        #expect(maxDeviation(all, simplified) <= OverviewRoute.tolerance + slack)
        #expect(simplified.count > 50)
        #expect(simplified.count < all.count / 5)
        // A few kB, small enough to stay inline in SwiftData.
        #expect(route.encoded().count < 4_000)
    }

    @Test("Encoding round trip: segments kept, about 0.1 m precision, also west and south")
    func encoding() throws {
        let route = OverviewRoute(segments: [
            points([0, 40, 0, 40]),
            [RoutePoint(latitude: -33.856_784_3, longitude: -70.651_234_9), RoutePoint(latitude: -33.86, longitude: -70.65)],
        ])
        let decoded = try #require(OverviewRoute(data: route.encoded()))
        #expect(decoded.segments.map(\.count) == [4, 2])
        let pairs = zip(route.segments.joined(), decoded.segments.joined())
        let maxError: Double = pairs.map { max(abs($0.latitude - $1.latitude), abs($0.longitude - $1.longitude)) }.max() ?? 1
        #expect(maxError <= 0.000_000_5)
    }

    @Test("Broken or cut data is rejected")
    func brokenData() {
        let data = OverviewRoute(segments: [points([0, 40, 0])]).encoded()
        #expect(OverviewRoute(data: data.dropLast()) == nil)
        #expect(OverviewRoute(data: data + Data([1])) == nil)
        #expect(OverviewRoute(data: Data([9]) + data.dropFirst()) == nil)
        #expect(OverviewRoute(data: Data()) == nil)
    }

    @Test("Joining keeps one segment per part, so no line crosses the gap")
    func joining() {
        let a = OverviewRoute(segments: [points([0, 40, 0])])
        let b = OverviewRoute(segments: [points([500, 540])])
        let joined = OverviewRoute(joining: [a, OverviewRoute(segments: []), b])
        #expect(joined.segments == a.segments + b.segments)
    }

    @Test("1 000 stored routes decode quickly")
    func manyRoutes() throws {
        // A random walk of 400 points per ride, about the size of a 20 km ride after simplifying.
        var generator = SystemRandomNumberGenerator()
        let encoded = (0..<1_000).map { _ in
            var lat = 49.8, lon = 8.8
            let segment = (0..<400).map { _ in
                lat += Double.random(in: -0.000_5...0.000_5, using: &generator)
                lon += Double.random(in: -0.000_8...0.000_8, using: &generator)
                return RoutePoint(latitude: lat, longitude: lon)
            }
            return OverviewRoute(segments: [segment]).encoded()
        }
        let clock = ContinuousClock()
        var points = 0
        let elapsed = clock.measure {
            for data in encoded { points += OverviewRoute(data: data)?.pointCount ?? 0 }
        }
        #expect(points == 400_000)
        let limit: Duration = .seconds(1)
        #expect(elapsed < limit, "Decoding 1 000 routes took \(elapsed)")
    }
}

@MainActor
@Suite("Overview routes in the library")
struct OverviewRouteLibraryTests {
    let container: ModelContainer
    let library: RideLibrary
    let first: Data
    let second: Data

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        first = try Fixture.data("reinheim-rundfahrt")
        second = try FITAnonymizer(latitudeOffset: 0.01, longitudeOffset: 0, weeks: 1).anonymize(first)
    }

    private func importBoth() throws -> (Ride, Ride) {
        library.importFile(data: first, fileName: "Reinheim Rundfahrt.fit")
        library.importFile(data: second, fileName: "Heimweg.fit")
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
        try #require(rides.count == 2)
        return (rides[0], rides[1])
    }

    @Test("Import stores the route with the current version")
    func importStoresRoute() throws {
        let (a, _) = try importBoth()
        #expect(a.overviewRouteVersion == OverviewRoute.version)
        #expect(!a.needsOverviewRoute)
        let route = try #require(a.overviewRoute)
        #expect(route.segments.count == 1)
        #expect(route.pointCount > 50)
    }

    @Test("A merged ride has one segment per part; splitting leaves the parts' routes")
    func mergeAndSplit() throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([a, b], name: "Zwei Teile")
        let route = try #require(merged.overviewRoute)
        #expect(route.segments == (a.overviewRoute?.segments ?? []) + (b.overviewRoute?.segments ?? []))
        library.split(merged)
        #expect(a.overviewRoute?.segments.count == 1)
        #expect(b.overviewRoute?.segments.count == 1)
    }

    @Test("Rides from before v1.4 get their route once, local edits stay")
    func prepareExisting() async throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([a, b], name: "Zwei Teile")
        let expected = try #require(merged.overviewRoute)
        library.rename(merged, to: "Meine Runde")
        for ride in [a, b, merged] {
            ride.overviewRouteData = nil
            ride.overviewRouteVersion = 0
        }
        try container.mainContext.save()

        var reports: [Int] = []
        let count = await library.prepareOverviewRoutes(batchSize: 1) { done, total in
            #expect(total == 3)
            reports.append(done)
        }
        #expect(count == 3)
        #expect(reports.first == 0)
        #expect(reports.last == 3)
        #expect(merged.overviewRoute == expected)
        #expect(a.overviewRoute?.segments.count == 1)
        #expect(merged.name == "Meine Runde")
        #expect(await library.prepareOverviewRoutes() == 0)
    }

    @Test("A ride without GPS is marked as done with no route")
    func withoutGPS() async throws {
        let (a, _) = try importBoth()
        a.samplesData = nil
        a.overviewRouteVersion = 0
        #expect(await library.prepareOverviewRoutes() == 1)
        #expect(a.overviewRouteVersion == OverviewRoute.version)
        #expect(a.overviewRouteData == nil)
        #expect(a.overviewRoute?.isEmpty == true)
    }
}
