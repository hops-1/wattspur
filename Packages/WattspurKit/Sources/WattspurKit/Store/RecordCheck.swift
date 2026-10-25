import Foundation
import SwiftData

extension RideLibrary {
    /// Looks at the rides imported after `date` (manually, by drag and drop or from the
    /// watched folder: all of them leave an `ImportRecord`) and returns the records they
    /// broke (ADV-R2). Each broken record is also noted on the ride's import log entry.
    public func newRecords(importedAfter date: Date, calendar: Calendar = .current) -> [RecordBreak] {
        let imported = ImportRecordOutcome.imported.rawValue
        let descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.outcomeRaw == imported && $0.date > date })
        let entries = (try? context.fetch(descriptor)) ?? []
        let importedIDs = Set(entries.compactMap(\.rideID))
        guard !importedIDs.isEmpty else { return [] }

        let counting = ((try? context.fetch(FetchDescriptor<Ride>())) ?? []).filter(\.countsInStatistics)
        let (fresh, existing) = counting.reduce(into: ([HighlightRide](), [HighlightRide]())) { result, ride in
            if importedIDs.contains(ride.id) { result.0.append(ride.highlightRide) } else { result.1.append(ride.highlightRide) }
        }
        let breaks = RideRecords.newRecords(existing: existing, imported: fresh, calendar: calendar)
        for entry in entries {
            let kinds = breaks.filter { $0.rideID == entry.rideID }.map(\.kind)
            if !kinds.isEmpty { entry.recordKinds = kinds }
        }
        try? context.save()
        return breaks
    }

    /// The newest import log entry for a successfully imported ride.
    public func latestImportDate() -> Date? {
        let imported = ImportRecordOutcome.imported.rawValue
        var descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.outcomeRaw == imported }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.date
    }
}
