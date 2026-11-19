import Foundation
import SwiftData
import WattspurCore

/// The iPhone's own library (B-216, B-217): the same models as on the Mac, in a SwiftData store on
/// the iPhone, later synced with the Mac over CloudKit (`LibrarySync`).
///
/// The iPhone's views were built for the Mac's state (`RideExchange`, B-209). `snapshot` gives the
/// library in that format, so they show the iPhone's own rides without being rebuilt. A recording
/// goes through the same import as a GPX file on the Mac (`GPXRideImporter`), so the Kit calculates
/// the ride on the iPhone and finds duplicates the same way.
@MainActor
public final class PhoneDatabase {
    /// Whether the iPhone's store syncs, set at build time (`WattspurDatabase` in the Info.plist). The
    /// folder way of iOS 0.2 (the Mac's state in a shared folder) ended with 0.6 (B-263).
    public enum Mode: String, Sendable, CaseIterable {
        /// The iPhone's own store without sync, to try it without the developer account.
        case local
        /// The iPhone's own store, synced over iCloud; needs the iCloud entitlement.
        case iCloud = "icloud"

        /// The mode for a value from the Info.plist; anything unknown (also the old "folder") is
        /// the store without sync.
        public init(infoValue: String?) {
            self = infoValue.flatMap { Mode(rawValue: $0.lowercased()) } ?? .local
        }

        /// The way the app works when the user chose for or against iCloud (B-218). Only a build that
        /// allows iCloud offers the choice; off means the iPhone's own store without iCloud (R-38).
        public func effective(syncOn: Bool) -> Mode {
            self == .iCloud && syncOn ? .iCloud : .local
        }

        /// Whether this iPhone used the folder way of iOS 0.2 until it ended in 0.6 (B-263): a folder
        /// was chosen and the iPhone's own store never existed. Such a user hears once that the folder
        /// is gone; iCloud is not switched on without asking.
        public static func wasFolderUser(hadFolder: Bool, hadStore: Bool) -> Bool {
            hadFolder && !hadStore
        }

        /// The configuration of the store.
        public var configuration: ModelConfiguration {
            switch self {
            case .local: LibrarySync.configuration(requested: false, available: false)
            case .iCloud: LibrarySync.configuration(requested: true, available: true)
            }
        }
    }

    /// A ride in the trash, with when it was trashed.
    public struct TrashedRide: Sendable, Equatable, Identifiable {
        public var ride: RideExchange.Ride
        public var deletedAt: Date
        public var id: UUID { ride.id }

        /// Days until it is deleted for good (LIST-08), rounded up: 30 right after trashing.
        public func daysLeft(now: Date = .now) -> Int {
            let end = deletedAt.addingTimeInterval(TimeInterval(PhoneDatabase.trashDays) * 86_400)
            return max(0, Int((end.timeIntervalSince(now) / 86_400).rounded(.up)))
        }
    }

    /// Like the Mac: rides stay in the trash for 30 days.
    nonisolated public static let trashDays = 30

    public let container: ModelContainer
    public let library: RideLibrary
    public var context: ModelContext { library.context }

    /// `defaultBikeName` is the localized “My eBike” for the first bike.
    public init(container: ModelContainer, defaultBikeName: String) {
        self.container = container
        library = RideLibrary(context: container.mainContext, defaultBikeName: defaultBikeName)
        _ = library.prepareBikes()
    }

    // MARK: - Compare and merge (B-296)

