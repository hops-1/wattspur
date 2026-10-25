import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Model

/// Everything the analysis shows, computed once per redraw from the rides and the period.
struct AnalysisModel {
    let calendar: Calendar
    /// How calories are estimated; the info next to them says so.
    let calories: CalorieModel
    let isSelection: Bool
    let kind: AnalysisPeriodKind
    /// The analysed rides, oldest first.
    let figures: [RideFigures]
    let current: RideAggregate
    /// `nil` when there is nothing to compare with ("all" or a selection).
    let previous: RideAggregate?
    let previousInterval: DateInterval?
    /// The span the charts cover.
    let chartInterval: DateInterval?
    let grouping: AnalysisGrouping
    let buckets: [RideBucket]
    let heading: String
    let subheading: String

    init(rides: [Ride], selection: Set<UUID>?, period: AnalysisPeriod, groupingChoice: AnalysisGrouping?,
         calendar: Calendar, calories: CalorieModel = .fromWork, now: Date = .now) {
        self.calendar = calendar
        self.calories = calories
        // The sample ride counts only when it was selected on purpose (ONB-02).
        let all = rides.filter { !$0.isSample }.map(\.figures)
        isSelection = selection != nil
        kind = period.kind
        let selected: [RideFigures]
        let chartSpan: DateInterval?
        if let selection {
            selected = RideAnalysis.rides(rides.filter { selection.contains($0.id) }.map(\.figures), in: nil)
            previousInterval = nil
            if let first = selected.first, let week = calendar.dateInterval(of: .weekOfYear, for: first.startDate) {
                let lastStart = selected.last?.startDate ?? first.startDate
                chartSpan = DateInterval(start: week.start, end: max(week.end, lastStart.addingTimeInterval(1)))
            } else {
                chartSpan = nil
            }
            grouping = groupingChoice ?? .week
        } else {
            let interval = period.interval(now: now, calendar: calendar)
            selected = RideAnalysis.rides(all, in: interval)
            previousInterval = period.previousInterval(now: now, calendar: calendar)
            chartSpan = interval ?? RideAnalysis.span(of: all, now: now)
            grouping = groupingChoice ?? period.kind.defaultGrouping
        }
        let groupedBy = grouping
        figures = selected
        chartInterval = chartSpan
        current = RideAggregate(selected, calories: calories)
        previous = previousInterval.map { RideAggregate(RideAnalysis.rides(all, in: $0), calories: calories) }
        buckets = chartSpan.map { RideAnalysis.buckets(selected, grouping: groupedBy, in: $0, calendar: calendar) } ?? []

        let count = current.rideCount
        if isSelection {
            heading = String(localized: "\(count) selected rides")
            subheading = String(localized: "Selected in Rides")
        } else {
            let interval = period.interval(now: now, calendar: calendar)
            heading = Self.title(kind: period.kind, interval: interval, calendar: calendar)
            if let previousInterval {
                let name = Self.previousName(kind: period.kind, interval: previousInterval, calendar: calendar)
                subheading = String(localized: "\(count) rides · compared with \(name)")
            } else {
                subheading = String(localized: "\(count) rides")
            }
        }
    }

    /// "vs September" under each figure.
    var comparisonCaption: String? {
        previousInterval.map { String(localized: "vs \(Self.previousName(kind: kind, interval: $0, calendar: calendar))") }
    }

    func change(_ value: (RideAggregate) -> Double?) -> Double? {
        guard let previous else { return nil }
        return Change.relative(from: value(previous), to: value(current))
    }

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
