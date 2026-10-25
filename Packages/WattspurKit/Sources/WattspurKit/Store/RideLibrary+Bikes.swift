import Foundation
import SwiftData

/// Managing the rider's bikes (PROF-03, B-074). Assigning rides is B-135.
extension RideLibrary {
    /// The name of the bike every library starts with and that bikes without a
    /// name get (REQUIREMENTS.md 10.16). The app sets the localized name at launch.
    public static var defaultBikeName = "Mein eBike"

    /// All bikes of the library in the order of the profile (B-134).
    public func bikes(includingArchived: Bool = true) -> [Bike] {
        let all = (try? context.fetch(FetchDescriptor<Bike>())) ?? []
        return Bike.sorted(includingArchived ? all : all.filter { !$0.isArchived })
    }

    /// The bike new rides are assigned to: the rider's chosen one, else (it is
    /// gone or archived) the preferred active bike, else a new default bike.
    /// Remembers the result as the rider's choice.
    @discardableResult
    public func activeBike() -> Bike {
        let rider = defaultRider()
        let open = bikes(includingArchived: false)
        let bike: Bike
        if let id = rider.activeBikeID, let chosen = open.first(where: { $0.id == id }) {
            bike = chosen
        } else if let preferred = Self.preferredBike(in: open) {
            bike = preferred
        } else {
            bike = makeBike(name: Self.defaultBikeName)
        }
        if rider.activeBikeID != bike.id { rider.activeBikeID = bike.id }
        if bike.rider == nil { bike.rider = rider }
        return bike
    }

    /// Makes `bike` the one new rides go to. An archived bike cannot be active.
    public func setActiveBike(_ bike: Bike) {
        guard !bike.isArchived else { return }
        let rider = defaultRider()
        bike.rider = rider
        rider.activeBikeID = bike.id
        try? context.save()
    }

    /// Adds a bike after the existing ones. An empty name becomes the default name.
    @discardableResult
    public func makeBike(name: String, kind: BikeKind = .bike, color: BikeColor = .blue) -> Bike {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // The position is worked out first: setting the rider already inserts the bike.
        let position = (bikes().map(\.sortOrder).max() ?? -1) + 1
        let bike = Bike(name: trimmed.isEmpty ? Self.defaultBikeName : trimmed)
        bike.kind = kind
        bike.color = color
        bike.sortOrder = position
        context.insert(bike)
        bike.rider = defaultRider()
        try? context.save()
        return bike
    }

    /// Why a bike cannot be archived.
    public enum ArchiveError: Error, Sendable, Equatable {
        /// There must always be a bike for new rides.
        case lastBike
    }

    /// Archives a bike (B-134). Its rides stay assigned and the bike stays in the
    /// filters, but it leaves the import menu. If it was the active bike, the next
    /// one takes over. The last open bike cannot be archived.
    public func archive(_ bike: Bike) throws(ArchiveError) {
        guard !bike.isArchived else { return }
        let others = bikes(includingArchived: false).filter { $0 !== bike }
        guard !others.isEmpty else { throw .lastBike }
        bike.isArchived = true
        let rider = defaultRider()
        if rider.activeBikeID == bike.id { rider.activeBikeID = nil }
        activeBike()
        try? context.save()
    }

    /// Takes a bike out of the archive; it does not become the active bike.
    public func unarchive(_ bike: Bike) {
        guard bike.isArchived else { return }
        bike.isArchived = false
        try? context.save()
    }

    // MARK: - First bike and body data (B-138)

    /// Names and colors the bike new rides go to, as the setup assistant does for the
    /// first bike. An empty or blank name leaves the name as it is. Returns the bike.
    @discardableResult
    public func configureActiveBike(name: String, color: BikeColor) -> Bike {
        let bike = activeBike()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { bike.name = trimmed }
        bike.color = color
        try? context.save()
        return bike
    }

    /// Stores the body data of the profile; values outside the plausible range are
    /// dropped (`ProfileInput`), `nil` clears a value.
    public func setBodyData(weightKg: Double?, heightCm: Double?, birthYear: Int?, sex: RiderSex) {
        let rider = defaultRider()
        rider.weightKg = ProfileInput.accepted(weightKg, in: ProfileInput.weightKg)
        rider.heightCm = ProfileInput.accepted(heightCm, in: ProfileInput.heightCm)
        rider.birthYear = ProfileInput.accepted(birthYear, in: ProfileInput.birthYears())
        rider.sex = sex
        try? context.save()
    }

    // MARK: - Assigning rides (B-135)

    /// Assigns rides to a bike, in one save, so one ⌘Z takes them all back. A merged
    /// ride takes its parts along, so the bike stays the same after splitting it.
    /// Rides that already belong to the bike are left alone. Returns the number of
    /// rides that changed (parts not counted); nothing is registered for undo if it is 0.
    @discardableResult
    public func assign(_ rides: [Ride], to bike: Bike) -> Int {
        var seen = Set<UUID>()
        let affected = rides.flatMap { [$0] + $0.sortedParts }.filter { seen.insert($0.id).inserted }
        let changes = affected.filter { $0.bike !== bike }
        guard !changes.isEmpty else { return 0 }
        setBikes(changes.map { ($0, bike) })
        return rides.filter { changes.contains($0) }.count
    }

    /// Changes the bikes of rides; undo puts back each ride's previous bike.
    private func setBikes(_ changes: [(ride: Ride, bike: Bike?)]) {
        let previous = changes.map { ($0.ride, $0.ride.bike) }
        for change in changes { change.ride.bike = change.bike }
        try? context.save()
        registerUndo { $0.setBikes(previous) }
    }

    /// Statistics of a bike for its tile (B-134).
    public func statistics(for bike: Bike) -> BikeStatistics { bike.statistics }

    /// Brings a library from before 1.5 in line with the model of PROF-03: one bike
    /// named "Mein eBike" that belongs to the rider and is active, all rides stay
    /// on it. Safe to call at every launch. Returns `true` if something changed.
    @discardableResult
    public func prepareBikes() -> Bool {
        let rider = defaultRider()
        var changed = false
        var all = bikes()
        if all.isEmpty {
            makeBike(name: Self.defaultBikeName)
            all = bikes()
            changed = true
        }
        for bike in all {
            if bike.rider == nil { bike.rider = rider; changed = true }
            if bike.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { bike.name = Self.defaultBikeName; changed = true }
        }
        // Libraries from before 1.5 have no positions; keep the creation order.
        if Set(all.map(\.sortOrder)).count < all.count {
            for (index, bike) in all.sorted(by: { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }).enumerated() {
                bike.sortOrder = index
            }
            changed = true
        }
        let before = rider.activeBikeID
        activeBike()
        if rider.activeBikeID != before { changed = true }
        if changed { try? context.save() }
        return changed
    }
}
