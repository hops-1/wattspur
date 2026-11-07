import Foundation
import Observation
import WattspurCore

/// Writes down what an import did, e.g. the Mac's `ImportLog` (IMP-06, SUP-01).
public typealias ImportRecorder = @MainActor (ImportResult, URL) -> Void

/// The manual import from the drop to the last question (IMP-04, B-144): which bike a GPX file
/// belongs to, what to do with a ride that is already there, and the notice that a GPX was
/// attached. Used by the ride list and the import window on the Mac and by “Open with” on the
/// iPhone (B-071, B-188); the watched folder asks nobody. Only the decisions live here, each app
/// draws its own sheets.
@MainActor
@Observable
public final class ImportFlow {
    /// GPX files carry no bike, so they are asked for it from two bikes on; recordings of the
    /// iPhone app name theirs (B-213).
    public struct BikeQuestion: Identifiable {
        public let id = UUID()
        public let urls: [URL]
        public var gpxURLs: [URL] { urls.filter(ImportFlow.isGPX) }
    }

    /// A file that looks like a ride in the library and needs a decision (mockup "Duplikate FIT/GPX").
    public struct Comparison: Identifiable {
        public enum Kind {
            /// A Bosch FIT for a ride that is there as GPX only.
            case fitForGPX
            /// Another GPX file of a ride that is already a GPX ride.
            case gpxForGPX
            /// A GPX for a Bosch ride that has one attached already.
            case gpxForFIT
        }

        public let id = UUID()
        public let entry: ImportReport.Entry
        public let rideID: UUID
        public let rideName: String
        public let bikeID: UUID?
        public let kind: Kind
        public let existing: DuplicateFacts
        public let incoming: DuplicateFacts?
    }

    /// The notice after GPX files were attached to rides (mockup "attached").
    public struct Attached: Equatable {
        public var rideIDs: [UUID]
        public var rideName: String
        /// `true` if heart rate or temperature came with the file.
        public var sensors: Bool
    }

    public var bikeQuestion: BikeQuestion? {
        // Cancelled by the app: the next waiting import may start. Answered, `confirm` starts it after
        // this one has run.
        didSet { if bikeQuestion == nil, !confirming { startWaitingIfIdle() } }
    }
    public var comparisons: [Comparison] = []
    /// The summary alert.
    public var report: ImportReport?
    /// Duplicates of two FIT files: the old question for all of them at once (IMP-02).
    public var plainDuplicates: ImportReport? {
        didSet { if plainDuplicates == nil { startWaitingIfIdle() } }
    }
    public var attached: Attached?
    /// Called with the rides a run added, e.g. to select the last one and look for merge suggestions.
    public var onImported: ([UUID]) -> Void = { _ in }
    /// Called to show a ride; `nil` where the view cannot.
    public var onSelect: ((UUID) -> Void)?

    private var bikeID: UUID?
    private var afterComparisons: (() -> Void)?
    private var failedUpdates: [String] = []
    /// Imports that came while a question of an earlier one was open; they start once it is
    /// answered, so they do not replace it (R-46).
    private var waiting: [() -> Void] = []
    private var confirming = false

    /// A question of an import is open.
    public var isAsking: Bool { bikeQuestion != nil || !comparisons.isEmpty || plainDuplicates != nil }

    public init() {}

    nonisolated public static func isGPX(_ url: URL) -> Bool { url.pathExtension.lowercased() == "gpx" }

    // MARK: - Start

    /// Imports the files, or asks for the bike first when GPX files are among them and there are
    /// two or more bikes.
    public func start(_ urls: [URL], library: RideLibrary, record: @escaping ImportRecorder) {
        guard !urls.isEmpty else { return }
        guard !isAsking else {
            waiting.append { [weak self] in self?.start(urls, library: library, record: record) }
            return
        }
        let asking = urls.filter(Self.isGPX).contains { !Self.namesKnownBike($0, library: library) }
        if asking, library.bikes(includingArchived: false).count >= 2 {
            bikeQuestion = BikeQuestion(urls: urls)
        } else {
            run(urls, gpxBike: nil, library: library, record: record)
        }
    }

