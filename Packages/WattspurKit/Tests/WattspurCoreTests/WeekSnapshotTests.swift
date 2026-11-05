import Foundation
import Testing
@testable import WattspurCore

struct WeekSnapshotTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 2
        return calendar
    }()

    private func date(_ text: String) -> Date {
        let style = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
            .time(includingFractionalSeconds: false)
        return try! Date(text, strategy: style)
    }

    @Test func keepsOnlyTheCurrentWeek() {
        // Wednesday 4 Nov 2026; the week is Mon 2 Nov – Sun 8 Nov.
        let snapshot = WeekSnapshot(rides: [
            (start: date("2026-11-04T08:00:00"), distance: 5_000.0),
            (start: date("2026-11-01T18:00:00"), distance: 20_000.0), // Sunday before
            (start: date("2026-11-02T00:00:00"), distance: 10_000.0), // Monday midnight
        ], lastRide: nil, now: date("2026-11-04T12:00:00"), calendar: calendar)
        #expect(snapshot.rides.map(\.distance) == [10_000, 5_000])
        let totals = snapshot.totals(now: date("2026-11-04T12:00:00"), calendar: calendar)
        #expect(totals.weekDistance == 15_000)
        #expect(totals.weekRides == 2)
    }

    @Test func newWeekStartsAtZero() {
        let snapshot = WeekSnapshot(rides: [(start: date("2026-11-04T08:00:00"), distance: 5_000.0)],
                                    lastRide: nil, now: date("2026-11-04T12:00:00"), calendar: calendar)
        let totals = snapshot.totals(now: date("2026-11-09T07:00:00"), calendar: calendar)
        #expect(totals.weekDistance == 0)
        #expect(totals.weekRides == 0)
        #expect(WeekSnapshot.nextWeek(after: date("2026-11-04T12:00:00"), calendar: calendar) == date("2026-11-09T00:00:00"))
    }

    @Test func sumsEachDay() {
        let snapshot = WeekSnapshot(rides: [
            (start: date("2026-11-02T08:00:00"), distance: 3_000.0),
            (start: date("2026-11-02T18:00:00"), distance: 4_000.0),
            (start: date("2026-11-08T23:30:00"), distance: 1_000.0),
        ], lastRide: nil, now: date("2026-11-04T12:00:00"), calendar: calendar)
        let days = snapshot.days(now: date("2026-11-04T12:00:00"), calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first?.day == date("2026-11-02T00:00:00"))
        #expect(days.map(\.distance) == [7_000, 0, 0, 0, 0, 0, 1_000])
    }

    @Test func survivesJSON() throws {
        let snapshot = WeekSnapshot(rides: [(start: date("2026-11-04T08:00:00"), distance: 5_000.0)],
                                    lastRide: .init(name: "Feierabend", start: date("2026-11-04T08:00:00"),
                                                    distance: 5_000, timeZone: "Europe/Berlin"),
                                    now: date("2026-11-04T12:00:00"), calendar: calendar)
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(WeekSnapshot.self, from: data) == snapshot)
    }
}
