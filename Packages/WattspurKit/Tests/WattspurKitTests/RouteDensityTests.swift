import Foundation
import Testing
@testable import WattspurKit

@Suite("Heat map cells and clicking on a route")
struct RouteDensityTests {
    private let plane = RouteSimplifier.LocalPlane(origin: RoutePoint(latitude: 49.83, longitude: 8.83))
    private let start = Date(timeIntervalSince1970: 1_792_396_800)

    /// A point `east` and `north` metres from Reinheim.
    private func at(_ east: Double, _ north: Double) -> RoutePoint {
        RoutePoint(latitude: 49.83 + north / plane.metresPerDegreeLatitude,
                   longitude: 8.83 + east / plane.metresPerDegreeLongitude)
    }

    private func ride(_ segments: [[RoutePoint]], days: Double = 0) -> MapRide {
        MapRide(id: UUID(), name: "Ride",
                figures: RideFigures(startDate: start.addingTimeInterval(days * 86_400), distance: 1000, timerTime: 600),
                route: OverviewRoute(segments: segments))!
    }

    /// About 100 m at Reinheim's latitude, in Mercator units.
    private var cellSize: Double { MercatorPoint(at(0, 100)).y.distance(to: MercatorPoint(at(0, 0)).y) }

    @Test("Mercator: Greenwich on the equator is the middle of the world, north is up")
    func mercator() {
        let middle = MercatorPoint(RoutePoint(latitude: 0, longitude: 0))
        #expect(abs(middle.x - 0.5) < 1e-12 && abs(middle.y - 0.5) < 1e-12)
        #expect(MercatorPoint(at(0, 1_000)).y < MercatorPoint(at(0, 0)).y)
    }

    @Test("Cells are about 16 points, a power of two, the same for nearby zooms")
    func cellSizeForZoom() {
        let size = RouteDensity.cellSize(unitsPerPoint: 1.0 / 1_000_000)
        #expect(size == pow(2, (log2(16.0 / 1_000_000)).rounded()))
        #expect(size / (16.0 / 1_000_000) > 0.7 && size / (16.0 / 1_000_000) < 1.42)
        #expect(RouteDensity.cellSize(unitsPerPoint: 1.0 / 1_050_000) == size)
        #expect(RouteDensity.cellSize(unitsPerPoint: 0) == 0)
    }

    @Test("Fixed steps 1 / 2–4 / 5–9 / 10–19 / 20+")
    func steps() {
        #expect([1, 2, 4, 5, 9, 10, 19, 20, 500].map(DensityStep.init(count:))
                == [.one, .few, .few, .some, .some, .many, .many, .most, .most])
        #expect(DensityStep.most.range.upperBound == nil)
    }

    @Test("A ride counts once per cell, even when it passes there twice")
    func oncePerRide() {
        let outAndBack = ride([[at(0, 0), at(1_000, 0), at(0, 0)]])
        let other = ride([[at(0, 0), at(1_000, 0)]])
        let density = RouteDensity(rides: [outAndBack, other], cellSize: cellSize)
        #expect(density.counts.values.max() == 2)
        let homeCell = density.cell(of: MercatorPoint(at(0, 0)))
        #expect(density.counts[homeCell] == 2)
        #expect(density.step(of: homeCell) == .few)
    }

    @Test("A long straight line marks every cell on its way")
    func noGaps() {
        let density = RouteDensity(rides: [ride([[at(0, 0), at(0, 2_000)]])], cellSize: cellSize)
        let rows = Set(density.counts.keys.map(\.row))
        #expect(rows.count >= 20)
        #expect(rows.count == (rows.max()! - rows.min()! + 1))
    }

    @Test("Only cells in the visible area are counted")
    func visibleArea() throws {
        let long = ride([[at(0, 0), at(0, 5_000)]])
        let area = try #require(GeoBounds([at(-100, 0), at(100, 200)]))
        let all = RouteDensity(rides: [long], cellSize: cellSize)
        let part = RouteDensity(rides: [long], cellSize: cellSize, area: area)
        #expect(part.counts.count < all.counts.count / 2)
        #expect(!part.counts.isEmpty)
    }

    @Test("Click: rides within the radius, newest first; a merged ride's gap is no line")
    func hitTest() {
        let near = ride([[at(-500, 8), at(500, 8)]], days: 1)
        let newer = ride([[at(0, -500), at(0, 500)]], days: 2)
        let far = ride([[at(-500, 40), at(500, 40)]], days: 3)
        // Two parts; the straight gap between them would pass the click point.
        let merged = ride([[at(-800, -300), at(-300, -300)], [at(300, 300), at(800, 300)]], days: 4)
        let hits = RouteHitTest.rides(near: at(0, 0), radius: 15, in: [near, far, merged, newer])
        #expect(hits.map(\.id) == [newer.id, near.id])
    }

    @Test("1 000 rides: heat map and click stay quick")
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
            return ride([points], days: Double(i))
        }
        let clock = ContinuousClock()
        let heat = clock.measure { _ = RouteDensity(rides: rides, cellSize: cellSize * 2) }
        let click = clock.measure { _ = RouteHitTest.rides(near: at(0, 0), radius: 50, in: rides) }
        let heatLimit: Duration = .seconds(2), clickLimit: Duration = .milliseconds(200)
        #expect(heat < heatLimit, "Heat map of 1 000 rides took \(heat)")
        #expect(click < clickLimit, "Click test over 1 000 rides took \(click)")
    }
}
