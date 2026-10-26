import Foundation
import Testing
import TestFixtures
@testable import WattspurCore

/// Routes for the tests: made up, around Reinheim, never real rides (NFR-01, NFR-12).
private enum Routes {
    static let metre = 1.0 / 111_195

    /// A winding route of about 4 km from south-west to north-east.
    static func winding(shiftNorth: Double = 0, shiftEast: Double = 0, points: Int = 400, noise: Double = 0,
                        seed: UInt64 = 7) -> OverviewRoute {
        var random = Random(seed: seed)
        let line = (0..<points).map { i -> RoutePoint in
            let t = Double(i) / Double(points - 1)
            return RoutePoint(
                latitude: 50 + t * 0.03 + 0.003 * sin(t * 12) + shiftNorth * metre + random.jitter(noise) * metre,
                longitude: 9 + t * 0.02 + 0.002 * cos(t * 9) + shiftEast * metre / cos(50 * .pi / 180) + random.jitter(noise) * metre / cos(50 * .pi / 180))
        }
        return OverviewRoute(segments: [line])
    }

    /// A round loop of the given radius that starts at the east point of the circle, turned on by
    /// `startAngle` radians; ridden counter-clockwise or clockwise.
    static func loop(radius: Double = 800, counterClockwise: Bool = true, startAngle: Double = 0,
                     turns: Double = 1, points: Int = 240) -> OverviewRoute {
        let line = (0..<points).map { i -> RoutePoint in
            let t = Double(i) / Double(points - 1) * turns * 2 * .pi
            let angle = startAngle + (counterClockwise ? t : -t)
            return RoutePoint(latitude: 50 + radius * sin(angle) * metre,
                              longitude: 9 + radius * cos(angle) * metre / cos(50 * .pi / 180))
        }
        return OverviewRoute(segments: [line])
    }

    /// The route ridden to the end and back on the same road.
    static func outAndBack(_ route: OverviewRoute) -> OverviewRoute {
        let line = route.segments[0]
        return OverviewRoute(segments: [line + line.reversed().dropFirst()])
    }

    static func reversed(_ route: OverviewRoute) -> OverviewRoute {
        OverviewRoute(segments: route.segments.reversed().map { Array($0.reversed()) })
    }

    static func prefix(_ route: OverviewRoute, share: Double) -> OverviewRoute {
        let line = route.segments[0]
        return OverviewRoute(segments: [Array(line.prefix(Int(Double(line.count) * share)))])
    }

    /// The same route with a detour of `metres` to the east in a middle part.
    static func detour(_ route: OverviewRoute, from: Double, to: Double, metres: Double) -> OverviewRoute {
        let line = route.segments[0]
        let moved = line.enumerated().map { i, p -> RoutePoint in
            let t = Double(i) / Double(line.count - 1)
            guard t >= from, t <= to else { return p }
            let bump = sin((t - from) / (to - from) * .pi)
            return RoutePoint(latitude: p.latitude, longitude: p.longitude + bump * metres * metre / cos(50 * .pi / 180))
        }
        return OverviewRoute(segments: [moved])
    }

    struct Random {
        var seed: UInt64
        mutating func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(1 << 31)
        }
        mutating func jitter(_ amount: Double) -> Double { (next() - 0.5) * 2 * amount }
    }
}

private func signature(_ route: OverviewRoute) throws -> RouteSignature {
    try #require(RouteSignature(route))
}

private func match(_ a: OverviewRoute, _ b: OverviewRoute) throws -> RouteSimilarity.Match {
    RouteSimilarity.compare(try signature(a), try signature(b))
}

@Suite("Route signature")
struct RouteSignatureTests {
    @Test("A route gets points every 10 m and its length")
    func spacing() throws {
        let s = try signature(Routes.winding())
        #expect(s.length > 3_500 && s.length < 6_500)
        #expect(abs(Double(s.xs.count) - s.length / RouteSignature.spacing) < 5)
    }

    @Test("An empty route, a single point and a few metres have no signature")
    func tooSmall() {
        #expect(RouteSignature(OverviewRoute(segments: [])) == nil)
        #expect(RouteSignature(OverviewRoute(segments: [[RoutePoint(latitude: 50, longitude: 9)]])) == nil)
        let short = OverviewRoute(segments: [[RoutePoint(latitude: 50, longitude: 9), RoutePoint(latitude: 50.0004, longitude: 9)]])
        #expect(RouteSignature(short) == nil) // 44 m
    }

