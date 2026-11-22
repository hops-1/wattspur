import SwiftUI
import WattspurKit

// MARK: - Formatting and labels

/// The texts of the analysis, the same on the Mac and the iPad (B-355). The numbers come from the
/// Kit (`AnalysisSummary`), the words stay in the apps (rule 8), here once for both (rule 6).
enum AnalysisFormat {
    /// "Week 42 · 12–18 Oct", "October 2026", "All Rides".
    static func title(kind: AnalysisPeriodKind, interval: DateInterval?, calendar: Calendar) -> String {
        guard let interval else { return String(localized: "All Rides") }
        let range = interval.start..<interval.end.addingTimeInterval(-1)
        switch kind {
        case .week:
            let week = calendar.component(.weekOfYear, from: interval.start)
            return String(localized: "Week \(week) · \(range.formatted(.interval.day().month(.abbreviated)))")
        case .month: return interval.start.formatted(.dateTime.month(.wide).year())
        case .year: return interval.start.formatted(.dateTime.year())
        case .custom, .all: return range.formatted(.interval.day().month(.abbreviated).year())
        }
    }

    /// The heading of a period, as `title(kind:interval:calendar:)`.
    static func heading(_ summary: AnalysisSummary) -> String {
        title(kind: summary.kind, interval: summary.interval, calendar: summary.calendar)
    }

    /// "12 rides · compared with September" or "12 rides".
    static func subheading(_ summary: AnalysisSummary) -> String {
        let count = summary.current.rideCount
        if let previousInterval = summary.previousInterval {
            let name = previousName(kind: summary.kind, interval: previousInterval, calendar: summary.calendar)
            return String(localized: "\(count) rides · compared with \(name)")
        }
        return String(localized: "\(count) rides")
    }

    /// "vs September" under each figure.
    static func comparisonCaption(_ summary: AnalysisSummary) -> String? {
        summary.previousInterval.map {
            String(localized: "vs \(previousName(kind: summary.kind, interval: $0, calendar: summary.calendar))")
        }
    }

    /// "week 41", "September", "2025", "the same length before".
    static func previousName(kind: AnalysisPeriodKind, interval: DateInterval, calendar: Calendar) -> String {
        switch kind {
        case .week: String(localized: "week \(calendar.component(.weekOfYear, from: interval.start))")
        case .month: interval.start.formatted(.dateTime.month(.wide))
        case .year: interval.start.formatted(.dateTime.year())
        case .custom, .all: String(localized: "the same length before")
        }
    }

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

// `BarMetric` with its values and units is in the Kit (B-294); the texts are here.
extension BarMetric {
    var label: LocalizedStringKey {
        switch self {
        case .distance: "Distance"
        case .time: "Ride time"
        case .ascent: "Ascent"
        }
    }

    func formatted(_ aggregate: RideAggregate) -> String {
        switch self {
        case .distance: ValueFormat.distance(aggregate.distance)
        case .time: AnalysisFormat.hoursMinutes(aggregate.timerTime)
        case .ascent: "\(aggregate.ascent.formatted(.number.precision(.fractionLength(0)))) m"
        }
    }

    /// The label as a plain string, for VoiceOver's chart description.
    var title: String {
        switch self {
        case .distance: String(localized: "Distance")
        case .time: String(localized: "Ride time")
        case .ascent: String(localized: "Ascent")
        }
    }
}
