import Foundation
import SwiftData

/// What `RideLibrary.mergeSyncDuplicates()` removed.
public struct SyncMergeReport: Equatable, Sendable {
    public var riders = 0
    public var bikes = 0
    public var goals = 0
    public var rides = 0

    public init(riders: Int = 0, bikes: Int = 0, goals: Int = 0, rides: Int = 0) {
        self.riders = riders
        self.bikes = bikes
        self.goals = goals
        self.rides = rides
    }

    public var isEmpty: Bool { riders + bikes + goals + rides == 0 }
}

/// Merges what two devices made on their own before they synced (B-216, V-15).
///
/// CloudKit has no unique constraints. Each device makes its own rider and its own "My eBike" on the
/// first start, a goal may be set on both, and a file imported on the Mac and the iPhone becomes two
/// rides. After the first sync the library then holds two of each.
///
/// Both devices run this on their own, possibly at the same time, and each sees the other's records
/// only as far as the sync has come. So the record that stays is chosen by what both see alike: the
/// oldest (`createdAt`, then `id`), never by counts like the number of rides, which differ while the
/// sync is running. Otherwise each device could keep its own and delete the other's.
struct SyncMergeService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    func mergeDuplicates() -> SyncMergeReport {
        var report = SyncMergeReport()
        report.riders = mergeRiders()
        report.bikes = mergeBikes()
        report.goals = mergeGoals()
        report.rides = mergeRides()
        if !report.isEmpty {
            // The active bike may have been one of the removed ones.
            _ = BikeService(env).activeBike()
            try? context.save()
        }
        return report
    }

    // MARK: - Riders

    /// There is one rider: the oldest stays and takes the rides, bikes and what the others know.
    private func mergeRiders() -> Int {
        let riders = ((try? context.fetch(FetchDescriptor<Rider>())) ?? []).sorted(by: Self.older)
        guard let keeper = riders.first, riders.count > 1 else { return 0 }
        for other in riders.dropFirst() {
            for ride in other.rides ?? [] { ride.rider = keeper }
            for bike in other.bikes ?? [] { bike.rider = keeper }
            if keeper.name.isEmpty { keeper.name = other.name }
            if keeper.weightKg == nil { keeper.weightKg = other.weightKg }
            if keeper.heightCm == nil { keeper.heightCm = other.heightCm }
            if keeper.birthYear == nil { keeper.birthYear = other.birthYear }
            if keeper.sex == .unspecified { keeper.sex = other.sex }
            if keeper.photoData == nil { keeper.photoData = other.photoData }
            if keeper.activeBikeID == nil { keeper.activeBikeID = other.activeBikeID }
            context.delete(other)
        }
        return riders.count - 1
    }

    // MARK: - Bikes

    /// Bikes that each device made for itself become the oldest of them: the default bike of the same
    /// kind (its name not changed, possibly with rides already), or the same bike by its serial
    /// number. Two bikes the user named alike stay two (R-36): a second "Cube" may be meant. Then an
    /// untouched default bike (no rides, nothing filled in), which a device makes on its first start,
    /// goes if an older open bike exists: the user has named theirs, so the names differ.
    private func mergeBikes() -> Int {
        var removed = 0
        let all = ((try? context.fetch(FetchDescriptor<Bike>())) ?? []).sorted(by: Self.older)
        let groups = Dictionary(grouping: all, by: mergeKey)
        var gone = Set<UUID>()
        for (key, bikes) in groups where key != nil && bikes.count > 1 {
            let sorted = bikes.sorted(by: Self.older)
            let keeper = sorted[0]
            for other in sorted.dropFirst() {
                for ride in other.rides ?? [] { ride.bike = keeper }
                Self.fill(keeper, from: other)
                gone.insert(other.id)
                context.delete(other)
                removed += 1
            }
        }
        let left = all.filter { !gone.contains($0.id) }
        for (index, bike) in left.enumerated() where index > 0 && isUntouchedDefault(bike) {
            let olderOpen = left[..<index].contains { !$0.isArchived }
            guard olderOpen else { continue }
            context.delete(bike)
            removed += 1
        }
        return removed
    }

    /// `nil` for a bike that is only ever merged as an untouched default.
    private func mergeKey(_ bike: Bike) -> String? {
        if let serial = bike.serialNumber { return "serial|\(serial)" }
        guard Self.normalized(bike.name) == Self.normalized(env.defaultBikeName) else { return nil }
        return "default|\(bike.kindRawValue)"
    }

    private func isUntouchedDefault(_ bike: Bike) -> Bool {
        (bike.rides ?? []).isEmpty && Self.normalized(bike.name) == Self.normalized(env.defaultBikeName)
            && !bike.isArchived && bike.serialNumber == nil && bike.photoData == nil
            && bike.manufacturer.isEmpty && bike.model.isEmpty && bike.driveUnit.isEmpty
            && bike.batteryWh == nil && bike.weightKg == nil && bike.purchaseDate == nil && bike.startKilometers == 0
    }

    private static func fill(_ keeper: Bike, from other: Bike) {
        if keeper.photoData == nil { keeper.photoData = other.photoData }
        if keeper.manufacturer.isEmpty { keeper.manufacturer = other.manufacturer }
        if keeper.model.isEmpty { keeper.model = other.model }
        if keeper.driveUnit.isEmpty { keeper.driveUnit = other.driveUnit }
        if keeper.batteryWh == nil { keeper.batteryWh = other.batteryWh }
        if keeper.weightKg == nil { keeper.weightKg = other.weightKg }
        if keeper.purchaseDate == nil { keeper.purchaseDate = other.purchaseDate }
        if keeper.startKilometers == 0 { keeper.startKilometers = other.startKilometers }
    }

    // MARK: - Goals

    /// One goal per measure and period: the oldest stays with its target.
    private func mergeGoals() -> Int {
        let goals = ((try? context.fetch(FetchDescriptor<Goal>())) ?? [])
        var removed = 0
        for group in Dictionary(grouping: goals, by: { "\($0.metricRawValue)|\($0.periodRawValue)" }).values where group.count > 1 {
            for other in group.sorted(by: { Self.older($0.createdAt, $0.id, $1.createdAt, $1.id) }).dropFirst() {
                context.delete(other)
                removed += 1
            }
        }
        return removed
    }

    // MARK: - Rides

    /// The same export imported on two devices: the same Bosch ID (`sourceIdentifier`) and format.
    /// The ride imported first stays. Merged rides and their parts are left alone; the user decides there.
    private func mergeRides() -> Int {
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.mergedInto == nil && !$0.isSample })
        let rides = ((try? context.fetch(descriptor)) ?? []).filter { !$0.isMerged }
        var removed = 0
        for group in Dictionary(grouping: rides, by: Self.syncKey).values where group.count > 1 {
            let sorted = group.sorted { Self.older($0.importedAt, $0.id, $1.importedAt, $1.id) }
            let keeper = sorted[0]
            for other in sorted.dropFirst() {
                take(from: other, to: keeper)
                context.delete(other)
                removed += 1
            }
        }
        return removed
    }

    /// What the user changed at the copy that goes (R-35): its name, its bike, that it is not in the
    /// trash, a GPX attached to the Bosch ride. The keeper's own changes win; both devices end alike,
    /// whichever merges first.
    private func take(from other: Ride, to keeper: Ride) {
        if !isRenamed(keeper), isRenamed(other) || keeper.name.isEmpty { keeper.name = other.name }
        if !hasOwnBike(keeper), hasOwnBike(other) { keeper.bike = other.bike }
        if other.deletedAt == nil { keeper.deletedAt = nil }
        if keeper.attachedSourceFormat == nil, other.attachedSourceFormat != nil {
            keeper.attachedSourceName = other.attachedSourceName
            keeper.attachedSourceFormat = other.attachedSourceFormat
            keeper.setSamples(other.samples)
        }
    }

    /// Whether the ride's name is not the one its file gave it.
    private func isRenamed(_ ride: Ride) -> Bool {
        guard let fileName = ride.sourceFile?.fileName, !fileName.isEmpty else { return false }
        return ride.name != ImportService.parseFileName(fileName).title
    }

    private func hasOwnBike(_ ride: Ride) -> Bool {
        guard let bike = ride.bike else { return false }
        return Self.normalized(bike.name) != Self.normalized(env.defaultBikeName)
    }

    /// What makes two rides one: the Bosch ride UUID of an export. A GPX has none, so an iPhone
    /// recording saved on the iPhone and the same GPX imported on the Mac before the sync brought it
    /// (7.11.2026) match by bike, start, length and distance instead; two different rides never share
    /// all of them to the millisecond and the metre.
    private static func syncKey(_ ride: Ride) -> String {
        if ride.sourceIdentifier != "" { return "\(ride.sourceFormat)|\(ride.sourceIdentifier)" }
        guard isRecordingKeyed(ride) else { return "none|\(ride.id.uuidString)" }
        let start = (ride.startDate.timeIntervalSinceReferenceDate * 1000).rounded()
        return "gpx|\(ride.bike?.id.uuidString ?? "-")|\(start)|\(ride.elapsedTime.rounded())|\(ride.distance.rounded())"
    }

    /// A ride in the trash is left out: the user may have thrown one of the two away by hand, and the
    /// one that stays must not be the thrown away one.
    private static func isRecordingKeyed(_ ride: Ride) -> Bool {
        ride.sourceIdentifier == "" && ride.sourceFormat == RideSource.gpx.rawValue && ride.distance > 0
            && ride.deletedAt == nil
    }

    // MARK: - Order

    private static func older(_ a: Rider, _ b: Rider) -> Bool { older(a.createdAt, a.id, b.createdAt, b.id) }
    private static func older(_ a: Bike, _ b: Bike) -> Bool { older(a.createdAt, a.id, b.createdAt, b.id) }

    private static func older(_ dateA: Date, _ idA: UUID, _ dateB: Date, _ idB: UUID) -> Bool {
        dateA != dateB ? dateA < dateB : idA.uuidString < idB.uuidString
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
