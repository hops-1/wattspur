import Foundation

/// Locale-aware formatting of ride values (NFR-10).
enum RideFormat {
    /// "00:48:36"
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2)))
    }

    /// "19.5" / "19,5" (kilometres, one decimal)
    static func distanceValue(_ metres: Double) -> String {
        (metres / 1000).formatted(.number.precision(.fractionLength(1)))
    }

    /// "19.5 km"
    static func distance(_ metres: Double) -> String {
        "\(distanceValue(metres)) km"
    }

    /// "24.1" (km/h, one decimal)
    static func speedValue(_ metresPerSecond: Double?) -> String {
        guard let metresPerSecond else { return "–" }
        return (metresPerSecond * 3.6).formatted(.number.precision(.fractionLength(1)))
    }

    /// "24.1 km/h"
    static func speed(_ metresPerSecond: Double?) -> String {
        "\(speedValue(metresPerSecond)) km/h"
    }

    /// "Yesterday, 14:12", "Today, 9:28" or "26.09.2026, 07:17" (LIST-01),
    /// in the time zone of the ride's start location (B-006).
    static func relativeDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
        if calendar.isDateInToday(date) { return String(localized: "Today, \(time)") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday, \(time)") }
        return date.formatted(Date.FormatStyle(date: .numeric, time: .shortened, timeZone: timeZone))
    }

    /// "Sunday, 18 October 2026 at 14:12"
    static func longDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(date: .complete, time: .shortened, timeZone: timeZone))
    }
}
