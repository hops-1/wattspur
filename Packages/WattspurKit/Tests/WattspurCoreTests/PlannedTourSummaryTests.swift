import Foundation
import Testing
@testable import WattspurCore

/// The list of planned tours (B-373): the search and filter pills, the thinned preview and the
/// elevation profile. Invented points only.
@Suite("Planned tour list")
struct PlannedTourSummaryTests {
    /// A line north from 50.0/9.0, one point every `spacing` metres, heights from `ele`.
    private static func line(_ count: Int, spacing: Double = 50, ele: (Int) -> Double? = { 300 + Double($0) }) -> [PlannedTour.Point] {
        (0..<count).map { PlannedTour.Point(latitude: 50 + Double($0) * spacing / 111_195, longitude: 9, altitude: ele($0)) }
    }

    private static func summary(_ name: String, km: Double, loop: Bool = false, source: PlannedTour.Source = .komoot) -> PlannedTourSummary {
        PlannedTourSummary(id: UUID(), name: name, createdAt: .now, source: source, distance: km * 1000,
                           ascent: 100, descent: 100, isLoop: loop, pointCount: 10, preview: [])
    }

    @Test("The search finds the name without regard to case, and the pills narrow the list")
    func filter() {
        let tours = [Self.summary("Zum Stausee", km: 42, loop: true),
                     Self.summary("Über den Pass", km: 88, source: .gpx),
                     Self.summary("Bäckerrunde", km: 8, loop: true)]
        #expect(PlannedTourFilter().apply(tours).count == 3)
        #expect(!PlannedTourFilter().isActive)
        #expect(PlannedTourFilter(text: "stausee").apply(tours).map(\.name) == ["Zum Stausee"])
        #expect(PlannedTourFilter(text: "  ").apply(tours).count == 3)
        #expect(PlannedTourFilter(shape: .loop).apply(tours).map(\.name) == ["Zum Stausee", "Bäckerrunde"])
        #expect(PlannedTourFilter(shape: .oneWay).apply(tours).map(\.name) == ["Über den Pass"])
        #expect(PlannedTourFilter(distance: .over50).apply(tours).map(\.name) == ["Über den Pass"])
        #expect(PlannedTourFilter(source: .komoot).apply(tours).count == 2)
        let combined = PlannedTourFilter(text: "e", distance: .under10, shape: .loop)
        #expect(combined.hasFilters && combined.isActive)
        #expect(combined.apply(tours).map(\.name) == ["Bäckerrunde"])
    }

    @Test("The preview keeps at most the asked number of points, first and last among them")
    func thinned() {
        let points = Self.line(1000)
        let preview = PlannedTour.thinned(points, to: PlannedTour.previewPointCount)
        #expect(preview.count == PlannedTour.previewPointCount)
        #expect(preview.first == points.first)
        #expect(preview.last == points.last)
        #expect(PlannedTour.thinned(Array(points.prefix(10)), to: 64).count == 10)
    }

    @Test("The profile runs from 0 to the whole distance and skips points without height")
    func profile() throws {
        let points = Self.line(1000, ele: { $0 % 10 == 5 ? nil : 300 + Double($0) / 10 })
        let profile = PlannedTour.profile(of: points, count: 100)
        #expect(profile.count <= 101 && profile.count >= 90)
        #expect(profile.first?.distance == 0)
        let last = try #require(profile.last)
        #expect(abs(last.distance - 999 * 50) < 1)
        #expect(zip(profile, profile.dropFirst()).allSatisfy { $0.distance < $1.distance })
        #expect(PlannedTour.altitudeRange(of: points) == 300...399.9)
    }

    @Test("Without heights there is no profile and no range")
    func noHeights() {
        let points = Self.line(50, ele: { _ in nil })
        #expect(PlannedTour.profile(of: points).isEmpty)
        #expect(PlannedTour.altitudeRange(of: points) == nil)
        #expect(PlannedTour.profile(of: Self.line(30)).count == 30)
    }

    @Test("A trashed tour counts down the days left")
    func daysLeft() {
        let deleted = Date(timeIntervalSince1970: 1_800_000_000)
        let trashed = TrashedPlannedTour(tour: Self.summary("Alt", km: 10), deletedAt: deleted)
        #expect(trashed.daysLeft(now: deleted) == 30)
        #expect(trashed.daysLeft(now: deleted.addingTimeInterval(29.5 * 86_400)) == 1)
        #expect(trashed.daysLeft(now: deleted.addingTimeInterval(40 * 86_400)) == 0)
    }
}
