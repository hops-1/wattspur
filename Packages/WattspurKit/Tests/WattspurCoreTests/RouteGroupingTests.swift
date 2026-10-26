import Foundation
import Testing
@testable import WattspurCore

/// Routes for the tests: made up, around Reinheim, never real rides (NFR-01, NFR-12).
private enum Roads {
    static let metre = 1.0 / 111_195

    /// A winding road of about 4 km; `family` moves it so that different families do not touch.
    static func road(family: Int = 0, noise: Double = 5, seed: UInt64 = 1, points: Int = 300) -> OverviewRoute {
        var state = seed &* 7_919 &+ 13
        func jitter() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return (Double(state >> 33) / Double(1 << 31) - 0.5) * 2 * noise
        }
        let north = Double(family) * 700, east = Double(family % 3) * 900
        let cosLat = cos(50 * Double.pi / 180)
        let line = (0..<points).map { i -> RoutePoint in
            let t = Double(i) / Double(points - 1)
            return RoutePoint(
                latitude: 50 + t * 0.03 + 0.003 * sin(t * 12) + (north + jitter()) * metre,
                longitude: 9 + t * 0.02 + 0.002 * cos(t * 9) + (east + jitter()) * metre / cosLat)
        }
        return OverviewRoute(segments: [line])
    }

    static func reversed(_ route: OverviewRoute) -> OverviewRoute {
        OverviewRoute(segments: route.segments.reversed().map { Array($0.reversed()) })
    }

    /// The road with a long detour in the middle: a different route.
    static func detour(_ route: OverviewRoute, metres: Double) -> OverviewRoute {
        let line = route.segments[0]
        let moved = line.enumerated().map { i, p -> RoutePoint in
            let t = Double(i) / Double(line.count - 1)
            guard t >= 0.2, t <= 0.8 else { return p }
            let bump = sin((t - 0.2) / 0.6 * .pi)
            return RoutePoint(latitude: p.latitude + bump * metres * metre, longitude: p.longitude)
        }
        return OverviewRoute(segments: [moved])
    }
}

@Suite("Route grouping")
struct RouteGroupingTests {
    /// `count` rides on road `family`, `reversed` of them the other way round.
    private func rides(family: Int, count: Int, reversed: Int = 0, seed: UInt64 = 1) -> [(id: UUID, route: OverviewRoute)] {
        (0..<count).map { i in
            let road = Roads.road(family: family, seed: seed &+ UInt64(i))
            return (UUID(), i < reversed ? Roads.reversed(road) : road)
        }
    }

    private func index(_ rides: [(id: UUID, route: OverviewRoute)]) -> RouteIndex {
        var index = RouteIndex()
        for ride in rides { index.insert(ride.id, route: ride.route) }
        return index
    }

    @Test("Three rides on one road are offered as a route, two are not")
    func minimum() {
        let three = rides(family: 0, count: 3)
        let suggestions = RouteGrouping.suggest(in: index(three), candidates: three.map(\.id))
        #expect(suggestions.count == 1)
        #expect(Set(suggestions[0].members) == Set(three.map(\.id)))
        #expect(suggestions[0].members.first == suggestions[0].reference)

        let two = Array(three.prefix(2))
        #expect(RouteGrouping.suggest(in: index(two), candidates: two.map(\.id)).isEmpty)
    }

    @Test("Different roads make different groups, the largest first")
    func twoRoads() {
        let a = rides(family: 0, count: 5, seed: 10)
        let b = rides(family: 4, count: 3, seed: 50)
        let all = a + b
        let suggestions = RouteGrouping.suggest(in: index(all), candidates: all.map(\.id))
        #expect(suggestions.map(\.count) == [5, 3])
        #expect(Set(suggestions[0].members) == Set(a.map(\.id)))
        #expect(Set(suggestions[1].members) == Set(b.map(\.id)))
    }

    @Test("There and back are separate groups")
    func directions() {
        let all = rides(family: 1, count: 7, reversed: 3, seed: 20)
        let suggestions = RouteGrouping.suggest(in: index(all), candidates: all.map(\.id))
        #expect(suggestions.map(\.count) == [4, 3])
        let there = Set(all.dropFirst(3).map(\.id)), back = Set(all.prefix(3).map(\.id))
        #expect(Set(suggestions[0].members) == there)
        #expect(Set(suggestions[1].members) == back)
    }

    @Test("A ride with a detour is not part of the group")
    func detourIsAnotherRoute() {
        var all = rides(family: 2, count: 4, seed: 30)
        let detour = (id: UUID(), route: Roads.detour(Roads.road(family: 2, seed: 99), metres: 700))
        all.append(detour)
        let suggestions = RouteGrouping.suggest(in: index(all), candidates: all.map(\.id))
        #expect(suggestions.count == 1)
        #expect(!suggestions[0].members.contains(detour.id))
        #expect(suggestions[0].count == 4)
    }

    @Test("Only candidates are offered: rides in a saved route stay out")
    func candidatesOnly() {
        let all = rides(family: 0, count: 5, seed: 40)
        let taken = Set(all.prefix(3).map(\.id))
        let open = all.map(\.id).filter { !taken.contains($0) }
        #expect(RouteGrouping.suggest(in: index(all), candidates: open).isEmpty)
        #expect(RouteGrouping.suggest(in: index(all), candidates: open + [all[0].id]).count == 1)
    }

