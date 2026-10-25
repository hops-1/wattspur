import Charts
import SwiftData
import SwiftUI
import WattspurKit

/// The rides as plain values, computed once per redraw.
@MainActor
struct HighlightsData {
    let highlightRides: [HighlightRide]
    let byID: [UUID: Ride]
    let records: [RideRecord]
    let calendar: Calendar

    init(rides: [Ride], calendar: Calendar) {
        highlightRides = rides.map(\.highlightRide)
        byID = Dictionary(rides.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        records = RideRecords.records(highlightRides, calendar: calendar)
        self.calendar = calendar
    }

    var names: [UUID: String] { byID.mapValues(\.name) }

    /// Years with rides plus the current one, newest first.
    func years(including current: Int) -> [Int] {
        Array(Set(YearReview.years(of: highlightRides, calendar: calendar) + [current])).sorted(by: >)
    }
}

// MARK: - Formatting
