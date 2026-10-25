import Foundation
import SwiftData

/// Result of importing one file (feeds the import log, IMP-06).
public struct ImportResult: Sendable, Identifiable {
    public enum Outcome: Sendable {
        case imported(rideID: UUID)
        /// The same ride is already there (same Bosch ID, or the same start and distance; two GPX
        /// files of one tour). The caller decides whether to update it (IMP-02).
        case duplicate(existingRideID: UUID)
        /// A GPX file for a Bosch ride that is already there: the GPX was attached to it (heart rate,
        /// temperature, the source noted) without asking (B-143).
        case attached(rideID: UUID)
        /// A Bosch FIT for a ride that is there as GPX only (B-143). Nothing is changed yet: the app
        /// asks, the watched folder updates the ride with `update(_:with:fileName:)`.
        case fitForGPX(existingRideID: UUID)
        case unsupported
        case failed(RideImportError)

        /// The ride a `duplicate` or `fitForGPX` result refers to.
        public var existingRideID: UUID? {
            switch self {
            case .duplicate(let id), .fitForGPX(let id): id
            default: nil
            }
        }
    }

    public let id = UUID()
    public let fileName: String
    public let outcome: Outcome
}

/// Imports files into the library and manages rides (B-010 … B-015).
@MainActor
public final class RideLibrary {
    public let context: ModelContext
    let importers: [any RideImporter]
    /// Where renaming, trashing, restoring, merging and splitting register their
    /// opposite step for ⌘Z (the window's undo manager). SwiftData's own undo is
    /// not used: it did not reliably undo changed values and left merged parts
    /// pointing at a deleted ride.
    public let undoManager: UndoManager?

    public init(context: ModelContext, importers: [any RideImporter] = [FITRideImporter(), GPXRideImporter()],
                undoManager: UndoManager? = nil) {
        self.context = context
        self.importers = importers
        self.undoManager = undoManager
    }

    // MARK: - Import