    /// What the comparison on the iPad needs of one ride: the figures of the table, the charts
    /// and the route, read once (as `CompareRidesView` on the Mac).
    public struct ComparedRide: Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var startDate: Date
        public var timeZone: TimeZone
        public var figures: ComparisonFigures
        public var chartPoints: [ChartPoint]
        public var route: [RoutePoint]
    }

    /// The compared rides, oldest first, so a ride keeps its column and colour.
    public func comparedRides(_ ids: Set<UUID>) -> [ComparedRide] {
        ids.compactMap { library.ride(withID: $0) }
            .sorted { $0.startDate < $1.startDate }
            .map { ride in
                let samples = ride.samples
                return ComparedRide(id: ride.id, name: ride.name, startDate: ride.startDate, timeZone: ride.timeZone,
                                    figures: ride.comparisonFigures,
                                    chartPoints: RideSeries.chartPoints(from: samples, bins: 300),
                                    route: RideSeries.route(from: samples, maxPoints: 800))
            }
    }

    /// The rides the averages of a comparison come from: those of the compared rides' sport,
    /// cycling when they are of several (B-288, as on the Mac).
    public func comparisonBaseline(for ids: Set<UUID>) -> [ComparisonFigures] {
        let listed = (try? ExchangeRides.listed(in: context)) ?? []
        let sports = Set(listed.filter { ids.contains($0.id) }.map(\.sport))
        let sport = sports.count == 1 ? sports.first ?? .cycling : .cycling
        return listed.filter { $0.countsInTotals(sport: sport) }.map(\.comparisonFigures)
    }

    /// Why the rides cannot be merged, or the merged figures to show before merging.
    public func mergePreview(_ ids: Set<UUID>) -> Result<RideMerge.Result, RideMerge.MergeError> {
        let rides = ids.compactMap { library.ride(withID: $0) }
        return Result { () throws(RideMerge.MergeError) in try library.mergePreview(rides) }
    }

    /// The name the merged ride gets unless changed: that of the first part.
    public func mergeName(_ ids: Set<UUID>) -> String {
        library.mergeParts(of: ids.compactMap { library.ride(withID: $0) }).first?.name ?? ""
    }

    /// Merges the rides into one, as on the Mac; the originals stay inside it. The new ride's id.
    public func merge(_ ids: Set<UUID>, name: String) throws(RideMerge.MergeError) -> UUID {
        try library.merge(ids.compactMap { library.ride(withID: $0) }, name: name).id
    }

    // MARK: - Goals (B-295)

    /// A goal as plain values for the iPad: per week, month or year, kilometres, rides or ascent.
    public struct GoalValue: Sendable, Equatable, Identifiable {
        public var id: UUID
        public var metric: GoalMetric
        public var period: GoalPeriod
        /// Metres, a number of rides, or metres of ascent.
        public var target: Double
    }

    /// The goals in display order: week, month, year, then km, rides, ascent (as on the Mac).
    public func goals() -> [GoalValue] {
        Goal.sorted((try? context.fetch(FetchDescriptor<Goal>())) ?? [])
            .map { GoalValue(id: $0.id, metric: $0.metric, period: $0.period, target: $0.target) }
    }

    /// Combinations of period and metric that have no goal yet.
    public func freeGoalCombinations() -> [(period: GoalPeriod, metric: GoalMetric)] {
        Goal.freeCombinations(besides: (try? context.fetch(FetchDescriptor<Goal>())) ?? [])
    }

    public func addGoal(metric: GoalMetric, period: GoalPeriod, target: Double) {
        _ = library.addGoal(metric: metric, period: period, target: target)
    }

    public func updateGoal(id: UUID, metric: GoalMetric, period: GoalPeriod, target: Double) {
        guard let goal = goal(id) else { return }
        library.update(goal, metric: metric, period: period, target: target)
    }

    public func deleteGoal(id: UUID) {
        guard let goal = goal(id) else { return }
        library.delete(goal)
    }

    private func goal(_ id: UUID) -> Goal? {
        try? context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.id == id })).first
    }

    // MARK: - Reading

    /// A listed ride as plain values for the analysis and the highlights on the iPad (B-295): the
    /// same figures as on the Mac (`Ride.highlightRide`), with name, device and source for the
    /// filters and the list of records.
    public struct StatsRide: Sendable, Equatable, Identifiable {
        public var id: UUID { highlight.id }
        public var name: String
        public var deviceID: UUID?
        public var source: RideSource?
        /// Counts towards totals and records (Requirements 10.10), like `Ride.countsInStatistics`.
        public var countsInStatistics: Bool
        /// When the ride came into the library: records of the last week are "New".
        public var importedAt: Date
        public var highlight: HighlightRide
        public var figures: RideFigures { highlight.figures }
        public var sport: Sport { highlight.figures.sport }
    }

    /// The listed rides without the sample ride, oldest first, as on the Mac's analysis.
    public func statsRides() -> [StatsRide] {
        ((try? ExchangeRides.listed(in: context)) ?? [])
            .map { StatsRide(name: $0.name, deviceID: $0.bike?.id, source: $0.source,
                             countsInStatistics: $0.countsInStatistics, importedAt: $0.importedAt,
                             highlight: $0.highlightRide) }
            .sorted { $0.highlight.startDate < $1.highlight.startDate }
    }

    /// The rides for the map of all rides (B-227): the listed rides that pass `filter`, with their
    /// overview routes, newest first, and how many it cannot draw. The same as on the Mac.
    public func mapOverview(filter: MapFilter) -> MapOverview {
        MapOverview((try? ExchangeRides.listed(in: context)) ?? [], filter: filter)
    }

    /// The rides of the list and all bikes in the exchange format. A ride with GPS names its own id
    /// as `routeFile`; `route(forRideID:)` reads it.
    public func snapshot(generator: String, now: Date = .now) throws -> RideExchange.Library {
        let rides = try ExchangeRides.listed(in: context)
        return RideExchange.Library(generatedAt: now, generator: generator,
                                    bikes: library.bikes().map(\.exchangeBike),
                                    rides: rides.map { ride in
                                        // The name changes with the route, so a ride the Mac changed
                                        // is not shown with the old one from the cache (R-62).
                                        ride.exchangeRide(routeFile: ride.mayHaveRoute
                                            ? RideExchange.routeFileName(rideID: ride.id, fingerprint: ride.routeFingerprint) : nil)
                                    })
    }

    /// A ride as GPX for “Share”, e.g. by AirDrop to the Mac or to komoot: the full time series like
    /// “Export as GPX…” on the Mac (B-112), the bike as note and as Wattspur extension, so the Mac
    /// assigns it. `note` words the bike name (“Bike: …”). `nil` without GPS.
    public func gpx(forRideID id: UUID, note: (String) -> String) -> (fileName: String, data: Data)? {
        guard let ride = library.ride(withID: id), route(forRideID: id) != nil else { return nil }
        let bikeName = ride.bike?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let data = GPXWriter.document(name: ride.name, segments: ride.gpxSegments,
                                      description: bikeName.isEmpty ? nil : note(bikeName), bikeID: ride.bike?.id,
                                      sport: ride.sport)
        return (GPXWriter.fileName(ride.name), data)
    }

    /// The route of a ride, thinned like in the Mac's state; `nil` without GPS.
    public func route(forRideID id: UUID) -> RideExchange.Route? {
        guard let ride = library.ride(withID: id) else { return nil }
        let route = RideExchange.Route(rideID: ride.id, recordings: ride.gpxSegments.map(\.samples))
        return route.pointCount > 0 ? route : nil
    }

    /// The measurements of a ride for the charts on the iPhone (B-241): speed, power, cadence, heart
    /// rate and altitude from the full time series, averaged into `bins` slices of distance or time
    /// like on the Mac (`RideSeries`). Empty for an unknown ride or one without a time series.
    public func chartPoints(forRideID id: UUID, axis: ChartAxis = .distance, bins: Int = 300) -> [ChartPoint] {
        guard let ride = library.ride(withID: id) else { return [] }
        return RideSeries.chartPoints(from: ride.samples, axis: axis, bins: bins)
    }

    /// The time series of a ride, to find the spot under the finger on the chart and show it on the
    /// map (B-221), like `RideCursor` on the Mac. Empty for an unknown ride.
    public func track(forRideID id: UUID) -> RideTrack {
        RideTrack(samples: library.ride(withID: id)?.samples ?? [])
    }

    /// What the tour detail shows from the time series, read once (R-33): the charts, the track for
    /// the spot under the finger and the motion values. Empty for an unknown ride.
    public struct Detail: Sendable {
        public var chartPoints: [ChartPoint] = []
        public var track = RideTrack(samples: [])
        public var motion: (figures: RideMotion, lean: [RideMotion.LeanStretch], surface: [RideMotion.SurfaceStretch])?

        public init(chartPoints: [ChartPoint] = [], track: RideTrack = RideTrack(samples: [])) {
            self.chartPoints = chartPoints
            self.track = track
        }
    }

    public func detail(forRideID id: UUID) -> Detail {
        guard let ride = library.ride(withID: id) else { return Detail() }
        let samples = ride.samples
        var detail = Detail(chartPoints: RideSeries.chartPoints(from: samples, axis: .distance, bins: 300),
                            track: RideTrack(samples: samples))
        if let figures = RideMotion(samples: samples, kind: ride.deviceKind) {
            detail.motion = (figures, RideMotion.leanStretches(samples, side: figures.side), RideMotion.surfaceStretches(samples))
        }
        return detail
    }

    /// Lean, acceleration and the sprint of a ride, and its track by lean angle (B-246) and by road
    /// surface (B-248); `nil` for a ride without lean angles. A vehicle sprints to 100 km/h, any
    /// bike to 25; a car shows the lateral acceleration (B-287).
    public func motion(forRideID id: UUID)
        -> (figures: RideMotion, lean: [RideMotion.LeanStretch], surface: [RideMotion.SurfaceStretch])? {
        guard let ride = library.ride(withID: id) else { return nil }
        let samples = ride.samples
        guard let figures = RideMotion(samples: samples, kind: ride.deviceKind) else { return nil }
        return (figures, RideMotion.leanStretches(samples, side: figures.side), RideMotion.surfaceStretches(samples))
    }

    // MARK: - Recording

    /// Turns a finished recording into a ride: the GPX the iPhone writes anyway (with its bike), through
    /// the same import as on the Mac. Returns the outcome, e.g. `.imported(id)` or `.duplicate`.
    ///
    /// A recording that matches a ride already there (a GPX of the same tour, or the same recording
    /// saved before a crash) is not dropped (R-53): it updates that ride, which keeps its name and
    /// bike and takes the recording's lean angle, acceleration and road surface; a Bosch ride keeps
    /// its own values and gets them added.
    @discardableResult
    public func saveRecording(gpx: Data, fileName: String) -> ImportResult {
        let result = library.importFile(data: gpx, fileName: fileName, bike: library.activeBike())
        guard case .duplicate(let id) = result.outcome, let ride = library.ride(withID: id) else { return result }
        do {
            try library.update(ride, with: gpx, fileName: fileName)
        } catch {
            return ImportResult(fileName: fileName, outcome: .failed(error))
        }
        return result
    }

    // MARK: - Editing (B-240)

    /// Renames a ride and moves it to another bike, as on the Mac; over iCloud the Mac gets both.
    /// A blank name keeps the old one, an unknown bike keeps the old bike, and a merged ride takes
    /// its parts to the new bike. Returns whether anything changed.
    @discardableResult
    public func edit(rideID: UUID, name: String, bikeID: UUID?) -> Bool {
        guard let ride = library.ride(withID: rideID), !ride.isSample else { return false }
        let oldName = ride.name
        library.rename(ride, to: name)
        var changed = ride.name != oldName
        if let bikeID, let bike = library.bikes().first(where: { $0.id == bikeID }) {
            changed = library.assign([ride], to: bike) > 0 || changed
        }
        return changed
    }

    // MARK: - Trash (B-217)

    public func moveToTrash(rideID: UUID, at date: Date = .now) {
        guard let ride = library.ride(withID: rideID) else { return }
        library.moveToTrash(ride, at: date)
    }

    public func restore(rideID: UUID) {
        guard let ride = library.ride(withID: rideID) else { return }
        library.restore(ride)
    }

    /// Deletes one ride from the trash for good, with its original file.
    public func deletePermanently(rideID: UUID) {
        guard let ride = library.ride(withID: rideID), ride.isInTrash else { return }
        context.delete(ride)
        LibrarySave.save(context)
    }

    /// The rider for the head of “More” (B-298); `nil` before there is one. Reads only: it does not
    /// make a rider the way `RideLibrary.defaultRider()` does. With two riders before the sync
    /// merged them, the oldest, the one that stays (as `SyncMergeService` decides).
    public func riderDetails() -> RiderDetails? {
        oldestRider()?.details
    }

    private func oldestRider() -> Rider? {
        let riders = (try? context.fetch(FetchDescriptor<Rider>())) ?? []
        return riders.min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    /// Saves the profile edited on the iPhone (B-299): name, photo and the data for the calories,
    /// into the same rider the Mac edits, so iCloud brings it there. Numbers out of range are not
    /// stored (`ProfileInput`). Makes the rider if there is none yet.
    public func updateRider(_ details: RiderDetails, now: Date = .now) {
        let rider = oldestRider() ?? library.defaultRider()
        let name = details.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if rider.name != name { rider.name = name }
        if rider.photoData != details.photoData { rider.photoData = details.photoData }
        let weight = ProfileInput.accepted(details.body.weightKg, in: ProfileInput.weightKg)
        if rider.weightKg != weight { rider.weightKg = weight }
        let height = ProfileInput.accepted(details.body.heightCm, in: ProfileInput.heightCm)
        if rider.heightCm != height { rider.heightCm = height }
        let year = ProfileInput.accepted(details.body.birthYear, in: ProfileInput.birthYears(now: now))
        if rider.birthYear != year { rider.birthYear = year }
        if rider.sex != details.body.sex { rider.sex = details.body.sex }
        LibrarySave.save(context)
    }

    // MARK: - Devices (B-290)

    private func device(_ id: UUID) -> Bike? {
        library.bikes().first { $0.id == id }
    }

    /// The values of a device for the editor; `nil` for an unknown id.
    public func deviceDraft(id: UUID) -> BikeDraft? {
        device(id).map { BikeDraft($0, isActive: oldestRider()?.activeBikeID == $0.id) }
    }

    /// Adds a device (`id` nil) or changes one, with the rules of the Mac's editor (`BikeDraft`), and
    /// returns its id; iCloud brings it to the Mac. An unknown id adds nothing and returns `nil`.
    @discardableResult
    public func saveDevice(_ draft: BikeDraft, id: UUID?) -> UUID? {
        let bike: Bike
        if let id {
            guard let existing = device(id) else { return nil }
            bike = existing
        } else {
            bike = library.makeBike(name: draft.name, kind: draft.kind, color: draft.color)
        }
        // An empty name keeps the one the device has (a new one has the default name already).
        let name = bike.name
        var checked = draft
        checked.startKilometers = ProfileInput.accepted(draft.startKilometers, in: ProfileInput.startKilometers)
        checked.apply(to: bike)
        if bike.name.isEmpty { bike.name = name }
        // A device added here is never the untouched default bike that the sync merge removes
        // (B-332): left with the default name, it gets a number, e.g. "My eBike 2".
        if id == nil { library.keepAddedBike(bike) }
        LibrarySave.save(context)
        return bike.id
    }

    /// Archives a device or takes it out of the archive (B-134); the last open bike stays.
    public func setArchived(_ archived: Bool, deviceID: UUID) throws(BikeArchiveError) {
        guard let bike = device(deviceID) else { return }
        if archived { try library.archive(bike) } else { library.unarchive(bike) }
    }

    /// The device new rides go to on the Mac (`Rider.activeBikeID`), the first default for a recording (B-286).
    public func activeDeviceID() -> UUID? {
        oldestRider()?.activeBikeID
    }

    /// Deletes an archived device without rides in the list (B-322); an unknown one is gone already.
    public func deleteDevice(id: UUID) throws(BikeDeleteError) {
        guard let bike = device(id) else { return }
        try library.delete(bike)
    }

    /// The rides in the list that keep a device from being deleted (B-322).
    public func listedRideCount(deviceID: UUID) -> Int {
        device(deviceID).map { library.listedRideCount(of: $0) } ?? 0
    }

    /// Whether a device may be archived: not the last one that is not archived.
    public func canArchive(deviceID: UUID) -> Bool {
        library.bikes(includingArchived: false).contains { $0.id != deviceID }
    }

    /// The trash, last trashed first. Merged rides' parts and the sample ride are not in it.
    public func trash() -> [TrashedRide] {
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.deletedAt != nil && $0.mergedInto == nil })
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { !$0.isSample }
            .compactMap { ride in ride.deletedAt.map { TrashedRide(ride: ride.exchangeRide(routeFile: nil), deletedAt: $0) } }
            .sorted { $0.deletedAt > $1.deletedAt }
    }

    /// Deletes what has been in the trash for longer than 30 days; at every start, like the Mac.
    public func purgeTrash(now: Date = .now) {
        library.purgeTrash(olderThan: Self.trashDays, now: now)
    }
}
