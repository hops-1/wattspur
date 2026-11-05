import Foundation
import WattspurCore

/// Summary shown after an import (simple form of the import log, IMP-06).
public struct ImportReport: Identifiable {
    public struct Entry {
        public let url: URL
        public let result: ImportResult

        public init(url: URL, result: ImportResult) {
            self.url = url
            self.result = result
        }
    }

    public let id = UUID()
    public let entries: [Entry]
    public var extraLines: [String] = []
    /// Results that get their own question (a GPX or a Bosch file for a GPX ride, B-144) and are not
    /// part of the all-at-once question for plain duplicates.
    public var excluded: Set<UUID> = []

    public init(entries: [Entry], extraLines: [String] = []) {
        self.entries = entries
        self.extraLines = extraLines
    }

    /// Rides that were already there and are decided on together (IMP-02).
    public var duplicates: [Entry] {
        entries.filter { $0.result.outcome.existingRideID != nil && !excluded.contains($0.result.id) }
    }

    /// `true` if there is something to tell besides duplicates and attached GPX files, which have
    /// their own question or notice.
    public var hasNews: Bool {
        !extraLines.isEmpty || entries.contains { entry in
            switch entry.result.outcome {
            case .imported, .unsupported, .failed: true
            case .duplicate, .attached, .fitForGPX: false
            }
        }
    }

    /// At most this many file or ride names are listed; the rest is only counted,
    /// so the alert keeps its button on screen even for hundreds of files.
    public static let maxListedNames = 5

    /// Imported count and problems, without duplicates. Unsupported files are
    /// summarised by type instead of being listed one by one.
    private var summaryLines: [String] {
        var imported = 0
        var unsupported: [String] = []
        var unreadable: [String] = []
        for entry in entries {
            switch entry.result.outcome {
            case .imported: imported += 1
            case .duplicate, .attached, .fitForGPX: break
            case .unsupported: unsupported.append(entry.result.fileName)
            case .failed: unreadable.append(entry.result.fileName)
            }
        }
        var lines = entries.isEmpty ? [] : [String(localized: "\(imported) rides imported")]
        if !unsupported.isEmpty {
            let types = Set(unsupported.map(Self.typeLabel)).sorted().formatted(.list(type: .and))
            lines.append(String(localized: "\(unsupported.count) files skipped, file type not supported yet: \(types)"))
        }
        lines += Self.unreadableLines(unreadable) + extraLines
        return lines
    }

    /// "x.fit: file could not be read" for the first few, then "3 more files could not be read".
    public static func unreadableLines(_ fileNames: [String]) -> [String] {
        var lines = fileNames.prefix(maxListedNames).map { String(localized: "\($0): file could not be read") }
        let rest = fileNames.count - maxListedNames
        if rest > 0 { lines.append(String(localized: "\(rest) more files could not be read")) }
        return lines
    }

    /// ".gpx", or "no extension".
    private static func typeLabel(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext.isEmpty ? String(localized: "no extension") : ".\(ext)"
    }

    public var message: String { summaryLines.joined(separator: "\n") }

    /// Message of the duplicate dialog: what happened so far, then the question.
    public var duplicateQuestion: String {
        var names = duplicates.prefix(Self.maxListedNames).map { RideLibrary.parseFileName($0.result.fileName).title }
        let rest = duplicates.count - Self.maxListedNames
        if rest > 0 { names.append(String(localized: "\(rest) more")) }
        var lines = summaryLines
        lines.append(String(localized: "Already in your library: \(names.formatted(.list(type: .and)))"))
        lines.append(String(localized: "Update them from the new files? Your names are kept."))
        return lines.joined(separator: "\n")
    }
}
