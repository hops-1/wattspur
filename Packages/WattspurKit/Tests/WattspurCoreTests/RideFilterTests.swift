import Foundation
import Testing
@testable import WattspurCore

@Suite("Search and filters of the ride list (B-222)")
struct RideFilterTests {
    static let cube = UUID()
    static let cargo = UUID()
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 2
        return calendar
    }()
    /// Thursday 5 Nov 2026, noon.
    static let now = Date(timeIntervalSince1970: 1_793_876_400)

    static func ride(_ name: String, daysAgo: Double, km: Double, bike: UUID? = cube) -> RideExchange.Ride {
        RideExchange.Ride(id: UUID(), name: name, startDate: now.addingTimeInterval(-daysAgo * 86_400), bikeID: bike,
                          source: "fit", timerTime: 3600, elapsedTime: 3600, distance: km * 1000)
    }

    static let rides = [
        ride("Zur Arbeit", daysAgo: 0, km: 14.8),
        ride("Feierabendrunde", daysAgo: 2, km: 32.1, bike: cargo),
        ride("Runde am Mittag", daysAgo: 40, km: 10.0),
        ride("Ausflug Odenwald", daysAgo: 400, km: 61.5),
        ride("Brötchen holen", daysAgo: 1, km: 2.4),
    ]

    private func names(_ filter: RideFilter) -> [String] {
        Self.rides.filter { filter.admits($0, now: Self.now, calendar: Self.calendar) }.map(\.name)
    }

    @Test("Without search or filter every ride passes")
    func nothingSet() {
        let filter = RideFilter()
        #expect(!filter.isActive)
        #expect(names(filter).count == Self.rides.count)
    }

    @Test("The search finds part of the name, without case and accents; blanks alone do not filter")
    func search() {
        #expect(names(RideFilter(text: "runde")) == ["Feierabendrunde", "Runde am Mittag"])
        #expect(names(RideFilter(text: "brotchen")) == ["Brötchen holen"])
        #expect(names(RideFilter(text: "  ")).count == Self.rides.count)
        #expect(!RideFilter(text: "  ").isActive)
        #expect(RideFilter(text: "x").isActive && !RideFilter(text: "x").hasFilters)
    }

    @Test("Bike, period and distance narrow the list together")
    func combined() {
        #expect(names(RideFilter(bike: .bike(Self.cargo))) == ["Feierabendrunde"])
        #expect(names(RideFilter(period: .thisWeek)) == ["Zur Arbeit", "Feierabendrunde", "Brötchen holen"])
        #expect(names(RideFilter(period: .thisWeek, distance: .from10To25)) == ["Zur Arbeit"])
        #expect(names(RideFilter(text: "runde", bike: .bike(Self.cube))) == ["Runde am Mittag"])
        #expect(RideFilter(distance: .over50).hasFilters)
    }

    @Test("A distance on a band's edge belongs to the band above")
    func distanceEdges() {
        #expect(RideDistanceBand.under10.contains(9_999))
        #expect(!RideDistanceBand.under10.contains(10_000))
        #expect(RideDistanceBand.from10To25.contains(10_000))
        #expect(RideDistanceBand.over50.contains(50_000))
        #expect(names(RideFilter(distance: .over50)) == ["Ausflug Odenwald"])
    }

    @Test("A bike filter without a second bike, or for a bike that is gone, counts as all")
    func resolved() {
        let filter = RideFilter(bike: .bike(Self.cargo))
        #expect(filter.resolved(knownBikeIDs: [Self.cube, Self.cargo]).bike == .bike(Self.cargo))
        #expect(filter.resolved(knownBikeIDs: [Self.cargo]).bike == .all)
        #expect(filter.resolved(knownBikeIDs: [Self.cube, UUID()]).bike == .all)
    }

    @Test("The months hold only the rides that pass")
    func months() {
        let library = RideExchange.Library(generatedAt: Self.now, generator: "test", bikes: [], rides: Self.rides)
        let months = library.months(filteredBy: RideFilter(distance: .under10), now: Self.now, calendar: Self.calendar)
        #expect(months.flatMap(\.rides).map(\.name) == ["Brötchen holen"])
        #expect(library.months(filteredBy: RideFilter(), now: Self.now, calendar: Self.calendar).flatMap(\.rides).count == 5)
    }
}