    @Test("The reference is the middle ride, not an outlier")
    func middleRide() {
        // Four rides on the whole road and one that stops 3 % early: the same route, but the least like the rest.
        var all = rides(family: 3, count: 4, seed: 60)
        let road = Roads.road(family: 3, seed: 70)
        let shorter = OverviewRoute(segments: road.segments.map { Array($0.prefix(Int(Double($0.count) * 0.97))) })
        let outlier = (id: UUID(), route: shorter)
        all.append(outlier)
        let suggestions = RouteGrouping.suggest(in: index(all), candidates: all.map(\.id))
        #expect(suggestions.count == 1)
        #expect(suggestions[0].count == 5)
        #expect(suggestions[0].reference != outlier.id)
    }

    @Test("The result does not depend on the order of the candidates")
    func stable() {
        let all = rides(family: 0, count: 6, seed: 80) + rides(family: 5, count: 4, seed: 90)
        let first = RouteGrouping.suggest(in: index(all), candidates: all.map(\.id))
        let second = RouteGrouping.suggest(in: index(all), candidates: all.map(\.id).reversed())
        #expect(first.map(\.reference) == second.map(\.reference))
        #expect(first.map { Set($0.members) } == second.map { Set($0.members) })
    }

    @Test("Rides without a route, or unknown to the index, are skipped")
    func noRoute() {
        var all = rides(family: 0, count: 3, seed: 100)
        let empty = UUID()
        var idx = index(all)
        idx.insert(empty, route: OverviewRoute(segments: []))
        all.append((empty, OverviewRoute(segments: [])))
        let suggestions = RouteGrouping.suggest(in: idx, candidates: all.map(\.id) + [UUID()])
        #expect(suggestions.count == 1)
        #expect(suggestions[0].count == 3)
    }

    // MARK: - Saved routes

    @Test("Membership comes from the reference route, with or without the other direction")
    func membership() {
        let all = rides(family: 1, count: 6, reversed: 2, seed: 110) + rides(family: 6, count: 2, seed: 130)
        let idx = index(all)
        let reference = all[3] // ridden "there"
        let there = Set(all.dropFirst(2).prefix(4).map(\.id))
        let back = Set(all.prefix(2).map(\.id))

        let oneWay = RouteGrouping.Spec(id: UUID(), route: reference.route, threshold: 0.9, includeReverse: false)
        let found = RouteGrouping.memberships(of: [oneWay], in: idx)
        #expect(Set(found.keys) == there)
        #expect(found.values.allSatisfy { $0 == oneWay.id })

        let both = RouteGrouping.Spec(id: UUID(), route: reference.route, threshold: 0.9, includeReverse: true)
        #expect(Set(RouteGrouping.memberships(of: [both], in: idx).keys) == there.union(back))
        #expect(RouteGrouping.members(of: both, in: idx).count == 6 - 0)
    }

    @Test("A ride in two saved routes goes to the one it matches best")
    func bestOfTwo() {
        let all = rides(family: 0, count: 4, seed: 150)
        let idx = index(all)
        let exact = RouteGrouping.Spec(id: UUID(), route: all[0].route, threshold: 0.5, includeReverse: false)
        // The same road, 57 m aside (40 m north and east): the rides still lie on it, but with a lower score.
        let cosLat = cos(50 * Double.pi / 180)
        let aside = RouteGrouping.Spec(
            id: UUID(),
            route: OverviewRoute(segments: all[0].route.segments.map { line in
                line.map { RoutePoint(latitude: $0.latitude + 40 * Roads.metre, longitude: $0.longitude + 40 * Roads.metre / cosLat) }
            }),
            threshold: 0.3, includeReverse: false)
        // The moved copy matches less well than the exact one, so the choice is not just "the first".
        let asideScore = RouteGrouping.members(of: aside, in: idx).first { $0.id == all[0].id }?.score ?? 0
        #expect(asideScore < 0.99)
        let result = RouteGrouping.memberships(of: [aside, exact], in: idx)
        #expect(result[all[0].id] == exact.id)
        #expect(result.count == 4)
    }

    @Test("A saved route without a usable shape has no members")
    func emptyReference() {
        let all = rides(family: 0, count: 3, seed: 170)
        let spec = RouteGrouping.Spec(id: UUID(), route: OverviewRoute(segments: []), threshold: 0.9, includeReverse: true)
        #expect(RouteGrouping.memberships(of: [spec], in: index(all)).isEmpty)
        #expect(RouteGrouping.members(of: spec, in: index(all)).isEmpty)
    }

    @Test("A thousand rides: the suggestions take seconds, not minutes")
    func manyRides() {
        // 40 roads with 25 rides each, a few of them ridden back.
        var all: [(id: UUID, route: OverviewRoute)] = []
        for road in 0..<40 {
            all += rides(family: road, count: 25, reversed: road % 4 == 0 ? 6 : 0, seed: UInt64(1_000 + road * 100))
        }
        let idx = index(all)
        let clock = ContinuousClock()
        var suggestions: [RouteGrouping.Suggestion] = []
        let time = clock.measure { suggestions = RouteGrouping.suggest(in: idx, candidates: all.map(\.id)) }
        #expect(suggestions.count >= 40)
        #expect(suggestions.reduce(0) { $0 + $1.count } <= all.count)
        #expect(time < .seconds(60), "took \(time)")
    }
}