    @Test("The gap between the parts of a merged ride is not part of the route")
    func gapIsNoRoute() throws {
        let a = [RoutePoint(latitude: 50, longitude: 9), RoutePoint(latitude: 50.01, longitude: 9)]
        let b = [RoutePoint(latitude: 50.1, longitude: 9), RoutePoint(latitude: 50.11, longitude: 9)]
        let s = try signature(OverviewRoute(segments: [a, b]))
        #expect(abs(s.length - 2_224) < 30)
    }

    @Test("Loops know their way round, out-and-back rides do not")
    func orientation() throws {
        #expect(try signature(Routes.loop(counterClockwise: true)).orientation == 1)
        #expect(try signature(Routes.loop(counterClockwise: false)).orientation == -1)
        #expect(try signature(Routes.outAndBack(Routes.winding())).orientation == 0)
    }
}

@Suite("Route similarity")
struct RouteSimilarityTests {
    @Test("A route is entirely similar to itself and runs the same way")
    func itself() throws {
        let m = try match(Routes.winding(), Routes.winding())
        #expect(m.score > 0.999)
        #expect(m.direction == .same)
    }

    @Test("The same route ridden the other way scores the same and runs reverse")
    func commuteBack() throws {
        let m = try match(Routes.winding(), Routes.reversed(Routes.winding()))
        #expect(m.score > 0.999)
        #expect(m.direction == .reverse)
        #expect(!m.isSimilar(threshold: 0.95, includeReverse: false))
        #expect(m.isSimilar(threshold: 0.95, includeReverse: true))
    }

    @Test("A few metres of GPS noise do not matter, a route 150 m to the side is mostly another route")
    func noiseAndOffset() throws {
        #expect(try match(Routes.winding(), Routes.winding(noise: 8, seed: 3)).score > 0.97)
        #expect(try match(Routes.winding(), Routes.winding(noise: 20, seed: 5)).score > 0.9)
        #expect(try match(Routes.winding(), Routes.winding(shiftNorth: 150)).score < 0.5)
        #expect(try match(Routes.winding(), Routes.winding(shiftNorth: 300)).score < 0.3)
        #expect(try match(Routes.winding(), Routes.winding(shiftNorth: 30)).score > 0.99)
    }

    @Test("A detour lowers the score by the share of the detour")
    func detour() throws {
        let base = Routes.winding()
        let m = try match(base, Routes.detour(base, from: 0.4, to: 0.6, metres: 400))
        #expect(m.score > 0.55 && m.score < 0.85)
        #expect(m.direction == .same)
        #expect(!m.isSimilar(threshold: 0.95, includeReverse: true))
    }

    @Test("A ride that stops early is not similar, and neither is a part of a longer one")
    func partOfARoute() throws {
        let base = Routes.winding()
        let stopped = try match(base, Routes.prefix(base, share: 0.85))
        #expect(stopped.score > 0.8 && stopped.score < 0.9) // the shorter one is covered, the longer one is not
        let half = try match(base, Routes.prefix(base, share: 0.5))
        #expect(half.score > 0.4 && half.score < 0.6)
        #expect(half.direction == .none) // the ends do not fit
        #expect(!half.isSimilar(threshold: 0.2, includeReverse: true))
    }

    @Test("A ride that starts a long way later does not run the same way, even if the rest fits")
    func startsElsewhere() throws {
        let base = Routes.winding()
        let line = base.segments[0]
        let late = OverviewRoute(segments: [Array(line.dropFirst(Int(Double(line.count) * 0.02)))]) // about 150 m
        #expect(try match(base, late).direction == .same)
        let later = OverviewRoute(segments: [Array(line.dropFirst(Int(Double(line.count) * 0.12)))]) // about 900 m
        #expect(try match(base, later).direction == .none)
    }

    @Test("Another place far away is not similar")
    func farAway() throws {
        let base = Routes.winding()
        let elsewhere = OverviewRoute(segments: [base.segments[0].map { RoutePoint(latitude: $0.latitude + 0.5, longitude: $0.longitude + 0.5) }])
        #expect(try match(base, elsewhere).score == 0)
    }