    /// `true` for a recording of the iPhone app that names a bike of the library (B-213): it needs
    /// no question. Reads only the first bytes of the file.
    private static func namesKnownBike(_ url: URL, library: RideLibrary) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 4096),
              let bikeID = GPXRideImporter.header(of: head).bikeID else { return false }
        return library.bikes(includingArchived: true).contains { $0.id == bikeID }
    }

    public func confirm(_ question: BikeQuestion, bike: Bike, library: RideLibrary, record: @escaping ImportRecorder) {
        confirming = true
        bikeQuestion = nil
        confirming = false
        run(question.urls, gpxBike: bike, library: library, record: record)
        startWaitingIfIdle()
    }

    private func run(_ urls: [URL], gpxBike: Bike?, library: RideLibrary, record: ImportRecorder) {
        bikeID = gpxBike?.id
        let entries = urls.map { url -> ImportReport.Entry in
            let result = Self.isGPX(url) ? library.importFile(at: url, bike: gpxBike) : library.importFile(at: url)
            record(result, url)
            library.record(result, source: .manual)
            return ImportReport.Entry(url: url, result: result)
        }
        finish(entries, library: library)
    }

    private func finish(_ entries: [ImportReport.Entry], library: RideLibrary) {
        let imported = entries.compactMap { entry -> UUID? in
            if case .imported(let id) = entry.result.outcome { id } else { nil }
        }
        if !imported.isEmpty { onImported(imported) }

        let attachedIDs = entries.compactMap { entry -> UUID? in
            if case .attached(let id) = entry.result.outcome { id } else { nil }
        }
        if let first = attachedIDs.first, let ride = library.ride(withID: first) {
            let sensors = attachedIDs.compactMap { library.ride(withID: $0) }
                .contains { $0.samples.contains { $0.heartRate != nil || $0.temperature != nil } }
            attached = Attached(rideIDs: attachedIDs, rideName: ride.name, sensors: sensors)
        }

        var comparisons: [Comparison] = []
        var report = ImportReport(entries: entries)
        for entry in entries {
            guard let id = entry.result.outcome.existingRideID, let ride = library.ride(withID: id),
                  let kind = Self.kind(of: entry, existing: ride) else { continue }
            comparisons.append(Comparison(entry: entry, rideID: id, rideName: ride.name, bikeID: bikeID ?? ride.bike?.id,
                                          kind: kind, existing: DuplicateFacts(ride: ride), incoming: library.facts(ofFileAt: entry.url)))
            report.excluded.insert(entry.result.id)
        }

        let conclude = { [self] in
            if !report.duplicates.isEmpty {
                plainDuplicates = report
            } else if report.hasNews {
                self.report = report
            }
        }
        if comparisons.isEmpty {
            conclude()
        } else {
            afterComparisons = conclude
            self.comparisons = comparisons
        }
    }

    /// Which question a duplicate asks; `nil` for two FIT files, which keep the old one.
    private static func kind(of entry: ImportReport.Entry, existing: Ride) -> Comparison.Kind? {
        switch (isGPX(entry.url), existing.source) {
        case (false, .gpx?): .fitForGPX
        case (true, .gpx?): .gpxForGPX
        case (true, .fit?): .gpxForFIT
        default: nil
        }
    }

    // MARK: - Decisions

    /// Leave the file out; the log keeps the line "duplicate".
    public func skip() {
        advance()
    }

    /// Take the new file's values; name, notes, bike and flags stay (IMP-02).
    public func update(_ comparison: Comparison, library: RideLibrary) {
        if let ride = library.ride(withID: comparison.rideID) {
            do {
                try library.update(ride, withFileAt: comparison.entry.url)
                library.recordUpdate(of: ride.id, fileName: comparison.entry.result.fileName, source: .manual)
            } catch {
                failedUpdates.append(comparison.entry.result.fileName)
            }
        }
        advance()
    }

    /// Keep both: the file becomes a ride of its own.
    public func importAsNew(_ comparison: Comparison, library: RideLibrary, record: ImportRecorder) {
        let bike = comparison.bikeID.flatMap { id in library.bikes(includingArchived: false).first { $0.id == id } }
        let result = library.importFile(at: comparison.entry.url, bike: bike, detectDuplicates: false)
        record(result, comparison.entry.url)
        library.record(result, source: .manual)
        if case .imported(let id) = result.outcome { onImported([id]) }
        advance()
    }

    private func advance() {
        if !comparisons.isEmpty { comparisons.removeFirst() }
        guard comparisons.isEmpty else { return }
        let next = afterComparisons
        afterComparisons = nil
        next?()
        if !failedUpdates.isEmpty {
            report = ImportReport(entries: [], failedUpdates: failedUpdates)
            failedUpdates = []
        }
        startWaitingIfIdle()
    }

    /// Starts the next waiting import once no question is open.
    private func startWaitingIfIdle() {
        guard !isAsking, !waiting.isEmpty else { return }
        waiting.removeFirst()()
    }

    /// The plain duplicates: update all of them from the new files.
    public func updatePlainDuplicates(_ report: ImportReport, library: RideLibrary) {
        var failed: [String] = []
        for entry in report.duplicates {
            guard let id = entry.result.outcome.existingRideID, let ride = library.ride(withID: id) else { continue }
            do {
                try library.update(ride, withFileAt: entry.url)
                library.recordUpdate(of: id, fileName: entry.result.fileName, source: .manual)
            } catch {
                failed.append(entry.result.fileName)
            }
        }
        plainDuplicates = nil
        if !failed.isEmpty {
            self.report = ImportReport(entries: [], failedUpdates: failed)
        }
    }
}
