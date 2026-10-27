import Foundation
import Testing
@testable import WattspurCore

@Suite("Rides of a day or a streak from the highlights")
struct RideDayFilterTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }
    private let german = Locale(identifier: "de_DE")
    private let english = Locale(identifier: "en_GB")

    private func date(_ day: Int, _ month: Int, _ year: Int = 2026, hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var now: Date { date(27, 10) }

    @Test("One day: day and month, two rides on it count as one day")
    func oneDay() {
        let label = RideDayFilter.label(for: [date(15, 10), date(15, 10, hour: 18)], calendar: calendar, locale: german, now: now)
        #expect(label == "15. Okt.")
        #expect(RideDayFilter.label(for: [date(15, 10)], calendar: calendar, locale: english, now: now) == "15 Oct")
    }

    @Test("A streak in one month and across two months")
    func streak() {
        let october = RideDayFilter.label(for: [date(9, 10), date(3, 10), date(5, 10)], calendar: calendar, locale: german, now: now)
        #expect(october?.hasPrefix("3.") == true && october?.contains("9. Okt.") == true)
        let across = RideDayFilter.label(for: [date(28, 9), date(4, 10)], calendar: calendar, locale: german, now: now)
        #expect(across?.contains("Sept.") == true && across?.contains("Okt.") == true)
        #expect(across?.contains("2026") == false)
    }

    @Test("With the year when it is not this year; nothing without rides")
    func otherYear() {
        let label = RideDayFilter.label(for: [date(15, 10, 2025)], calendar: calendar, locale: german, now: now)
        #expect(label?.contains("2025") == true)
        #expect(RideDayFilter.label(for: [Date](), calendar: calendar, locale: german, now: now) == nil)
    }

    @Test("Holds each ride once")
    func ids() {
        let id = UUID()
        #expect(RideDayFilter(rideIDs: [id, id]).rideIDs == [id])
    }
}
