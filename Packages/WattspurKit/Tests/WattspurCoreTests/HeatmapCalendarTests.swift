import Foundation
import Testing
@testable import WattspurCore

/// The calendar of the year's heatmap and the "New" mark of records (B-356, S-20).
@Suite("Heatmap calendar")
struct HeatmapCalendarTests {
    /// A Gregorian calendar in UTC that starts its weeks on `firstWeekday` (1 Sunday, 2 Monday).
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func day(_ date: Date?, _ calendar: Calendar) -> String? {
        date.map { "\(calendar.component(.month, from: $0))-\(calendar.component(.day, from: $0))" }
    }

    @Test("A year that begins on a Monday starts in the first cell with weeks from Monday")
    func mondayYear() {
        // 1 January 2024 was a Monday, and 2024 is a leap year.
        let monday = calendar(firstWeekday: 2)
        let weeks = HeatmapCalendar.weeks(year: 2024, calendar: monday)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(day(weeks[0][0], monday) == "1-1")
        #expect(weeks.joined().compactMap { $0 }.count == 366)
        #expect(weeks.joined().contains { day($0, monday) == "2-29" })
        // 31 December 2024 was a Tuesday: five empty cells after it.
        #expect(day(weeks.last?[1], monday) == "12-31")
        #expect(weeks.last?.suffix(5).allSatisfy { $0 == nil } == true)
        #expect(weeks.count == 53)
    }

    @Test("A year that begins on a Sunday has six empty cells before it when weeks start on Monday")
    func sundayYear() {
        // 1 January 2023 was a Sunday; 2023 has 365 days.
        let monday = calendar(firstWeekday: 2)
        let weeks = HeatmapCalendar.weeks(year: 2023, calendar: monday)
        #expect(weeks[0].prefix(6).allSatisfy { $0 == nil })
        #expect(day(weeks[0][6], monday) == "1-1")
        #expect(weeks.joined().compactMap { $0 }.count == 365)
        #expect(!weeks.joined().contains { day($0, monday) == "2-29" })
        // 6 + 365 cells fill exactly 53 weeks: 31 December, a Sunday, is the last cell.
        #expect(weeks.count == 53)
        #expect(day(weeks.last?[6], monday) == "12-31")

        // With weeks from Sunday, the same year starts in the first cell.
        let sunday = calendar(firstWeekday: 1)
        let sundayWeeks = HeatmapCalendar.weeks(year: 2023, calendar: sunday)
        #expect(day(sundayWeeks[0][0], sunday) == "1-1")
        #expect(sundayWeeks.count == 53)
    }

    @Test("A leap year that begins on a Saturday keeps 29 February in its week")
    func leapYear() {
        // 1 January 2028 is a Saturday, 29 February 2028 a Tuesday.
        let monday = calendar(firstWeekday: 2)
        let weeks = HeatmapCalendar.weeks(year: 2028, calendar: monday)
        #expect(weeks[0].prefix(5).allSatisfy { $0 == nil })
        #expect(day(weeks[0][5], monday) == "1-1")
        let leap = weeks.first { week in week.contains { day($0, monday) == "2-29" } }
        #expect(day(leap?[1], monday) == "2-29")
        #expect(day(leap?[2], monday) == "3-1")
        #expect(weeks.joined().compactMap { $0 }.count == 366)
    }

    @Test("Each month is named in the week of its first day, once")
    func monthStarts() {
        let monday = calendar(firstWeekday: 2)
        for year in [2023, 2024, 2028] {
            let weeks = HeatmapCalendar.weeks(year: year, calendar: monday)
            let months = weeks.compactMap { HeatmapCalendar.monthStarting(in: $0, calendar: monday) }
            #expect(months == Array(1...12))
        }
        let weeks = HeatmapCalendar.weeks(year: 2024, calendar: monday)
        #expect(HeatmapCalendar.monthStarting(in: weeks[0], calendar: monday) == 1)
        #expect(HeatmapCalendar.monthStarting(in: weeks[1], calendar: monday) == nil)
        #expect(HeatmapCalendar.monthStarting(in: [nil, nil], calendar: monday) == nil)
    }

    @Test("A record is new while a ride imported in the last seven days holds it")
    func newRecord() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recent = UUID(), old = UUID(), unknown = UUID()
        let imported: [UUID: Date] = [recent: now.addingTimeInterval(-6 * 86_400), old: now.addingTimeInterval(-8 * 86_400)]
        func record(_ ids: [UUID]) -> RideRecord {
            RideRecord(kind: .longestDistance, value: 100_000, rideIDs: ids, date: now, streak: nil)
        }
        #expect(record([recent]).isNew(now: now) { imported[$0] })
        #expect(!record([old]).isNew(now: now) { imported[$0] })
        #expect(!record([unknown]).isNew(now: now) { imported[$0] })
        // A streak is new when one of its rides is.
        #expect(record([old, recent]).isNew(now: now) { imported[$0] })
        #expect(!record([]).isNew(now: now) { imported[$0] })
    }
}
