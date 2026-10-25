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