    /// Imports a file from disk. Handles security-scoped URLs from the open panel.
    @discardableResult
    public func importFile(at url: URL, bike: Bike? = nil, detectDuplicates: Bool = true) -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            return importFile(data: data, fileName: url.lastPathComponent, bike: bike, detectDuplicates: detectDuplicates)
        } catch {
            return ImportResult(fileName: url.lastPathComponent, outcome: .failed(.decoding(.fileTooShort)))
        }
    }

    /// Imports file contents for `bike` (default: the active bike). Duplicates are skipped (IMP-02);
    /// use `update(_:with:fileName:)` to refresh one. A GPX file for a Bosch ride of the same bike is
    /// attached to it, a FIT for a GPX ride is reported as `fitForGPX` (B-143). With `detectDuplicates`
    /// off the file becomes a ride of its own ("As new ride" in the duplicate dialog); it then gets
    /// no Bosch ID, so the ID keeps belonging to the first ride.
    @discardableResult
    public func importFile(data: Data, fileName: String, bike: Bike? = nil, detectDuplicates: Bool = true) -> ImportResult {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard let importer = importers.first(where: { $0.fileExtensions.contains(ext) }) else {
            return ImportResult(fileName: fileName, outcome: .unsupported)
        }

        let parsed: ParsedRide
        do {
            parsed = try importer.parse(data)
        } catch {
            return ImportResult(fileName: fileName, outcome: .failed(error))
        }

        let names = Self.parseFileName(fileName)
        if detectDuplicates, let existing = findDuplicate(sourceIdentifier: names.sourceIdentifier, parsed: parsed) {
            return ImportResult(fileName: fileName, outcome: .duplicate(existingRideID: existing.id))
        }
        let target = bike ?? activeBike()
        if detectDuplicates, let similar = findSimilarRide(to: parsed, bike: target) {
            switch (RideSource(fileExtension: ext), similar.source) {
            case (.gpx?, .fit?):
                guard similar.attachedSourceFormat == nil else {
                    return ImportResult(fileName: fileName, outcome: .duplicate(existingRideID: similar.id))
                }
                attach(parsed, fileName: fileName, to: similar)
                try? context.save()
                return ImportResult(fileName: fileName, outcome: .attached(rideID: similar.id))
            case (.gpx?, .gpx?):
                return ImportResult(fileName: fileName, outcome: .duplicate(existingRideID: similar.id))
            case (.fit?, .gpx?):
                return ImportResult(fileName: fileName, outcome: .fitForGPX(existingRideID: similar.id))
            default:
                break
            }
        }

        let suggested = parsed.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ride = Ride(name: suggested.isEmpty ? names.title : suggested, startDate: parsed.startDate)
        ride.sourceIdentifier = detectDuplicates ? (names.sourceIdentifier ?? "") : ""
        ride.sourceFormat = ext
        ride.apply(parsed)
        ride.rider = defaultRider()
        ride.bike = target
        ride.sourceFile = SourceFile(fileName: fileName, data: data)
        context.insert(ride)
        try? context.save()
        return ImportResult(fileName: fileName, outcome: .imported(rideID: ride.id))
    }

    /// Refreshes an existing ride from a file on disk (security-scoped URLs allowed).
    public func update(_ ride: Ride, withFileAt url: URL) throws(RideImportError) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw .noRideData }
        try update(ride, with: data, fileName: url.lastPathComponent)
    }

    /// Refreshes an existing ride from a newer export. Keeps the local name (IMP-02).
    public func update(_ ride: Ride, with data: Data, fileName: String) throws(RideImportError) {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard let importer = importers.first(where: { $0.fileExtensions.contains(ext) }) else {
            throw .noRideData
        }
        let parsed = try importer.parse(data)
        let incoming = RideSource(fileExtension: ext)

        // A GPX never replaces the Bosch values of a FIT ride (Requirements 3.3): it refreshes the
        // additional source.
        if incoming == .gpx, ride.source == .fit {
            attach(parsed, fileName: fileName, to: ride)
            if let merged = ride.mergedInto { refresh(merged) }
            try? context.save()
            return
        }

        let before = (samples: ride.samples, start: ride.startDate, fileName: ride.sourceFile?.fileName, source: ride.source)
        ride.apply(parsed)
        ride.sourceFormat = ext
        if let identifier = Self.parseFileName(fileName).sourceIdentifier { ride.sourceIdentifier = identifier }
        if incoming == .fit, before.source == .gpx {
            // The Bosch values replace the estimate; the GPX stays noted as an additional source and
            // its heart rate and temperature are kept.
            ride.attachedSourceName = before.fileName
            ride.attachedSourceFormat = RideSource.gpx.rawValue
            carrySensorValues(from: before.samples, startDate: before.start, to: ride)
        } else if incoming == .fit, ride.attachedSourceFormat != nil {
            carrySensorValues(from: before.samples, startDate: before.start, to: ride)
        } else if incoming == .gpx {
            ride.attachedSourceName = nil
            ride.attachedSourceFormat = nil
        }
        if ride.bike == nil { ride.bike = defaultBike() }
        if let file = ride.sourceFile {
            file.fileName = fileName
            file.data = data
        } else {
            ride.sourceFile = SourceFile(fileName: fileName, data: data)
        }
        if let merged = ride.mergedInto { refresh(merged) }
        try? context.save()
    }

    /// Re-parses rides whose stored parser version is older than the current one,
    /// from their archived original file. Local edits (name, trash) stay (NFR-17).
    /// Returns the number of updated rides.
    @discardableResult
    public func reparseOutdatedRides() -> Int {
        var updated = 0
        var mergedToRefresh: Set<UUID> = []
        let rides = (try? context.fetch(FetchDescriptor<Ride>())) ?? []
        for ride in rides {
            guard let file = ride.sourceFile, let data = file.data,
                  let importer = importers.first(where: { $0.fileExtensions.contains(ride.sourceFormat) }),
                  ride.parserVersion < importer.parserVersion,
                  let parsed = try? importer.parse(data) else { continue }
            let before = ride.attachedSourceFormat == nil ? nil : (samples: ride.samples, start: ride.startDate)
            ride.apply(parsed)
            if let before { carrySensorValues(from: before.samples, startDate: before.start, to: ride) }
            if ride.bike == nil { ride.bike = defaultBike() }
            if let merged = ride.mergedInto { mergedToRefresh.insert(merged.id) }
            updated += 1
        }
        // A merged ride has no file of its own; it is rebuilt from its updated parts.
        for ride in rides where mergedToRefresh.contains(ride.id) { refresh(ride) }
        if updated > 0 { try? context.save() }
        return updated
    }

    /// Computes the overview route (B-104) of every ride that has none or one from
    /// an older `OverviewRoute.version`, e.g. rides imported before v1.4. Decoding
    /// and simplifying run off the main actor in batches; each batch is saved, so
    /// an interrupted run goes on where it stopped. Returns the number of rides.
    @discardableResult
    public func prepareOverviewRoutes(batchSize: Int = 20,
                                      progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async -> Int {
        let version = OverviewRoute.version
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.overviewRouteVersion != version })
        let outdated = (try? context.fetch(descriptor)) ?? []
        guard !outdated.isEmpty else { return 0 }
        // Parts first: a merged ride is put together from its parts' routes.
        let single = outdated.filter { !$0.isMerged }
        let merged = outdated.filter(\.isMerged)
        var done = 0
        progress(0, outdated.count)
        for start in stride(from: 0, to: single.count, by: max(1, batchSize)) {
            let batch = Array(single[start..<min(start + max(1, batchSize), single.count)])
            let inputs = batch.map(\.samplesData)
            let routes = await Task.detached(priority: .utility) { inputs.map(OverviewRoute.init(samplesData:)) }.value
            // The ride may have been deleted or updated meanwhile.
            for (ride, route) in zip(batch, routes) where !ride.isDeleted && ride.needsOverviewRoute {
                ride.setOverviewRoute(route)
            }
            try? context.save()
            done += batch.count
            progress(done, outdated.count)
        }
        for ride in merged where !ride.isDeleted && ride.needsOverviewRoute { ride.updateOverviewRouteFromParts() }
        try? context.save()
        progress(outdated.count, outdated.count)
        return outdated.count
    }

    // MARK: - Managing rides

    public func rename(_ ride: Ride, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ride.name else { return }
        let old = ride.name
        ride.name = trimmed
        try? context.save()
        registerUndo { $0.rename(ride, to: old) }
    }

    /// Moves a ride to the trash (LIST-07). It stays restorable for 30 days.
    public func moveToTrash(_ ride: Ride, at date: Date = .now) {
        moveToTrash([ride], at: date)
    }

    /// Moves several rides to the trash with one save, so one undo brings them all back.
    public func moveToTrash(_ rides: [Ride], at date: Date = .now) {
        setDeletedAt(rides.map { ($0, date) })
    }

    public func restore(_ ride: Ride) {
        restore([ride])
    }

    public func restore(_ rides: [Ride]) {
        setDeletedAt(rides.map { ($0, nil) })
    }

    /// Changes the trash state; undo puts back each ride's previous state.
    private func setDeletedAt(_ changes: [(ride: Ride, date: Date?)]) {
        let previous = changes.map { ($0.ride, $0.ride.deletedAt) }
        for change in changes { change.ride.deletedAt = change.date }
        try? context.save()
        registerUndo { $0.setDeletedAt(previous) }
    }

    /// Permanently deletes trashed rides older than `days` (LIST-08), including the original file.
    public func purgeTrash(olderThan days: Int = 30, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.deletedAt != nil })
        for ride in (try? context.fetch(descriptor)) ?? [] where (ride.deletedAt ?? now) <= cutoff {
            context.delete(ride)
        }
        try? context.save()
    }

    // MARK: - Merging rides (B-095, LIST-09)

    /// Why the rides cannot be merged, or `nil` if they can. Merged rides count
    /// with their parts, so a merged ride can be merged again.
    public func mergeProblem(_ rides: [Ride]) -> RideMerge.MergeError? {
        let parts = Self.leafParts(of: rides)
        if parts.count < 2 { return .tooFewRides }
        if rides.contains(where: \.isSample) { return .containsSample }
        // Only start and duration matter here; decoding the time series would slow down menus.
        let spans = parts.map { RideMerge.Part(startDate: $0.startDate, summary: $0.summary, samples: [], workKilojoules: 0) }
        return RideMerge.overlaps(spans) ? .overlapping : nil
    }

    /// Merges the rides into a new ride with the given name, in one save, so ⌘Z
    /// undoes it. The originals become its hidden parts and keep their files;
    /// merged rides among them are dissolved into their parts first.
    @discardableResult
    public func merge(_ rides: [Ride], name: String) throws(RideMerge.MergeError) -> Ride {
        if let problem = mergeProblem(rides) { throw problem }
        let parts = mergeParts(of: rides)
        // Merged rides among the selection are dissolved; undo merges them again.
        let previousGroups = rides.filter(\.isMerged).map { (parts: $0.sortedParts, name: $0.name, deletedAt: $0.deletedAt) }
        let first = parts[0]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ride = Ride(name: trimmed.isEmpty ? first.name : trimmed, startDate: first.startDate)
        ride.timeZoneIdentifier = first.timeZoneIdentifier
        ride.deviceSerialNumber = first.deviceSerialNumber
        ride.rider = first.rider ?? defaultRider()
        ride.bike = first.bike ?? defaultBike()
        context.insert(ride)
        for old in rides where old.isMerged {
            old.parts = []
            context.delete(old)
        }
        for part in parts { part.mergedInto = ride }
        refresh(ride)
        try? context.save()
        registerUndo { library in
            library.split(ride)
            for group in previousGroups {
                let again = try? library.merge(group.parts, name: group.name)
                again?.deletedAt = group.deletedAt
            }
        }
        return ride
    }

    /// Dissolves a merged ride: its parts come back as rides of their own.
    /// Returns them, oldest first.
    @discardableResult
    public func split(_ ride: Ride) -> [Ride] {
        let parts = ride.sortedParts
        guard !parts.isEmpty else { return [] }
        let name = ride.name
        let deletedAt = ride.deletedAt
        for part in parts {
            part.mergedInto = nil
            part.deletedAt = deletedAt
        }
        ride.parts = []
        context.delete(ride)
        try? context.save()
        registerUndo { library in
            for part in parts { part.deletedAt = nil }
            let again = try? library.merge(parts, name: name)
            again?.deletedAt = deletedAt
            try? library.context.save()
        }
        return parts
    }

    /// What merging the rides would give, for the confirmation dialog.
    public func mergePreview(_ rides: [Ride]) throws(RideMerge.MergeError) -> RideMerge.Result {
        if let problem = mergeProblem(rides) { throw problem }
        return try Self.merged(Self.leafParts(of: rides))
    }

    /// The original rides behind the given ones, oldest first.
    public func mergeParts(of rides: [Ride]) -> [Ride] {
        Self.leafParts(of: rides).sorted { $0.startDate < $1.startDate }
    }

    /// Recomputes a merged ride's values from its parts (after merging or re-parsing).
    func refresh(_ ride: Ride) {
        guard let result = try? Self.merged(ride.sortedParts) else { return }
        let parts = ride.sortedParts
        ride.startDate = result.startDate
        ride.parserVersion = parts.map(\.parserVersion).min() ?? 0
        let s = result.summary
        ride.timerTime = s.timerTime
        ride.elapsedTime = s.elapsedTime
        ride.distance = s.distance
        ride.averageSpeed = s.averageSpeed
        ride.maxSpeed = s.maxSpeed
        ride.averagePower = s.averagePower
        ride.maxPower = s.maxPower
        ride.averageCadence = s.averageCadence
        ride.maxCadence = s.maxCadence
        ride.totalAscent = s.totalAscent
        ride.totalDescent = s.totalDescent
        ride.workKilojoules = result.workKilojoules
        ride.minAltitude = result.minAltitude
        ride.maxAltitude = result.maxAltitude
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        ride.samplesData = try? encoder.encode(result.samples)
        ride.updateOverviewRouteFromParts()
    }

    private static func merged(_ parts: [Ride]) throws(RideMerge.MergeError) -> RideMerge.Result {
        let sorted = parts.sorted { $0.startDate < $1.startDate }
        return try RideMerge.merge(sorted.map(mergePart), timeZone: sorted.first?.timeZone ?? .current)
    }

    private static func leafParts(of rides: [Ride]) -> [Ride] {
        rides.flatMap { $0.isMerged ? $0.sortedParts : [$0] }
    }

    /// Where the parts of a merged ride meet (B-131); empty for any other ride.
    public func joins(of ride: Ride) -> [RideMerge.Join] {
        let parts = ride.sortedParts
        guard parts.count >= 2 else { return [] }
        return RideMerge.joins(of: parts.map(Self.mergePart), timeZone: parts[0].timeZone)
    }

    private static func mergePart(_ ride: Ride) -> RideMerge.Part {
        RideMerge.Part(startDate: ride.startDate, summary: ride.summary, samples: ride.samples,
                       workKilojoules: ride.workKilojoules, minAltitude: ride.minAltitude, maxAltitude: ride.maxAltitude)
    }

    // MARK: - Undo

    /// Registers the opposite step. Called while undoing, it becomes the redo step.
    func registerUndo(_ step: @escaping @MainActor (RideLibrary) -> Void) {
        guard let undoManager else { return }
        let importers = importers
        undoManager.registerUndo(withTarget: context) { [weak undoManager] context in
            MainActor.assumeIsolated {
                step(RideLibrary(context: context, importers: importers, undoManager: undoManager))
            }
        }
    }

    // MARK: - Sample ride (ONB-02)

    /// Imports the anonymized sample ride (V-05) under the given name and marks it
    /// as a sample. If one is already there, it is returned (and restored from the trash).
    @discardableResult
    public func importSample(data: Data, name: String) -> Ride? {
        if let existing = sampleRides().first {
            existing.deletedAt = nil
            try? context.save()
            return existing
        }
        let result = importFile(data: data, fileName: "SampleRide.fit")
        guard case .imported(let id) = result.outcome, let ride = ride(withID: id) else { return nil }
        ride.isSample = true
        ride.name = name
        try? context.save()
        return ride
    }

    /// Deletes the sample ride for good, including its original file.
    public func removeSamples() {
        sampleRides().forEach(context.delete)
        try? context.save()
    }

    public func sampleRides() -> [Ride] {
        (try? context.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.isSample }))) ?? []
    }

    public func ride(withID id: UUID) -> Ride? {
        var descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - Rider and bike (B-007)

    /// The single local profile; created on first use.
    public func defaultRider() -> Rider {
        if let rider = try? context.fetch(FetchDescriptor<Rider>()).first { return rider }
        let rider = Rider()
        context.insert(rider)
        return rider
    }

    /// The bike new rides go to; see `activeBike()`. Kept for callers that only need
    /// "the bike of the rider".
    public func defaultBike() -> Bike { activeBike() }

    /// Merges the bikes earlier versions created from the export's serial number
    /// into one and deletes the surplus. Only bikes with a serial number are
    /// touched; bikes made in the profile (PROF-03) never have one. The serial
    /// number of each is kept on its rides as metadata. Rides without a bike go
    /// to the active bike. Returns the number of deleted bikes.
    @discardableResult
    public func mergeBikes() -> Int {
        let bikes = (try? context.fetch(FetchDescriptor<Bike>())) ?? []
        let legacy = bikes.filter { $0.serialNumber != nil }
        var deleted = 0
        if !legacy.isEmpty {
            let current = bikes.filter { $0.serialNumber == nil }
            if let keeper = Self.preferredBike(in: current.isEmpty ? legacy : current) {
                // The serial numbers came from the exports, so they move to the rides.
                for bike in legacy {
                    for ride in bike.rides ?? [] {
                        if ride.deviceSerialNumber == nil { ride.deviceSerialNumber = bike.serialNumber }
                        ride.bike = keeper
                    }
                }
                keeper.serialNumber = nil
                let surplus = legacy.filter { $0 !== keeper }
                surplus.forEach(context.delete)
                deleted = surplus.count
            }
        }
        let unassigned = FetchDescriptor<Ride>(predicate: #Predicate { $0.bike == nil })
        let orphans = (try? context.fetch(unassigned)) ?? []
        if !orphans.isEmpty {
            let target = activeBike()
            for ride in orphans { ride.bike = target }
        }
        if deleted > 0 || !orphans.isEmpty { try? context.save() }
        return deleted
    }

    /// The bike to keep: one the user has named, else the one with the most rides.
    static func preferredBike(in bikes: [Bike]) -> Bike? {
        func rank(_ bike: Bike) -> (Int, Int) { (bike.name.isEmpty ? 0 : 1, bike.rides?.count ?? 0) }
        return bikes.max { rank($0) < rank($1) }
    }

    // MARK: - Helpers

    private func findDuplicate(sourceIdentifier: String?, parsed: ParsedRide) -> Ride? {
        if let sourceIdentifier {
            var descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.sourceIdentifier == sourceIdentifier })
            descriptor.fetchLimit = 1
            if let match = try? context.fetch(descriptor).first { return match }
        }
        let from = parsed.startDate.addingTimeInterval(-1)
        let to = parsed.startDate.addingTimeInterval(1)
        let distance = parsed.summary.distance
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.startDate >= from && $0.startDate <= to })
        return (try? context.fetch(descriptor))?.first { abs($0.distance - distance) < 1 }
    }

    /// Splits a Bosch export name like "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit"
    /// into the ride title and the Bosch ride UUID (IMP-03).
    nonisolated public static func parseFileName(_ fileName: String) -> (title: String, sourceIdentifier: String?) {
        let base = (fileName as NSString).deletingPathExtension
        let pattern = /^(.*?)-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$/
        if let match = base.wholeMatch(of: pattern) {
            let title = String(match.1).trimmingCharacters(in: .whitespaces)
            return (title.isEmpty ? base : title, String(match.2).lowercased())
        }
        return (base, nil)
    }
}
