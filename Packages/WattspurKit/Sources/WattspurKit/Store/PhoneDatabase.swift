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
    /// Where the iPhone's rides come from, set at build time (`WattspurDatabase` in the Info.plist).
    public enum Mode: String, Sendable, CaseIterable {
        /// iOS 0.2: the Mac's state in the shared folder; a recording goes there as GPX.
        case folder
        /// The iPhone's own store without sync, to try it without the developer account.
        case local
        /// The iPhone's own store, synced over iCloud; needs the iCloud entitlement.
        case iCloud = "icloud"

        /// The mode for a value from the Info.plist; anything unknown keeps the folder.
        public init(infoValue: String?) {
            self = infoValue.flatMap { Mode(rawValue: $0.lowercased()) } ?? .folder
        }

        public var usesStore: Bool { self != .folder }

        /// The configuration of the store; `nil` in folder mode, which has none.
        public var configuration: ModelConfiguration? {
            switch self {
            case .folder: nil
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

    /// The rides of the list and all bikes in the exchange format. A ride with GPS names its own id
    /// as `routeFile`; `route(forRideID:)` reads it.
    public func snapshot(generator: String, now: Date = .now) throws -> RideExchange.Library {
        let rides = try PhoneStateWriter(context: context).listedRides()
        return RideExchange.Library(generatedAt: now, generator: generator,
                                    bikes: library.bikes().map(\.exchangeBike),
                                    rides: rides.map { $0.exchangeRide(routeFile: $0.mayHaveRoute ? $0.id.uuidString : nil) })
    }

    /// The route of a ride, thinned like in the Mac's state; `nil` without GPS.
    public func route(forRideID id: UUID) -> RideExchange.Route? {
        guard let ride = library.ride(withID: id) else { return nil }
        let route = RideExchange.Route(rideID: ride.id, recordings: ride.gpxSegments.map(\.samples))
        return route.pointCount > 0 ? route : nil
    }

    // MARK: - Recording

    /// Turns a finished recording into a ride: the GPX the iPhone writes anyway (with its bike), through
    /// the same import as on the Mac. Returns the outcome, e.g. `.imported(id)` or `.duplicate`.
    @discardableResult
    public func saveRecording(gpx: Data, fileName: String) -> ImportResult {
        library.importFile(data: gpx, fileName: fileName, bike: library.activeBike())
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
        try? context.save()
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
