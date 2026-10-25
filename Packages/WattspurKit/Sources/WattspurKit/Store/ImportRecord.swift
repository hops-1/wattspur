import Foundation
import SwiftData

/// How a file reached Wattspur.
public enum ImportSource: String, Sendable, Codable {
    /// Dropped on the window or chosen in the open panel.
    case manual
    /// Picked up from the watched folder (IMP-05).
    case folder
}

/// What happened to a file, as stored in the import log (IMP-06).
public enum ImportRecordOutcome: String, Sendable, Codable {
    case imported, updated, duplicate, unsupported, failed
    /// A GPX file was attached to a Bosch ride (B-143).
    case attached

    /// Entries the user should look at.
    public var needsAttention: Bool { self == .failed }
}

/// One persistent line of the import log (IMP-06). Survives restarts, unlike the
/// alert after a manual import. CloudKit-compatible like the other models.
@Model
public final class ImportRecord {
    public var id: UUID = UUID()
    public var date: Date = Date.now
    public var fileName: String = ""
    public var outcomeRaw: String = ImportRecordOutcome.imported.rawValue
    public var sourceRaw: String = ImportSource.manual.rawValue
    /// Technical reason for a failure, e.g. "decoding(checksumMismatch…)".
    public var detail: String = ""
    public var rideID: UUID?
    /// Where the file is now, relative to the watched folder, e.g. "Failed/x.fit".
    public var movedTo: String?
    /// Records the imported ride broke (ADV-R2), `RecordKind` raw values separated by commas.
    public var recordKindsRaw: String = ""

    public init(fileName: String, outcome: ImportRecordOutcome, source: ImportSource, date: Date = .now) {
        self.fileName = fileName
        self.outcomeRaw = outcome.rawValue
        self.sourceRaw = source.rawValue
        self.date = date
    }

    public var outcome: ImportRecordOutcome { ImportRecordOutcome(rawValue: outcomeRaw) ?? .failed }
    public var source: ImportSource { ImportSource(rawValue: sourceRaw) ?? .manual }

    /// Records the imported ride broke, in `RecordKind` order.
    public var recordKinds: [RecordKind] {
        get {
            let raw = Set(recordKindsRaw.split(separator: ",").map(String.init))
            return RecordKind.allCases.filter { raw.contains($0.rawValue) }
        }
        set { recordKindsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    /// The line for a diagnostic report (SUP-01).
    public var logEntry: ImportLogEntry {
        ImportLogEntry(date: date, fileName: fileName,
                       outcome: detail.isEmpty ? outcomeRaw : "\(outcomeRaw): \(detail)")
    }
}

extension RideLibrary {
    /// Adds a line to the import log for the result of `importFile`.
    @discardableResult
    public func record(_ result: ImportResult, source: ImportSource, movedTo: String? = nil,
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
    public func recordUpdate(of rideID: UUID, fileName: String, source: ImportSource, date: Date = .now) {
        let record = ImportRecord(fileName: fileName, outcome: .updated, source: source, date: date)
        record.rideID = rideID
        context.insert(record)
        try? context.save()
    }

    /// `true` if an unsupported file of this name is already in the log, so the
    /// watched folder notes files it leaves in place only once.
    public func hasRecordedUnsupportedFile(named fileName: String) -> Bool {
        let unsupported = ImportRecordOutcome.unsupported.rawValue
        var descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.fileName == fileName && $0.outcomeRaw == unsupported })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Log entries, newest first.
    public func importRecords(limit: Int? = nil) -> [ImportRecord] {
        var descriptor = FetchDescriptor<ImportRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Removes log entries older than `days` (the log is a help, not an archive).
    public func trimImportLog(olderThan days: Int = 90, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        try? context.delete(model: ImportRecord.self, where: #Predicate { $0.date < cutoff })
        try? context.save()
    }
}
