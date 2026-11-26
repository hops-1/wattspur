import Foundation
import WattspurKit

/// The words for the summary of many files (B-300): “12 new, 3 completed, 1 duplicate”, then the
/// files that could not be read.
extension ImportFlow.Summary {
    var message: String {
        var counts: [String] = []
        if newRides > 0 { counts.append(String(localized: "\(newRides) new")) }
        if plannedTours > 0 { counts.append(String(localized: "\(plannedTours) planned tours")) }
        if completed > 0 { counts.append(String(localized: "\(completed) completed")) }
        if duplicates > 0 { counts.append(String(localized: "\(duplicates) duplicates")) }
        var lines = counts.isEmpty ? [] : [counts.joined(separator: ", ")]
        if !unsupportedFileNames.isEmpty {
            lines.append(String(localized: "\(unsupportedFileNames.count) files skipped, file type not supported"))
        }
        let limit = ImportReport.maxListedNames
        lines += failedFileNames.prefix(limit).map { String(localized: "\($0): file could not be read") }
        let rest = failedFileNames.count - limit
        if rest > 0 { lines.append(String(localized: "\(rest) more files could not be read")) }
        lines += plannedRouteFileNames.prefix(limit).map { String(localized: "\($0): this is a planned route, not a ride") }
        if !plannedRouteFileNames.isEmpty {
            lines.append(String(localized: "Export the tour again after you have ridden it, then it has times and becomes a ride."))
        }
        return lines.joined(separator: "\n")
    }
}