    @Test("Loops: the same way round is the same, the other way is reverse, another start has no direction")
    func loops() throws {
        let ccw = Routes.loop()
        let same = try match(ccw, Routes.loop())
        #expect(same.score > 0.99 && same.direction == .same)
        let other = try match(ccw, Routes.loop(counterClockwise: false))
        #expect(other.score > 0.99 && other.direction == .reverse)
        // The start moved a quarter of the way round the circle: 1 250 m away.
        let rotated = try match(ccw, Routes.loop(startAngle: .pi / 2))
        #expect(rotated.score > 0.95 && rotated.direction == .none)
    }

    @Test("A ride out and back on one road is similar to itself and to a shorter ride on that road only as far as it goes")
    func outAndBack() throws {
        let road = Routes.outAndBack(Routes.winding())
        #expect(try match(road, road).direction == .same)
        #expect(try match(road, Routes.outAndBack(Routes.winding(noise: 5, seed: 2))).score > 0.97)
        let shorter = Routes.outAndBack(Routes.prefix(Routes.winding(), share: 0.5))
        #expect(try match(road, shorter).score < 0.6)
    }

    @Test("The early exit agrees with the full comparison")
    func earlyExit() throws {
        let a = try signature(Routes.winding())
        let near = try signature(Routes.winding(noise: 8, seed: 3))
        let far = try signature(Routes.winding(shiftNorth: 150))
        #expect(RouteSimilarity.compare(a, near, atLeast: 0.95)?.score == RouteSimilarity.compare(a, near).score)
        #expect(RouteSimilarity.compare(a, far, atLeast: 0.95) == nil)
    }
}

@Suite("Route index")
struct RouteIndexTests {
    /// A family of rides: a few commutes from different places, each ridden several times with
    /// a little noise, some of them back, some with a detour.
    private func library(rides: Int, seed: UInt64 = 11) -> [(id: UUID, route: OverviewRoute)] {
        var random = Routes.Random(seed: seed)
        return (0..<rides).map { i in
            let family = i % 8
            var route = Routes.winding(shiftNorth: Double(family) * 700, shiftEast: Double(family % 3) * 900,
                                       points: 300, noise: 6, seed: UInt64(100 + i))
            switch Int(random.next() * 10) {
            case 0: route = Routes.reversed(route)
            case 1: route = Routes.detour(route, from: 0.3, to: 0.5, metres: 300)
            case 2: route = Routes.prefix(route, share: 0.6)
            default: break
            }
            return (UUID(), route)
        }
    }

    private func bruteForce(_ rides: [(id: UUID, route: OverviewRoute)], to index: Int, threshold: Double,
                            includeReverse: Bool) -> Set<UUID> {
        let reference = RouteSignature(rides[index].route)!
        var ids = Set<UUID>()
        for (i, ride) in rides.enumerated() where i != index {
            guard let other = RouteSignature(ride.route) else { continue }
            if RouteSimilarity.compare(reference, other).isSimilar(threshold: threshold, includeReverse: includeReverse) {
                ids.insert(ride.id)
            }
        }
        return ids
    }

    @Test("The index finds exactly the rides a comparison with every ride finds")
    func agreesWithBruteForce() {
        let rides = library(rides: 160)
        var index = RouteIndex()
        for ride in rides { index.insert(ride.id, route: ride.route) }
        #expect(index.count == 160)
        for (threshold, reverse) in [(0.95, false), (0.95, true), (0.85, true)] {
            for i in stride(from: 0, to: rides.count, by: 17) {
                let expected = bruteForce(rides, to: i, threshold: threshold, includeReverse: reverse)
                let found = Set(index.similar(to: rides[i].id, threshold: threshold, includeReverse: reverse).map(\.id))
                #expect(found == expected, "ride \(i), threshold \(threshold), reverse \(reverse)")
            }
        }
    }

