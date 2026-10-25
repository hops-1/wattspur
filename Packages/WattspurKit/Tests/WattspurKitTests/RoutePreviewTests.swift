import Foundation
import Testing
@testable import WattspurKit

@Suite("Route previews for the ride list")
struct RoutePreviewTests {
    private let plane = RouteSimplifier.LocalPlane(origin: RoutePoint(latitude: 49.83, longitude: 8.83))

    /// A point `east` and `north` metres from Reinheim.
    private func at(_ east: Double, _ north: Double) -> RoutePoint {
        RoutePoint(latitude: 49.83 + north / plane.metresPerDegreeLatitude,
                   longitude: 8.83 + east / plane.metresPerDegreeLongitude)
    }

    @Test("No GPS gives no preview")
    func empty() {
        #expect(RoutePreview(route: OverviewRoute(segments: [])) == nil)
    }

    @Test("A ride north keeps its proportions: centred, start at the bottom, north up")
    func northwards() throws {
        let preview = try #require(RoutePreview(route: OverviewRoute(segments: [[at(0, 0), at(0, 2_000)]])))
        let line = try #require(preview.segments.first)
        #expect(line.count == 2)
        #expect(abs(line[0].x - 0.5) < 0.001 && abs(line[1].x - 0.5) < 0.001)
        #expect(abs(line[0].y - 1) < 0.001)
        #expect(abs(line[1].y) < 0.001)
        #expect(!preview.isLoop)
    }

    @Test("A loop back to the start is recognised and fills the square")
    func loop() throws {
        let square = [at(0, 0), at(1_000, 0), at(1_000, 1_000), at(0, 1_000), at(30, 20)]
        let preview = try #require(RoutePreview(route: OverviewRoute(segments: [square])))
        #expect(preview.isLoop)
        let points = preview.segments.joined()
        let xs = points.map(\.x), ys = points.map(\.y)
        #expect(abs((xs.min() ?? 1)) < 0.001 && abs((xs.max() ?? 0) - 1) < 0.001)
        #expect(abs((ys.min() ?? 1)) < 0.001 && abs((ys.max() ?? 0) - 1) < 0.001)
    }

    @Test("A merged ride keeps one line per part")
    func parts() throws {
        let route = OverviewRoute(segments: [[at(0, 0), at(500, 500)], [at(600, 600), at(1_000, 0)]])
        let preview = try #require(RoutePreview(route: route))
        #expect(preview.segments.map(\.count) == [2, 2])
        #expect(preview.start == preview.segments.first?.first)
    }

    @Test("The sample ride: a few dozen points, all inside the square")
    func sampleRide() throws {
        let ride = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
        let route = OverviewRoute(samples: ride.samples)
        let preview = try #require(RoutePreview(route: route))
        let points = Array(preview.segments.joined())
        #expect(points.count < route.pointCount)
        #expect(points.count > 10 && points.count < 100)
        #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }
}
