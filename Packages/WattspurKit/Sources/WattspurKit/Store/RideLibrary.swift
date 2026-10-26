import Foundation
import Observation
import SwiftData

/// The library of rides, bikes, goals and the import log (B-010 … B-015).
///
/// This is the one door the app uses. The work is done by small services, one per area, that share
/// the data (`Services/`): imports, rides and the trash, merging, bikes, the import log and goals.
/// The methods here only hand over to them, so the app has one type to know.
///
/// One library is created at launch and put into the environment; it holds nothing that changes, so
/// `Observable` only makes it usable with `@Environment`. Undo belongs to a window: `using(_:)` gives
/// the same library for the undo manager of the window that asks.
@MainActor @Observable
public final class RideLibrary {
    public let context: ModelContext
    /// Where renaming, trashing, restoring, merging and splitting register their
    /// opposite step for ⌘Z (the window's undo manager).
    public let undoManager: UndoManager?
    /// The name of the bike every library starts with and that bikes without a name get
    /// (REQUIREMENTS.md 10.16). The app passes the localized name.
    public let defaultBikeName: String
    let importers: [any RideImporter]

    public init(context: ModelContext, importers: [any RideImporter] = [FITRideImporter(), GPXRideImporter()],
                undoManager: UndoManager? = nil, defaultBikeName: String = "Mein eBike") {
        self.context = context
        self.importers = importers
        self.undoManager = undoManager
        self.defaultBikeName = defaultBikeName
    }

    /// The same library for another window's undo manager (⌘Z belongs to the window).
    public func using(_ undoManager: UndoManager?) -> RideLibrary {
        RideLibrary(context: context, importers: importers, undoManager: undoManager, defaultBikeName: defaultBikeName)
    }

    private var env: LibraryEnvironment {
        LibraryEnvironment(context: context, importers: importers, undoManager: undoManager, defaultBikeName: defaultBikeName)
    }
    private var imports: ImportService { ImportService(env) }
    private var rides: RideService { RideService(env) }
    private var merges: MergeService { MergeService(env) }
    private var bikes: BikeService { BikeService(env) }
    private var log: ImportLogService { ImportLogService(env) }
    private var goals: GoalService { GoalService(env) }
    private var groupService: RouteGroupService { RouteGroupService(env) }

    // MARK: - Import

    /// Imports a file from disk. Handles security-scoped URLs from the open panel.
    @discardableResult
    public func importFile(at url: URL, bike: Bike? = nil, detectDuplicates: Bool = true) -> ImportResult {
        imports.importFile(at: url, bike: bike, detectDuplicates: detectDuplicates)
    }

    /// Imports file contents for `bike` (default: the active bike). Duplicates are skipped (IMP-02);
    /// use `update(_:with:fileName:)` to refresh one. A GPX file for a Bosch ride of the same bike is
    /// attached to it, a FIT for a GPX ride is reported as `fitForGPX` (B-143). With `detectDuplicates`
    /// off the file becomes a ride of its own ("As new ride" in the duplicate dialog); it then gets
    /// no Bosch ID, so the ID keeps belonging to the first ride.
    @discardableResult
    public func importFile(data: Data, fileName: String, bike: Bike? = nil, detectDuplicates: Bool = true) -> ImportResult {
        imports.importFile(data: data, fileName: fileName, bike: bike, detectDuplicates: detectDuplicates)
    }

    /// Refreshes an existing ride from a file on disk (security-scoped URLs allowed).
    public func update(_ ride: Ride, withFileAt url: URL) throws(RideImportError) {
        try imports.update(ride, withFileAt: url)
    }

    /// Refreshes an existing ride from a newer export. Keeps the local name (IMP-02).
    public func update(_ ride: Ride, with data: Data, fileName: String) throws(RideImportError) {
        try imports.update(ride, with: data, fileName: fileName)
    }

    /// Re-parses rides whose stored parser version is older than the current one,
    /// from their archived original file. Local edits (name, trash) stay (NFR-17).
    /// Returns the number of updated rides.
    @discardableResult
    public func reparseOutdatedRides() -> Int { imports.reparseOutdatedRides() }

