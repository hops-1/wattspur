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

        if summary.isSelection {
            heading = String(localized: "\(summary.current.rideCount) selected rides")
            subheading = String(localized: "Selected in Rides")
        } else {
            heading = AnalysisFormat.heading(summary)
            subheading = AnalysisFormat.subheading(summary)
        }
    }

    subscript<T>(dynamicMember keyPath: KeyPath<AnalysisSummary, T>) -> T { summary[keyPath: keyPath] }

    /// "vs September" under each figure.
    var comparisonCaption: String? { AnalysisFormat.comparisonCaption(summary) }

    func change(_ value: (RideAggregate) -> Double?) -> Double? { summary.change(value) }
}
