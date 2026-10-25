import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

@Suite("Ride periods and sorting")
struct RideQueryTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        c.firstWeekday = 2 // Monday
        return c
    }

    /// Tuesday, 20 October 2026, 10:00 in Berlin.
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 10))! }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 14))!
    }

    @Test("Periods include and exclude the expected dates")
    func periods() {
        let sunday = date(2026, 10, 18)
        let monday = date(2026, 10, 19)
        #expect(!RidePeriod.thisWeek.contains(sunday, now: now, calendar: calendar))
        #expect(RidePeriod.thisWeek.contains(monday, now: now, calendar: calendar))
        #expect(RidePeriod.thisMonth.contains(sunday, now: now, calendar: calendar))
        #expect(!RidePeriod.thisMonth.contains(date(2026, 9, 26), now: now, calendar: calendar))
        #expect(RidePeriod.last30Days.contains(date(2026, 9, 26), now: now, calendar: calendar))
        #expect(RidePeriod.thisYear.contains(date(2026, 1, 2), now: now, calendar: calendar))
        #expect(!RidePeriod.thisYear.contains(date(2025, 12, 31), now: now, calendar: calendar))
        #expect(RidePeriod.all.contains(date(2001, 1, 1), now: now, calendar: calendar))
    }

    @Test("Sorting is descending with missing values last")
    func sorting() {
        let a = RideSortKey(startDate: date(2026, 10, 18), distance: 19_543, timerTime: 2916, totalAscent: 166, averagePower: 135)
        let b = RideSortKey(startDate: date(2026, 9, 26), distance: 3_900, timerTime: 640, totalAscent: nil, averagePower: 150)
        let c = RideSortKey(startDate: date(2026, 10, 1), distance: 3_900, timerTime: 900, totalAscent: 40, averagePower: nil)
        let rides = [b, c, a]

        #expect(rides.sorted(by: RideSortOrder.date.areInIncreasingOrder) == [a, c, b])
        #expect(rides.sorted(by: RideSortOrder.distance.areInIncreasingOrder) == [a, c, b]) // tie → newest first
        #expect(rides.sorted(by: RideSortOrder.duration.areInIncreasingOrder) == [a, c, b])
        #expect(rides.sorted(by: RideSortOrder.ascent.areInIncreasingOrder) == [a, c, b])
        #expect(rides.sorted(by: RideSortOrder.averagePower.areInIncreasingOrder) == [b, a, c])
    }
}