    /// Computes the overview route (B-104) of every ride that has none or one from
    /// an older `OverviewRoute.version`, e.g. rides imported before v1.4. Decoding
    /// and simplifying run off the main actor in batches; each batch is saved, so
    /// an interrupted run goes on where it stopped. Returns the number of rides.
    @discardableResult
    public func prepareOverviewRoutes(batchSize: Int = 20,
                                      progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async -> Int {
        await imports.prepareOverviewRoutes(batchSize: batchSize, progress: progress)
    }

    /// Calculates the best minute of the rides that have none yet (B-122), in batches.
    @discardableResult
    public func preparePeakPower(batchSize: Int = 20,
                                 progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async -> Int {
        await imports.preparePeakPower(batchSize: batchSize, progress: progress)
    }

    /// Imports the anonymized sample ride (V-05) under the given name and marks it
    /// as a sample. If one is already there, it is returned (and restored from the trash).
    @discardableResult
    public func importSample(data: Data, name: String) -> Ride? { imports.importSample(data: data, name: name) }

    /// Splits a Bosch export name like "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit"
    /// into the ride title and the Bosch ride UUID (IMP-03).
    nonisolated public static func parseFileName(_ fileName: String) -> (title: String, sourceIdentifier: String?) {
        ImportService.parseFileName(fileName)
    }

    /// How far the start times of two files of one ride may be apart, in seconds.
    public static let similarStartTolerance: TimeInterval = ImportService.similarStartTolerance
    /// How far the GPS paths may be apart, as a share of the longer one.
    public static let similarDistanceTolerance = ImportService.similarDistanceTolerance

    /// The ride of `bike` that `parsed` records again, if there is one (B-143).
    public func findSimilarRide(to parsed: ParsedRide, bike: Bike?) -> Ride? {
        imports.findSimilarRide(to: parsed, bike: bike)
    }

    /// The facts of a file for the duplicate dialog; `nil` if no importer reads it.
    public func facts(ofFileAt url: URL) -> DuplicateFacts? { imports.facts(ofFileAt: url) }

    // MARK: - Managing rides

    public func ride(withID id: UUID) -> Ride? { rides.ride(withID: id) }
    public func rename(_ ride: Ride, to name: String) { rides.rename(ride, to: name) }

    /// Moves a ride to the trash (LIST-07). It stays restorable for 30 days.
    public func moveToTrash(_ ride: Ride, at date: Date = .now) { rides.moveToTrash(ride, at: date) }
    /// Moves several rides to the trash with one save, so one undo brings them all back.
    public func moveToTrash(_ rides: [Ride], at date: Date = .now) { self.rides.moveToTrash(rides, at: date) }
    public func restore(_ ride: Ride) { rides.restore(ride) }
    public func restore(_ rides: [Ride]) { self.rides.restore(rides) }
    /// Permanently deletes trashed rides older than `days` (LIST-08), including the original file.
    public func purgeTrash(olderThan days: Int = 30, now: Date = .now) { rides.purgeTrash(olderThan: days, now: now) }
    /// Deletes the sample ride for good, including its original file.
    public func removeSamples() { rides.removeSamples() }
    public func sampleRides() -> [Ride] { rides.sampleRides() }

    // MARK: - Merging rides (B-095, LIST-09)

    public func mergeProblem(_ rides: [Ride]) -> RideMerge.MergeError? { merges.mergeProblem(rides) }

    @discardableResult
    public func merge(_ rides: [Ride], name: String) throws(RideMerge.MergeError) -> Ride {
        try merges.merge(rides, name: name)
    }

    @discardableResult
    public func split(_ ride: Ride) -> [Ride] { merges.split(ride) }

    public func mergePreview(_ rides: [Ride]) throws(RideMerge.MergeError) -> RideMerge.Result {
        try merges.mergePreview(rides)
    }

    public func mergeParts(of rides: [Ride]) -> [Ride] { merges.mergeParts(of: rides) }
    /// Where the parts of a merged ride meet (B-131); empty for any other ride.
    public func joins(of ride: Ride) -> [RideMerge.Join] { merges.joins(of: ride) }
    func refresh(_ ride: Ride) { merges.refresh(ride) }

    /// Groups of rides that probably belong together and include at least one of `rideIDs` (B-096).
    public func mergeSuggestions(involving rideIDs: [UUID], maxGapMinutes: Int = RideMergeSuggestion.defaultGapMinutes)
        -> [RideMergeSuggestion.Group] {
        merges.mergeSuggestions(involving: rideIDs, maxGapMinutes: maxGapMinutes)
    }

    // MARK: - Rider and bikes (B-007, PROF-03, B-134, B-135, B-138)

    public typealias ArchiveError = BikeArchiveError

    /// The single local profile; created on first use.
    public func defaultRider() -> Rider { bikes.defaultRider() }
    public func defaultBike() -> Bike { bikes.defaultBike() }
    public func bikes(includingArchived: Bool = true) -> [Bike] { bikes.bikes(includingArchived: includingArchived) }

    @discardableResult
    public func activeBike() -> Bike { bikes.activeBike() }
    public func setActiveBike(_ bike: Bike) { bikes.setActiveBike(bike) }

    @discardableResult
    public func makeBike(name: String, kind: BikeKind = .bike, color: BikeColor = .blue) -> Bike {
        bikes.makeBike(name: name, kind: kind, color: color)
    }

    public func archive(_ bike: Bike) throws(BikeArchiveError) { try bikes.archive(bike) }
    public func unarchive(_ bike: Bike) { bikes.unarchive(bike) }

    @discardableResult
    public func configureActiveBike(name: String, color: BikeColor) -> Bike {
        bikes.configureActiveBike(name: name, color: color)
    }

    public func setBodyData(weightKg: Double?, heightCm: Double?, birthYear: Int?, sex: RiderSex) {
        bikes.setBodyData(weightKg: weightKg, heightCm: heightCm, birthYear: birthYear, sex: sex)
    }

    /// Assigns rides to a bike, in one save, so one ⌘Z takes them all back.
    @discardableResult
    public func assign(_ rides: [Ride], to bike: Bike) -> Int { bikes.assign(rides, to: bike) }

    /// Statistics of a bike for its tile (B-134).
    public func statistics(for bike: Bike) -> BikeStatistics { bike.statistics }

    @discardableResult
    public func prepareBikes() -> Bool { bikes.prepareBikes() }
    @discardableResult
    public func mergeBikes() -> Int { bikes.mergeBikes() }
    static func preferredBike(in bikes: [Bike]) -> Bike? { BikeService.preferredBike(in: bikes) }

    // MARK: - Import log and records (IMP-06, ADV-R2)

    /// Adds a line to the import log for the result of `importFile`.
    @discardableResult
    public func record(_ result: ImportResult, source: ImportSource, movedTo: String? = nil,
                       date: Date = .now) -> ImportRecord {
        log.record(result, source: source, movedTo: movedTo, date: date)
    }

    /// Notes that an existing ride was refreshed from a newer export (IMP-02).
    public func recordUpdate(of rideID: UUID, fileName: String, source: ImportSource, date: Date = .now) {
        log.recordUpdate(of: rideID, fileName: fileName, source: source, date: date)
    }

    public func hasRecordedUnsupportedFile(named fileName: String) -> Bool { log.hasRecordedUnsupportedFile(named: fileName) }
    /// Log entries, newest first.
    public func importRecords(limit: Int? = nil) -> [ImportRecord] { log.importRecords(limit: limit) }
    public func trimImportLog(olderThan days: Int = 90, now: Date = .now) { log.trimImportLog(olderThan: days, now: now) }

    public func newRecords(importedAfter date: Date, calendar: Calendar = .current) -> [RecordBreak] {
        log.newRecords(importedAfter: date, calendar: calendar)
    }

    public func latestImportDate() -> Date? { log.latestImportDate() }

    // MARK: - Saved routes (B-121)

    /// The saved routes, oldest first.
    public func routeGroups() -> [RouteGroup] { groupService.groups() }

    /// Saves the route of `ride` under `name`; `nil` if the name is empty or the ride has no usable route.
    @discardableResult
    public func addRouteGroup(from ride: Ride, name: String, threshold: Double = RouteSimilarity.defaultThreshold,
                              includeReverse: Bool = false) -> RouteGroup? {
        groupService.create(from: ride, name: name, threshold: threshold, includeReverse: includeReverse)
    }

    public func rename(_ group: RouteGroup, to name: String) { groupService.rename(group, to: name) }

    public func update(_ group: RouteGroup, threshold: Double, includeReverse: Bool) {
        groupService.update(group, threshold: threshold, includeReverse: includeReverse)
    }

    /// Dissolves a saved route; its rides stay.
    public func dissolve(_ group: RouteGroup) { groupService.dissolve(group) }

    // MARK: - Goals and saving (B-053)

    @discardableResult
    public func addGoal(metric: GoalMetric, period: GoalPeriod, target: Double) -> Goal {
        goals.addGoal(metric: metric, period: period, target: target)
    }

    public func update(_ goal: Goal, metric: GoalMetric, period: GoalPeriod, target: Double) {
        goals.update(goal, metric: metric, period: period, target: target)
    }

    public func delete(_ goal: Goal) { goals.delete(goal) }
    /// Writes changes a caller made to a model object (a bike being edited, the rider's name).
    public func save() { goals.save() }
    /// Rides whose start has not been looked up for a time zone yet (B-006).
    public func ridesWithoutTimeZone() -> [Ride] { goals.ridesWithoutTimeZone() }
}
