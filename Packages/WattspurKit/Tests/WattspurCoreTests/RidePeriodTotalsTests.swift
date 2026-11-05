import Foundation
import Testing
@testable import WattspurCore

struct RidePeriodTotalsTests {
    private func calendar(_ identifier: String, firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ text: String, _ calendar: Calendar) -> Date {
        var style = Date.ISO8601FormatStyle(timeZone: calendar.timeZone)
        style = style.year().month().day().time(includingFractionalSeconds: false)
        return try! Date(text, strategy: style)
    }

    @Test func sumsWeekAndMonthOfNow() {
        let cal = calendar("Europe/Berlin", firstWeekday: 2)
        // Wednesday 4 Nov 2026; the week is Mon 2 Nov – Sun 8 Nov.
        let now = date("2026-11-04T12:00:00", cal)
        let rides = [
            (start: date("2026-11-02T08:00:00", cal), distance: 10_000.0), // Monday, this week
            (start: date("2026-11-08T23:30:00", cal), distance: 5_000.0),  // Sunday night, this week
            (start: date("2026-11-01T18:00:00", cal), distance: 20_000.0), // Sunday before: month only
            (start: date("2026-10-31T10:00:00", cal), distance: 30_000.0), // last month
            (start: date("2026-11-09T00:00:00", cal), distance: 7_000.0),  // next Monday: month only
        ]
        let totals = RidePeriodTotals(rides: rides, now: now, calendar: cal)
        #expect(totals.weekRides == 2)
        #expect(totals.weekDistance == 15_000)
        #expect(totals.monthRides == 4)
        #expect(totals.monthDistance == 42_000)
        #expect(totals.yearRides == 5)
        #expect(totals.yearDistance == 72_000)
    }

    @Test func yearEndsAtNewYear() {
        let cal = calendar("Europe/Berlin", firstWeekday: 2)
        let now = date("2026-11-04T12:00:00", cal)
        let rides = [
            (start: date("2026-01-01T00:00:00", cal), distance: 1_000.0),
            (start: date("2025-12-31T23:59:00", cal), distance: 2_000.0),
            (start: date("2027-01-01T00:00:00", cal), distance: 4_000.0),
        ]
        let totals = RidePeriodTotals(rides: rides, now: now, calendar: cal)
        #expect(totals.yearRides == 1)
        #expect(totals.yearDistance == 1_000)
    }

    @Test func weekStartFollowsTheCalendar() {
        // In the US the week starts on Sunday, so Sunday 1 Nov belongs to the week of 4 Nov.
        let us = calendar("America/New_York", firstWeekday: 1)
        let now = date("2026-11-04T12:00:00", us)
        let sunday = [(start: date("2026-11-01T09:00:00", us), distance: 1_000.0)]
        #expect(RidePeriodTotals(rides: sunday, now: now, calendar: us).weekRides == 1)

        let de = calendar("America/New_York", firstWeekday: 2)
        #expect(RidePeriodTotals(rides: sunday, now: now, calendar: de).weekRides == 0)
    }

    @Test func timeZoneDecidesTheMonth() {
        // 31 Oct 23:30 in Berlin is 1 Nov in Tokyo.
        let berlin = calendar("Europe/Berlin", firstWeekday: 2)
        let tokyo = calendar("Asia/Tokyo", firstWeekday: 2)
        let start = date("2026-10-31T23:30:00", berlin)
        let ride = [(start: start, distance: 1_000.0)]
        #expect(RidePeriodTotals(rides: ride, now: date("2026-11-15T12:00:00", berlin), calendar: berlin).monthRides == 0)
        #expect(RidePeriodTotals(rides: ride, now: date("2026-11-15T12:00:00", tokyo), calendar: tokyo).monthRides == 1)
    }

    @Test func noRides() {
        #expect(RidePeriodTotals(rides: [(start: Date, distance: Double)](), now: .now) == RidePeriodTotals())
    }
}
