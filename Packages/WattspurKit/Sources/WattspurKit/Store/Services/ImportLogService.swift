import Foundation
import SwiftData

/// The import log and the records that imports break (IMP-06, ADV-R2).
struct ImportLogService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    /// Adds a line to the import log for the result of `importFile`.
    @discardableResult
    func record(_ result: ImportResult, source: ImportSource, movedTo: String? = nil,
                date: Date = .now) -> ImportRecord {
        let record: ImportRecord
        switch result.outcome {
        case .imported(let id):
            record = ImportRecord(fileName: result.fileName, outcome: .imported, source: source, date: date)
            record.rideID = id
        case .duplicate(let id), .fitForGPX(let id):
            record = ImportRecord(fileName: result.fileName, outcome: .duplicate, source: source, date: date)
            record.rideID = id
        case .attached(let id):
            record = ImportRecord(fileName: result.fileName, outcome: .attached, source: source, date: date)
            record.rideID = id
        case .unsupported:
            record = ImportRecord(fileName: result.fileName, outcome: .unsupported, source: source, date: date)
        case .failed(let error):
            record = ImportRecord(fileName: result.fileName, outcome: .failed, source: source, date: date)
            record.detail = "\(error)"
        }
        record.movedTo = movedTo
        context.insert(record)
        try? context.save()
        return record
    }

    /// Notes that an existing ride was refreshed from a newer export (IMP-02).
    func recordUpdate(of rideID: UUID, fileName: String, source: ImportSource, date: Date = .now) {
        let record = ImportRecord(fileName: fileName, outcome: .updated, source: source, date: date)
        record.rideID = rideID
        context.insert(record)
        try? context.save()
    }

    /// `true` if an unsupported file of this name is already in the log, so the
    /// watched folder notes files it leaves in place only once.
    func hasRecordedUnsupportedFile(named fileName: String) -> Bool {
        let unsupported = ImportRecordOutcome.unsupported.rawValue
        var descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.fileName == fileName && $0.outcomeRaw == unsupported })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Log entries, newest first.
    func importRecords(limit: Int? = nil) -> [ImportRecord] {
        var descriptor = FetchDescriptor<ImportRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Removes log entries older than `days` (the log is a help, not an archive).
    func trimImportLog(olderThan days: Int = 90, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        try? context.delete(model: ImportRecord.self, where: #Predicate { $0.date < cutoff })
        try? context.save()
    }

    // MARK: - Records (ADV-R2)

    /// Looks at the rides imported after `date` (manually, by drag and drop or from the
    /// watched folder: all of them leave an `ImportRecord`) and returns the records they
    /// broke (ADV-R2). Each broken record is also noted on the ride's import log entry.
    func newRecords(importedAfter date: Date, calendar: Calendar = .current) -> [RecordBreak] {
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
    func latestImportDate() -> Date? {
        let imported = ImportRecordOutcome.imported.rawValue
        var descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.outcomeRaw == imported }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.date
    }
}
