import Foundation
import SwiftData
import WattspurCore

/// Everything the iPhone's screens show from the library, read in one go as plain values (B-381).
///
/// `PhoneLibrary.reload()` used to read all of it on the main thread. With the memory full (the
/// camera open during a ride) that took more than 10 seconds and iOS ended the app (B-380). Now
/// `LibraryReader` reads it with its own context off the main thread, and only these values go back.
public struct LibraryReading: Sendable {
    public var state: RideExchange.Library
    public var trash: [PhoneDatabase.TrashedRide]
    public var mergedRideIDs: Set<UUID>
    /// How many rides each merged ride was made from (B-335).
    public var partCounts: [UUID: Int]
    public var rider: RiderDetails?
    public var statsRides: [PhoneDatabase.StatsRide]
    public var goals: [PhoneDatabase.GoalValue]
    public var freeGoalCombinations: [GoalCombination]
    public var activeDeviceID: UUID?
    /// The rides in the list per device, which keep it from being deleted (B-322).
    public var listedRideCounts: [UUID: Int]

    /// A period and a metric without a goal yet.
    public struct GoalCombination: Sendable, Equatable {
        public var period: GoalPeriod
        public var metric: GoalMetric
    }

    /// Reads it all from `context`. Throws only when the rides of the list cannot be read; the
    /// rest is empty then, as `LibraryFetch` does.
    public static func read(in context: ModelContext, generator: String, now: Date = .now) throws -> LibraryReading {
        // The rides of the list, as `ExchangeRides.listed`: not in the trash, not a merged part, no sample.
        let listed = try context.fetch(FetchDescriptor<Ride>(predicate: Ride.listedPredicate)).filter { !$0.isSample }
        let bikes = Bike.sorted(LibraryFetch.fetchOrEmpty(FetchDescriptor<Bike>(), in: context))
        let merged = listed.filter(\.isMerged)
        let goals = LibraryFetch.fetchOrEmpty(FetchDescriptor<Goal>(), in: context)
        let riders = LibraryFetch.fetchOrEmpty(FetchDescriptor<Rider>(), in: context)
        // The oldest rider is the one that stays after the sync merged two (as `PhoneDatabase`).
        let rider = riders.min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        let trashed = LibraryFetch.fetchOrEmpty(
            FetchDescriptor<Ride>(predicate: #Predicate { $0.deletedAt != nil && $0.mergedInto == nil }), in: context)

        return LibraryReading(
            state: RideExchange.Library(
                generatedAt: now, generator: generator,
                bikes: bikes.map(\.exchangeBike),
                rides: listed.map { ride in
                    // The name changes with the route, so a ride the Mac changed is not shown with
                    // the old one from the cache (R-62).
                    ride.exchangeRide(routeFile: ride.mayHaveRoute
                        ? RideExchange.routeFileName(rideID: ride.id, fingerprint: ride.routeFingerprint) : nil)
                }),
            trash: trashed.filter { !$0.isSample }
                .compactMap { ride in
                    ride.deletedAt.map { PhoneDatabase.TrashedRide(ride: ride.exchangeRide(routeFile: nil), deletedAt: $0) }
                }
                .sorted { $0.deletedAt > $1.deletedAt },
            mergedRideIDs: Set(merged.map(\.id)),
            partCounts: Dictionary(merged.map { ($0.id, $0.parts?.count ?? 0) }, uniquingKeysWith: { first, _ in first }),
            rider: rider?.details,
            statsRides: listed
                .map { PhoneDatabase.StatsRide(name: $0.name, deviceID: $0.bike?.id, source: $0.source,
                                               countsInStatistics: $0.countsInStatistics, importedAt: $0.importedAt,
                                               highlight: $0.highlightRide) }
                .sorted { $0.highlight.startDate < $1.highlight.startDate },
            goals: Goal.sorted(goals).map { PhoneDatabase.GoalValue(id: $0.id, metric: $0.metric, period: $0.period, target: $0.target) },
            freeGoalCombinations: Goal.freeCombinations(besides: goals).map { GoalCombination(period: $0.period, metric: $0.metric) },
            activeDeviceID: rider?.activeBikeID,
            listedRideCounts: Dictionary(bikes.map { bike in
                (bike.id, (bike.rides ?? []).filter { $0.deletedAt == nil && $0.mergedInto == nil }.count)
            }, uniquingKeysWith: { first, _ in first }))
    }
}

/// Reads the library with its own context, off the main thread (B-381). Each reading sees what
/// is saved in the store; the iPhone saves its own changes before it asks.
@ModelActor
public actor LibraryReader {
    public func read(generator: String, now: Date = .now) throws -> LibraryReading {
        try LibraryReading.read(in: modelContext, generator: generator, now: now)
    }
}
