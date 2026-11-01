import Foundation

/// The rides of a calendar day or a streak opened from the highlights (B-130): the list shows
/// only them, with a chip "15 Oct ✕" or "3–9 Oct ✕" that brings back all rides.
public struct RideDayFilter: Sendable, Hashable {
    public var rideIDs: Set<UUID>

    public init(rideIDs: some Sequence<UUID>) {
        self.rideIDs = Set(rideIDs)
    }

    /// "15 Oct" for one day, "3–9 Oct" or "28 Sep – 4 Oct" for several, from the rides' start
    /// dates; with the year when it is not the year of `now`. `nil` without dates.
    public static func label(for dates: some Collection<Date>, calendar: Calendar = .current,
                             locale: Locale = .current, now: Date = .now) -> String? {
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let firstDay = calendar.startOfDay(for: first), lastDay = calendar.startOfDay(for: last)
        let showsYear = calendar.component(.year, from: firstDay) != calendar.component(.year, from: now)
            || calendar.component(.year, from: lastDay) != calendar.component(.year, from: now)
        var day = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if showsYear { day = day.year() }
        guard firstDay != lastDay else { return firstDay.formatted(day) }
        var range = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if showsYear { range = range.year() }
        return (firstDay..<lastDay).formatted(range)
    }
}
