import Charts
import SwiftData
import SwiftUI
import WattspurKit

/// The rides as plain values, computed once per redraw: the summary from the Kit
/// (`HighlightsSummary`, B-294) and the rides by id, for names and for opening one.
@MainActor
struct HighlightsData {
    let summary: HighlightsSummary
    let byID: [UUID: Ride]

    init(rides: [Ride], calendar: Calendar) {
        summary = HighlightsSummary(rides: rides.map(\.highlightRide), calendar: calendar)
        byID = Dictionary(rides.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var highlightRides: [HighlightRide] { summary.rides }
    var records: [RideRecord] { summary.records }
    var calendar: Calendar { summary.calendar }
    var names: [UUID: String] { byID.mapValues(\.name) }

    /// Years with rides plus the current one, newest first.
    func years(including current: Int) -> [Int] { summary.years(including: current) }
}

// MARK: - Formatting
