import Foundation

/// One line of the import log (IMP-06) as it appears in a diagnostic report.
public struct ImportLogEntry: Sendable, Identifiable, Equatable {
    public let id = UUID()
    public var date: Date
    public var fileName: String
    /// "imported", "duplicate", "unsupported" or "failed: …"
    public var outcome: String

    public init(date: Date, fileName: String, outcome: String) {
        self.date = date
        self.fileName = fileName
        self.outcome = outcome
    }

    public init(result: ImportResult, date: Date = .now) {
        let outcome: String
        switch result.outcome {
        case .imported: outcome = "imported"
        case .duplicate: outcome = "duplicate"
        case .attached: outcome = "attached to a Bosch ride"
        case .fitForGPX: outcome = "matches a GPX ride"
        case .unsupported: outcome = "unsupported file type"
        case .failed(let error): outcome = "failed: \(error)"
        }
        self.init(date: date, fileName: result.fileName, outcome: outcome)
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.date == b.date && a.fileName == b.fileName && a.outcome == b.outcome
    }
}

/// Text report for "Create Diagnostics…" (SUP-01). Contains versions, counts and
/// the import log – never positions, ride names or other personal ride data.
/// Nothing is sent automatically; the user saves the report and decides.
public struct DiagnosticReport: Sendable {
    public var appVersion: String
    public var build: String
    public var commit: String
    public var parserVersion: Int
    /// Version of the GPX parser (B-141); `parserVersion` stays the FIT parser's.
    public var gpxParserVersion: Int
    public var osVersion: String
    public var locale: String
    public var rideCount: Int
    public var trashedRideCount: Int
    /// Parser version → number of stored rides with it.
    public var ridesByParserVersion: [Int: Int]
    /// The same for rides imported from GPX files.
    public var gpxRidesByParserVersion: [Int: Int]
    public var importLog: [ImportLogEntry]
    public var createdAt: Date

    public init(appVersion: String, build: String, commit: String,
                parserVersion: Int = FITRideImporter.parserVersion,
                gpxParserVersion: Int = GPXRideImporter.parserVersion,
                osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
                locale: String = Locale.current.identifier,
                rideCount: Int, trashedRideCount: Int, ridesByParserVersion: [Int: Int],
                gpxRidesByParserVersion: [Int: Int] = [:],
                importLog: [ImportLogEntry], createdAt: Date = .now) {
        self.appVersion = appVersion
        self.build = build
        self.commit = commit
        self.parserVersion = parserVersion
        self.gpxParserVersion = gpxParserVersion
        self.osVersion = osVersion
        self.locale = locale
        self.rideCount = rideCount
        self.trashedRideCount = trashedRideCount
        self.ridesByParserVersion = ridesByParserVersion
        self.gpxRidesByParserVersion = gpxRidesByParserVersion
        self.importLog = importLog
        self.createdAt = createdAt
    }

    /// Plain text, English on purpose so the developer can read every report.
    public var text: String {
        let iso = ISO8601DateFormatter()
        var lines = [
            "Wattspur diagnostic report",
            "Created: \(iso.string(from: createdAt))",
            "",
            "App version: \(appVersion) (build \(build), commit \(commit))",
            "Parser version: \(parserVersion)",
            "GPX parser version: \(gpxParserVersion)",
            "macOS: \(osVersion)",
            "Locale: \(locale)",
            "",
            "Rides: \(rideCount) (in trash: \(trashedRideCount))",
            "Rides by parser version: " + (ridesByParserVersion.isEmpty ? "–" :
                ridesByParserVersion.keys.sorted().map { "v\($0): \(ridesByParserVersion[$0] ?? 0)" }.joined(separator: ", ")),
            "GPX rides by parser version: " + (gpxRidesByParserVersion.isEmpty ? "–" :
                gpxRidesByParserVersion.keys.sorted().map { "v\($0): \(gpxRidesByParserVersion[$0] ?? 0)" }.joined(separator: ", ")),
            "",
            "Import log (this session, newest first):",
        ]
        if importLog.isEmpty {
            lines.append("  (no imports)")
        } else {
            for entry in importLog.sorted(by: { $0.date > $1.date }) {
                lines.append("  \(iso.string(from: entry.date))  \(entry.outcome)  \(entry.fileName)")
            }
        }
        lines.append("")
        lines.append("This report contains no positions, ride names or other ride data.")
        return lines.joined(separator: "\n")
    }
}
