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

    // MARK: - Reading

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
                                      description: bikeName.isEmpty ? nil : note(bikeName), bikeID: ride.bike?.id)
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
        if let figures = RideMotion(samples: samples, motorized: ride.bike?.kind.isMotorized == true) {
            detail.motion = (figures, RideMotion.leanStretches(samples), RideMotion.surfaceStretches(samples))
        }
        return detail
    }

    /// Lean, acceleration and the sprint of a ride, and its track by lean angle (B-246) and by road
    /// surface (B-248); `nil` for a ride without lean angles. A motorcycle sprints to 100 km/h, any
    /// other bike to 25.
    public func motion(forRideID id: UUID)
        -> (figures: RideMotion, lean: [RideMotion.LeanStretch], surface: [RideMotion.SurfaceStretch])? {
        guard let ride = library.ride(withID: id) else { return nil }
        let samples = ride.samples
        guard let figures = RideMotion(samples: samples, motorized: ride.bike?.kind.isMotorized == true) else { return nil }
        return (figures, RideMotion.leanStretches(samples), RideMotion.surfaceStretches(samples))
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
        let riders = (try? context.fetch(FetchDescriptor<Rider>())) ?? []
        return riders.min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }?.details
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
