import Charts
import SwiftData
import SwiftUI
import WattspurKit

enum HighlightsFormat {
    static func title(_ kind: RecordKind) -> String {
        switch kind {
        case .longestDistance: String(localized: "Longest ride")
        case .longestDuration: String(localized: "Longest ride time")
        case .mostAscent: String(localized: "Most ascent")
        case .highestAverageSpeed: String(localized: "Highest avg speed")
        case .highestAveragePower: String(localized: "Highest avg power")
        case .highestSpeed: String(localized: "Top speed")
        case .highestPower: String(localized: "Highest power")
        case .highestCadence: String(localized: "Highest cadence")
        case .bestPower1Min: String(localized: "Best 1-minute power")
        case .longestStreak: String(localized: "Longest streak")
        }
    }

    /// Number and unit, e.g. ("101.6", "km") or ("5:36", "h").
    static func value(_ kind: RecordKind, _ value: Double) -> (number: String, unit: String) {
        switch kind {
        case .longestDistance: (RideFormat.distanceValue(value), "km")
        case .longestDuration:
            (Duration.seconds(value.rounded()).formatted(.time(pattern: .hourMinute)), "h")
        case .mostAscent: (Int(value.rounded()).formatted(), "m")
        case .highestAverageSpeed: (RideFormat.speedValue(value), "km/h")
        case .highestAveragePower: (Int(value.rounded()).formatted(), "W")
        case .highestSpeed: (RideFormat.speedValue(value), "km/h")
        case .highestPower, .bestPower1Min: (Int(value.rounded()).formatted(), "W")
        case .highestCadence: (Int(value.rounded()).formatted(), String(localized: "rpm"))
        case .longestStreak: (Int(value).formatted(), String(localized: "days", comment: "Unit after the number of days of a streak"))
        }
    }

    /// "101.6 km", "5 days".
    static func text(_ kind: RecordKind, _ value: Double) -> String {
        if kind == .longestStreak { return String(localized: "\(Int(value)) days") }
        let v = Self.value(kind, value)
        return "\(v.number) \(v.unit)"
    }

    static func title(_ metric: GoalMetric) -> String {
        switch metric {
        case .distance: String(localized: "Kilometres")
        case .rides: String(localized: "Rides")
        case .ascent: String(localized: "Ascent")
        }
    }

    static func title(_ period: GoalPeriod) -> String {
        switch period {
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .year: String(localized: "Year")
        }
    }

    /// The value in the unit the user types: km, rides or m.
    static func display(_ metric: GoalMetric, _ value: Double) -> Double {
        metric == .distance ? value / 1000 : value
    }

    static func unit(_ metric: GoalMetric) -> String {
        switch metric {
        case .distance: "km"
        case .rides: ""
        case .ascent: "m"
        }
    }

    /// "62", "1,284" – kilometres without decimals from 100 km on.
    static func number(_ metric: GoalMetric, _ value: Double) -> String {
        let shown = display(metric, value)
        if metric == .distance && shown < 100 && shown.rounded() != shown {
            return shown.formatted(.number.precision(.fractionLength(1)))
        }
        return Int(shown.rounded()).formatted()
    }

    /// "This week", "October", "2026".
    static func currentPeriod(_ period: GoalPeriod, _ interval: DateInterval, calendar: Calendar) -> String {
        switch period {
        case .week: String(localized: "This week")
        case .month: interval.start.formatted(Date.FormatStyle(timeZone: calendar.timeZone).month(.wide))
        case .year: String(calendar.component(.year, from: interval.start))
        }
    }

    static func shortDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).day().month(.abbreviated))
    }

    static func longDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).day().month(.abbreviated).year())
    }
}

// MARK: - Year
