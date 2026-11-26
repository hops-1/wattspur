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

    /// A GPX file whose times look estimated (B-372, V-22): ride or planned tour? Sheet A of B-371
    /// shows the line, name, km and metres of ascent; for a komoot file the tour is preselected.
    public struct TourQuestion: Identifiable {
        public let id = UUID()
        public let url: URL
        /// The file read as a tour, for the preview.
        public let tour: PlannedTour
        /// `true` for a komoot tour: “Planned tour” is preselected, otherwise “Ride”.
        public let suggestsTour: Bool
        public var fileName: String { url.lastPathComponent }
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
        didSet {
            guard bikeQuestion == nil, !confirming else { return }
            // Cancelled: the files are left out, and so are the answers kept for them.
            for url in oldValue?.urls ?? [] { kinds[url] = nil }
            startWaitingIfIdle()
        }
    }
    public var comparisons: [Comparison] = []
    /// The open question “Ride or planned tour?” (B-372); the next ones wait in `tourRun`. Answered
    /// with `answer(_:asTour:)` or `skip(_:)`.
    public private(set) var tourQuestion: TourQuestion?
    /// The summary alert.
    public var report: ImportReport?
    /// Duplicates of two FIT files: the old question for all of them at once (IMP-02).
    public var plainDuplicates: ImportReport? {
        didSet {
            // Closed without updating: the files were left out.
            if plainDuplicates == nil, let oldValue, !updatingPlainDuplicates { summary.duplicates += oldValue.duplicates.count }
            if plainDuplicates == nil { startWaitingIfIdle() }
        }
    }
    private var updatingPlainDuplicates = false
    public var attached: Attached?

    /// How far a run of many files is (B-300); `nil` when none is running.
    public struct Progress: Equatable, Sendable {
        public var done: Int
        public var total: Int
    }

    /// What the imports did since the last `takeSummary()`, once every question is answered (B-300):
    /// “12 new, 3 added, 1 duplicate”. The apps word it.
    public struct Summary: Equatable, Sendable {
        /// Rides the imports added.
        public var newRides = 0
        /// Rides that were there and got more from a file: a GPX attached to a Bosch ride, the Bosch
        /// values for a GPX recording (B-273), an update from a newer file.
        public var completed = 0
        /// Files of rides that were there and were left out.
        public var duplicates = 0
        /// Files that could not be read, and updates that failed.
        public var failedFileNames: [String] = []
        /// Files of a type Wattspur does not read.
        public var unsupportedFileNames: [String] = []
        /// GPX files of a planned route that could not be saved as a tour (B-301).
        public var plannedRouteFileNames: [String] = []
        /// Planned tours saved (B-372); a tour that was there already counts as a duplicate.
        public var plannedTours = 0

        public init() {}

        public var isEmpty: Bool {
            newRides == 0 && completed == 0 && duplicates == 0 && failedFileNames.isEmpty && unsupportedFileNames.isEmpty
                && plannedRouteFileNames.isEmpty && plannedTours == 0
        }
    }

    public private(set) var progress: Progress?
    public private(set) var summary = Summary()
    /// Imports file by file and lets the screen draw in between, with `progress` (B-300). Off on the
    /// Mac, where the import stays as it was.
    public var stepsThroughFiles = false
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
    /// What a file becomes, decided before the run (B-372): a tour without times needs no bike, the
    /// answer to a `TourQuestion` is kept here. Taken out when the file is imported.
    private var kinds: [URL: ImportKind] = [:]

    /// The files of a start while its tour questions are open.
    private struct TourRun {
        var urls: [URL]
        var questions: [TourQuestion]
        let library: RideLibrary
        let record: ImportRecorder
    }
    private var tourRun: TourRun?

    /// A question of an import is open.
    public var isAsking: Bool { bikeQuestion != nil || !comparisons.isEmpty || plainDuplicates != nil || tourQuestion != nil }

    /// Something is still running, asking or waiting; the summary is complete once this is `false`.
    public var isBusy: Bool { isAsking || progress != nil || !waiting.isEmpty }

    /// The summary so far, and a fresh one for the next imports.
    public func takeSummary() -> Summary {
        defer { summary = Summary() }
        return summary
    }

    public init() {}

    nonisolated public static func isGPX(_ url: URL) -> Bool { url.pathExtension.lowercased() == "gpx" }

    // MARK: - Start

    /// Imports the files. A GPX file with estimated times asks first whether it is a ride or a
    /// planned tour (B-372); then the bike is asked when GPX rides are among them and there are two
    /// or more bikes. A GPX file without times becomes a tour without asking.
    public func start(_ urls: [URL], library: RideLibrary, record: @escaping ImportRecorder) {
        guard !urls.isEmpty else { return }
        guard !isAsking, progress == nil else {
            waiting.append { [weak self] in self?.start(urls, library: library, record: record) }
            return
        }
        var questions: [TourQuestion] = []
        var rest: [URL] = []
        for url in urls {
            guard Self.isGPX(url) else { rest.append(url); continue }
            switch Self.content(of: url) {
            case .estimatedTimes(let komoot):
                if let tour = Self.tour(at: url) {
                    questions.append(TourQuestion(url: url, tour: tour, suggestsTour: komoot))
                } else {
                    rest.append(url)
                }
            case .plannedTour:
                kinds[url] = .plannedTour
                rest.append(url)
            case .ride:
                rest.append(url)
            }
        }
        guard let first = questions.first else {
            startRides(rest, library: library, record: record)
            return
        }
        tourRun = TourRun(urls: rest, questions: Array(questions.dropFirst()), library: library, record: record)
        tourQuestion = first
    }

    /// Takes the answer to “Ride or planned tour?”; after the last one the files are imported.
    public func answer(_ question: TourQuestion, asTour: Bool) {
        guard question.id == tourQuestion?.id else { return }
        kinds[question.url] = asTour ? .plannedTour : .ride
        tourRun?.urls.append(question.url)
        nextTourQuestion()
    }

    /// Leaves the file of the question out.
    public func skip(_ question: TourQuestion) {
        guard question.id == tourQuestion?.id else { return }
        nextTourQuestion()
    }

    private func nextTourQuestion() {
        guard var run = tourRun else { tourQuestion = nil; return }
        if !run.questions.isEmpty {
            tourQuestion = run.questions.removeFirst()
            tourRun = run
            return
        }
        tourRun = nil
        tourQuestion = nil
        startRides(run.urls, library: run.library, record: run.record)
        // Imports that came while asking start once nothing else asks or runs.
        startWaitingIfIdle()
    }

    /// What the first points of a GPX file say (`PlannedTourReader.content(of:)`); reads only the start.
    nonisolated static func content(of url: URL) -> GPXContent {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .ride }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: PlannedTourReader.lookBytes) else { return .ride }
        return PlannedTourReader.content(of: head)
    }

    /// The file read as a planned tour, for the question's preview.
    nonisolated static func tour(at url: URL) -> PlannedTour? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PlannedTourReader().read(data)
    }

    /// The rides of a start: asks for the bike first when GPX rides are among them and there are
    /// two or more bikes.
    private func startRides(_ urls: [URL], library: RideLibrary, record: @escaping ImportRecorder) {
        guard !urls.isEmpty else { return }
        let asking = urls.filter { Self.isGPX($0) && kinds[$0] != .plannedTour }.contains { !Self.namesKnownBike($0, library: library) }
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

    private func run(_ urls: [URL], gpxBike: Bike?, library: RideLibrary, record: @escaping ImportRecorder) {
        bikeID = gpxBike?.id
        let importOne = { [self] (url: URL) -> ImportReport.Entry in
            let kind = kinds.removeValue(forKey: url) ?? .automatic
            let result = Self.isGPX(url) ? library.importFile(at: url, bike: gpxBike, as: kind) : library.importFile(at: url)
            record(result, url)
            library.record(result, source: .manual)
            count(result)
            return ImportReport.Entry(url: url, result: result)
        }
        guard stepsThroughFiles else {
            finish(urls.map(importOne), library: library)
            return
        }
        progress = Progress(done: 0, total: urls.count)
        Task { [self] in
            var entries: [ImportReport.Entry] = []
            for url in urls {
                entries.append(importOne(url))
                progress?.done += 1
                // Lets the screen draw the progress between two files.
                await Task.yield()
            }
            progress = nil
            finish(entries, library: library)
            startWaitingIfIdle()
        }
    }

    /// Counts a file for the summary; duplicates are counted once they are decided.
    private func count(_ result: ImportResult) {
        switch result.outcome {
        case .imported: summary.newRides += 1
        case .attached: summary.completed += 1
        case .unsupported: summary.unsupportedFileNames.append(result.fileName)
        case .failed(let error) where error.isPlannedRoute: summary.plannedRouteFileNames.append(result.fileName)
        case .failed: summary.failedFileNames.append(result.fileName)
        case .plannedTour: summary.plannedTours += 1
        case .plannedTourDuplicate: summary.duplicates += 1
        case .duplicate, .fitForGPX: break
        }
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
        summary.duplicates += 1
        advance()
    }

    /// Take the new file's values; name, notes, bike and flags stay (IMP-02).
    public func update(_ comparison: Comparison, library: RideLibrary) {
        if let ride = library.ride(withID: comparison.rideID) {
            do {
                try library.update(ride, withFileAt: comparison.entry.url)
                library.recordUpdate(of: ride.id, fileName: comparison.entry.result.fileName, source: .manual)
                summary.completed += 1
            } catch {
                failedUpdates.append(comparison.entry.result.fileName)
                summary.failedFileNames.append(comparison.entry.result.fileName)
            }
        }
        advance()
    }

    /// Keep both: the file becomes a ride of its own.
    public func importAsNew(_ comparison: Comparison, library: RideLibrary, record: ImportRecorder) {
        let bike = comparison.bikeID.flatMap { id in library.bikes(includingArchived: false).first { $0.id == id } }
        let result = library.importFile(at: comparison.entry.url, bike: bike, detectDuplicates: false, as: .ride)
        record(result, comparison.entry.url)
        library.record(result, source: .manual)
        count(result)
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
        guard !isAsking, progress == nil, !waiting.isEmpty else { return }
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
                summary.completed += 1
            } catch {
                failed.append(entry.result.fileName)
                summary.failedFileNames.append(entry.result.fileName)
            }
        }
        updatingPlainDuplicates = true
        plainDuplicates = nil
        updatingPlainDuplicates = false
        if !failed.isEmpty {
            self.report = ImportReport(entries: [], failedUpdates: failed)
        }
    }
}
