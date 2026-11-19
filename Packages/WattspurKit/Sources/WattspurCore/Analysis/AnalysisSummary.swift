import Foundation

// The numbers of the "Analysis" section for one period or a selection (B-294). The Mac and the
// iPad add their own headings; the texts stay in the apps (rule 8).

/// Everything the analysis shows, computed once per redraw from the rides and the period.
public struct AnalysisSummary: Sendable {
    public let calendar: Calendar
    /// How calories are estimated; the info next to them says so.
    public let calories: CalorieModel
    public let isSelection: Bool
    public let kind: AnalysisPeriodKind
    /// The period itself; `nil` for "all" and for a selection.
    public let interval: DateInterval?
    /// The analysed rides, oldest first.
    public let figures: [RideFigures]
    public let current: RideAggregate
    /// `nil` when there is nothing to compare with ("all" or a selection).
    public let previous: RideAggregate?
    public let previousInterval: DateInterval?
    /// The span the charts cover.
    public let chartInterval: DateInterval?
    public let grouping: AnalysisGrouping
    public let buckets: [RideBucket]

    /// - Parameters:
    ///   - all: every ride that counts, without the sample ride (ONB-02).
    ///   - selected: the rides chosen in the list, or `nil` to analyse the period. The sample
    ///     ride counts here when it was selected on purpose.
    public init(all: [RideFigures], selected: [RideFigures]?, period: AnalysisPeriod,
                groupingChoice: AnalysisGrouping?, calendar: Calendar, calories: CalorieModel = .fromWork,
                now: Date = .now) {
        self.calendar = calendar
        self.calories = calories
        isSelection = selected != nil
        kind = period.kind
        let chosen: [RideFigures]
        let chartSpan: DateInterval?
        if let selected {
            chosen = RideAnalysis.rides(selected, in: nil)
            interval = nil
            previousInterval = nil
            if let first = chosen.first, let week = calendar.dateInterval(of: .weekOfYear, for: first.startDate) {
                let lastStart = chosen.last?.startDate ?? first.startDate
                chartSpan = DateInterval(start: week.start, end: max(week.end, lastStart.addingTimeInterval(1)))
            } else {
                chartSpan = nil
            }
            grouping = groupingChoice ?? .week
        } else {
            let periodInterval = period.interval(now: now, calendar: calendar)
            interval = periodInterval
            chosen = RideAnalysis.rides(all, in: periodInterval)
            previousInterval = period.previousInterval(now: now, calendar: calendar)
            chartSpan = periodInterval ?? RideAnalysis.span(of: all, now: now)
            grouping = groupingChoice ?? period.kind.defaultGrouping
        }
        let groupedBy = grouping
        figures = chosen
        chartInterval = chartSpan
        current = RideAggregate(chosen, calories: calories)
        previous = previousInterval.map { RideAggregate(RideAnalysis.rides(all, in: $0), calories: calories) }
        buckets = chartSpan.map { RideAnalysis.buckets(chosen, grouping: groupedBy, in: $0, calendar: calendar) } ?? []
    }

    /// The change against the previous period, as a fraction; `nil` without one.
    public func change(_ value: (RideAggregate) -> Double?) -> Double? {
        guard let previous else { return nil }
        return Change.relative(from: value(previous), to: value(current))
    }
}

/// What the bar chart of the analysis shows (AGG-04, TREND-02). The raw values are stored in the
/// settings, so they must not change.
public enum BarMetric: String, CaseIterable, Identifiable, Sendable {
    case distance, time, ascent

    public var id: Self { self }

    /// km, hours or metres.
    public func value(_ aggregate: RideAggregate) -> Double {
        switch self {
        case .distance: aggregate.distance / 1000
        case .time: aggregate.timerTime / 3600
        case .ascent: aggregate.ascent
        }
    }

    /// The unit on the axis; symbols, not words.
    public var axisUnit: String {
        switch self {
        case .distance: "km"
        case .time: "h"
        case .ascent: "m"
        }
    }
}

/// The rides of the "Highlights" section as plain values (B-294): records and the years for the
/// year in review. The apps look up names and rides by id.
public struct HighlightsSummary: Sendable {
    public let rides: [HighlightRide]
    public let records: [RideRecord]
    public let calendar: Calendar

    public init(rides: [HighlightRide], calendar: Calendar) {
        self.rides = rides
        records = RideRecords.records(rides, calendar: calendar)
        self.calendar = calendar
    }

    /// Years with rides plus the current one, newest first.
    public func years(including current: Int) -> [Int] {
        Array(Set(YearReview.years(of: rides, calendar: calendar) + [current])).sorted(by: >)
    }
}

/// How the rides of a comparison stay apart without colour (NFR-16): a dash pattern and a marker
/// shape per column. The colours stay in the apps.
public enum ComparisonMarks {
    /// Line dashes in points; the first ride is solid.
    public static let dashes: [[Double]] = [[], [7, 4], [2, 3], [9, 3, 2, 3]]
    /// SF Symbol names of the markers.
    public static let markers = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill"]

    public static func dash(_ index: Int) -> [Double] { dashes[index % dashes.count] }
    public static func marker(_ index: Int) -> String { markers[index % markers.count] }
}