    @Test("Hits come best first, without the ride itself, and the other way only on request")
    func order() throws {
        let base = Routes.winding()
        var index = RouteIndex()
        let ids = (0..<5).map { _ in UUID() }
        index.insert(ids[0], route: base)
        index.insert(ids[1], route: Routes.detour(base, from: 0.45, to: 0.5, metres: 120)) // a little less than 100 %
        index.insert(ids[2], route: Routes.winding(noise: 4, seed: 4))
        index.insert(ids[3], route: Routes.reversed(base))
        index.insert(ids[4], route: Routes.winding(shiftNorth: 2_000))

        let forward = index.similar(to: ids[0], threshold: 0.9)
        #expect(forward.map(\.id) == [ids[2], ids[1]])
        #expect(forward[0].score > forward[1].score)
        #expect(forward[1].score > 0.9)

        let both = index.similar(to: ids[0], threshold: 0.9, includeReverse: true)
        #expect(Set(both.map(\.id)) == [ids[1], ids[2], ids[3]])
        #expect(both.first { $0.id == ids[3] }?.direction == .reverse)
        #expect(!both.contains { $0.id == ids[0] })
    }

    @Test("Replacing and removing rides keeps the index right")
    func changes() {
        let base = Routes.winding()
        var index = RouteIndex()
        let a = UUID(), b = UUID(), c = UUID()
        index.insert(a, route: base)
        index.insert(b, route: base)
        #expect(index.similar(to: a).map(\.id) == [b])

        index.insert(b, route: Routes.winding(shiftNorth: 3_000)) // the ride moved away
        #expect(index.similar(to: a).isEmpty)

        index.insert(b, route: base)
        index.remove(b)
        #expect(!index.contains(b) && index.count == 1)
        #expect(index.similar(to: a).isEmpty)
        #expect(index.similar(to: b).isEmpty)

        index.insert(c, route: base) // takes the free slot of b
        #expect(index.similar(to: a).map(\.id) == [c])

        index.insert(c, route: OverviewRoute(segments: [])) // no route any more
        #expect(!index.contains(c))
    }

    @Test("A thousand rides: building and asking take well under a second")
    func manyRides() {
        let rides = library(rides: 1_000, seed: 5)
        let clock = ContinuousClock()
        var index = RouteIndex()
        let build = clock.measure { for ride in rides { index.insert(ride.id, route: ride.route) } }
        var hits = 0
        let ask = clock.measure {
            for i in stride(from: 0, to: rides.count, by: 100) {
                hits += index.similar(to: rides[i].id, threshold: 0.9, includeReverse: true).count
            }
        }
        #expect(hits > 0)
        #expect(build < .seconds(8))
        // Ten questions; one must stay far below the second of ROUTE-08.
        #expect(ask < .seconds(3), "ten questions took \(ask)")
    }
}

@Suite("Similarity threshold")
struct SimilarityThresholdTests {
    @Test("A threshold stays within 80–99 %; a damaged value becomes the default")
    func clamped() {
        #expect(RouteSimilarity.clampedThreshold(0.95) == 0.95)
        #expect(RouteSimilarity.clampedThreshold(0.5) == 0.80)
        #expect(RouteSimilarity.clampedThreshold(1.2) == 0.99)
        #expect(RouteSimilarity.clampedThreshold(.nan) == RouteSimilarity.defaultThreshold)
        #expect(RouteSimilarity.clampedThreshold(.infinity) == RouteSimilarity.defaultThreshold)
    }
}

@Suite("Route similarity on recorded tours")
struct RecordedRouteSimilarityTests {
    private func route(gpx name: String) throws -> OverviewRoute {
        OverviewRoute(samples: try GPXRideImporter().parse(GPXFixture.data(name)).samples)
    }

    private func route(fit name: String) throws -> OverviewRoute {
        OverviewRoute(samples: try FITRideImporter().parse(GPXFixture.fitData(name)).samples)
    }

    /// The same tour from the Bosch FIT file, the Bosch GPX and komoot: the three recordings
    /// are the same route, whichever device wrote them (the anonymized files of V-11).
    @Test("One tour recorded three ways is the same route; another tour is not")
    func pairs() throws {
        let fit = try route(fit: "pair-tour1-bosch-flow")
        let gpx = try route(gpx: "pair-tour1-bosch-flow")
        let komoot = try route(gpx: "pair-tour1-komoot")
        for (name, other) in [("Bosch GPX", gpx), ("komoot", komoot)] {
            let m = try match(fit, other)
            #expect(m.score > 0.97, "\(name): \(m)")
            #expect(m.direction == .same, "\(name): \(m)")
        }
        let second = try route(fit: "pair-tour2-bosch-flow")
        #expect(try match(fit, second).score < 0.5)
    }
}
