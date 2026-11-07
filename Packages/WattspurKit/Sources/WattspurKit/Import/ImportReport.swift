import Foundation
import WattspurCore

/// Summary shown after an import (simple form of the import log, IMP-06). It holds what happened;
/// each app words it (`ImportReport+Text.swift`), as the Kit has no texts (rule 8, R-48).
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
    /// Files whose update from a newer export failed (after a duplicate question).
    public var failedUpdates: [String] = []
    /// Results that get their own question (a GPX or a Bosch file for a GPX ride, B-144) and are not
    /// part of the all-at-once question for plain duplicates.
    public var excluded: Set<UUID> = []

    public init(entries: [Entry], failedUpdates: [String] = []) {
        self.entries = entries
        self.failedUpdates = failedUpdates
    }

    /// Rides that were already there and are decided on together (IMP-02).
    public var duplicates: [Entry] {
        entries.filter { $0.result.outcome.existingRideID != nil && !excluded.contains($0.result.id) }
    }

    /// `true` if there is something to tell besides duplicates and attached GPX files, which have
    /// their own question or notice.
    public var hasNews: Bool {
        !failedUpdates.isEmpty || entries.contains { entry in
            switch entry.result.outcome {
            case .imported, .unsupported, .failed: true
            case .duplicate, .attached, .fitForGPX: false
            }
        }
    }

    /// At most this many file or ride names are listed; the rest is only counted,
    /// so the alert keeps its button on screen even for hundreds of files.
    public static let maxListedNames = 5

    /// Rides the import added.
    public var importedCount: Int {
        entries.filter { if case .imported = $0.result.outcome { true } else { false } }.count
    }

    /// Files of a type Wattspur does not read.
    public var unsupportedFileNames: [String] {
        entries.compactMap { if case .unsupported = $0.result.outcome { $0.result.fileName } else { nil } }
    }

    /// The types of those files, e.g. "gpx", sorted; "" for a file without an extension.
    public var unsupportedExtensions: [String] {
        Set(unsupportedFileNames.map { ($0 as NSString).pathExtension.lowercased() }).sorted()
    }

    /// Files that could not be read or imported, then those whose update failed.
    public var unreadableFileNames: [String] {
        entries.compactMap { if case .failed = $0.result.outcome { $0.result.fileName } else { nil } } + failedUpdates
    }

    /// The titles of the plain duplicates, for the question about them.
    public var duplicateTitles: [String] {
        duplicates.map { RideLibrary.parseFileName($0.result.fileName).title }
    }
}
