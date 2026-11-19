import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Model

/// Everything the analysis shows: the numbers from the Kit (`AnalysisSummary`, B-294) and the
/// headings, which are texts and stay in the app (rule 8).
@dynamicMemberLookup
struct AnalysisModel {
    let summary: AnalysisSummary
    let heading: String
    let subheading: String

    init(rides: [Ride], selection: Set<UUID>?, period: AnalysisPeriod, groupingChoice: AnalysisGrouping?,
         calendar: Calendar, calories: CalorieModel = .fromWork, now: Date = .now) {
        // The sample ride counts only when it was selected on purpose (ONB-02).
        let all = rides.filter { !$0.isSample }.map(\.figures)
        let selected = selection.map { ids in rides.filter { ids.contains($0.id) }.map(\.figures) }
        summary = AnalysisSummary(all: all, selected: selected, period: period, groupingChoice: groupingChoice,
                                  calendar: calendar, calories: calories, now: now)

        let count = summary.current.rideCount
        if summary.isSelection {
            heading = String(localized: "\(count) selected rides")
            subheading = String(localized: "Selected in Rides")
        } else {
            heading = Self.title(kind: period.kind, interval: summary.interval, calendar: calendar)
            if let previousInterval = summary.previousInterval {
                let name = Self.previousName(kind: period.kind, interval: previousInterval, calendar: calendar)
                subheading = String(localized: "\(count) rides · compared with \(name)")
            } else {
                subheading = String(localized: "\(count) rides")
            }
        }
    }

    subscript<T>(dynamicMember keyPath: KeyPath<AnalysisSummary, T>) -> T { summary[keyPath: keyPath] }

    /// "vs September" under each figure.
    var comparisonCaption: String? {
        summary.previousInterval.map { String(localized: "vs \(Self.previousName(kind: summary.kind, interval: $0, calendar: summary.calendar))") }
    }

    func change(_ value: (RideAggregate) -> Double?) -> Double? { summary.change(value) }

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

    static func previousName(kind: AnalysisPeriodKind, interval: DateInterval, calendar: Calendar) -> String {
        switch kind {
        case .week: String(localized: "week \(calendar.component(.weekOfYear, from: interval.start))")
        case .month: interval.start.formatted(.dateTime.month(.wide))
        case .year: interval.start.formatted(.dateTime.year())
        case .custom, .all: String(localized: "the same length before")
        }
    }
}
