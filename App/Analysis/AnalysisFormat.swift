import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Formatting and labels

enum AnalysisFormat {
    /// "38 h 12 min" in the user's locale.
    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        Duration.seconds((seconds / 60).rounded() * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func whole(_ value: Double?) -> String { number(value, digits: 0) }

    static func number(_ value: Double?, digits: Int) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(digits))) } ?? "–"
    }

    /// "+12 %", "−3 %", "±0 %"
    static func percent(_ change: Double) -> String {
        let rounded = (change * 100).rounded()
        let sign = rounded > 0 ? "+" : (rounded < 0 ? "−" : "±")
        return "\(sign)\(abs(change).formatted(.percent.precision(.fractionLength(0))))"
    }

    /// Axis label of a bar: "Mon", "W42", "Oct", "2026".
    static func bucketShort(_ date: Date, grouping: AnalysisGrouping, calendar: Calendar, multiYear: Bool) -> String {
        switch grouping {
        case .day: date.formatted(.dateTime.weekday(.abbreviated))
        case .week: String(localized: "W\(calendar.component(.weekOfYear, from: date))")
        case .month: multiYear ? date.formatted(.dateTime.month(.abbreviated).year(.twoDigits)) : date.formatted(.dateTime.month(.abbreviated))
        case .year: date.formatted(.dateTime.year())
        }
    }

    /// Title of the picked bar: "Monday, 19 October", "Week 42 (12–18 Oct)", "October 2026", "2026".
    static func bucketTitle(_ interval: DateInterval, grouping: AnalysisGrouping, calendar: Calendar) -> String {
        switch grouping {
        case .day: return interval.start.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .week:
            let week = calendar.component(.weekOfYear, from: interval.start)
            let range = (interval.start..<interval.end.addingTimeInterval(-1)).formatted(.interval.day().month(.abbreviated))
            return String(localized: "Week \(week) (\(range))")
        case .month: return interval.start.formatted(.dateTime.month(.wide).year())
        case .year: return interval.start.formatted(.dateTime.year())
        }
    }
}

extension AnalysisPeriodKind {
    var label: LocalizedStringKey {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .custom: "Custom"
        case .all: "All"
        }
    }
}

extension AnalysisGrouping {
    var label: LocalizedStringKey {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var perLabel: LocalizedStringKey {
        switch self {
        case .day: "per day"
        case .week: "per week"
        case .month: "per month"
        case .year: "per year"
        }
    }
}
