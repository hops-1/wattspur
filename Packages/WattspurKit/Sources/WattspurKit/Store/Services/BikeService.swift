import Foundation
import SwiftData

/// Why a bike cannot be archived.
public enum BikeArchiveError: Error, Sendable, Equatable {
    /// There must always be a bike for new rides.
    case lastBike
}

/// The rider and the rider's bikes (PROF-03, B-007, B-074, B-134, B-135, B-138).
struct BikeService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    /// The single local profile; created on first use.
    func defaultRider() -> Rider {
        if let rider = try? context.fetch(FetchDescriptor<Rider>()).first { return rider }
        let rider = Rider()
        context.insert(rider)
        return rider
    }

    /// The bike new rides go to; see `activeBike()`. Kept for callers that only need
    /// "the bike of the rider".
    func defaultBike() -> Bike { activeBike() }

    /// All bikes of the library in the order of the profile (B-134).
    func bikes(includingArchived: Bool = true) -> [Bike] {
        let all = (try? context.fetch(FetchDescriptor<Bike>())) ?? []
        return Bike.sorted(includingArchived ? all : all.filter { !$0.isArchived })
    }

    /// The bike new rides are assigned to: the rider's chosen one, else (it is
    /// gone or archived) the preferred active bike, else a new default bike.
    /// Remembers the result as the rider's choice.
    @discardableResult
    func activeBike() -> Bike {
        let rider = defaultRider()
        let open = bikes(includingArchived: false)
        let bike: Bike
        if let id = rider.activeBikeID, let chosen = open.first(where: { $0.id == id }) {
            bike = chosen
        } else if let preferred = Self.preferredBike(in: open) {
            bike = preferred
        } else {
            bike = makeBike(name: env.defaultBikeName)
        }
        if rider.activeBikeID != bike.id { rider.activeBikeID = bike.id }
        if bike.rider == nil { bike.rider = rider }
        return bike
    }

    /// Makes `bike` the one new rides go to. An archived bike cannot be active.
    func setActiveBike(_ bike: Bike) {
        guard !bike.isArchived else { return }
        let rider = defaultRider()
        bike.rider = rider
        rider.activeBikeID = bike.id
        try? context.save()
    }

    /// Adds a bike after the existing ones. An empty name becomes the default name.
    @discardableResult
    func makeBike(name: String, kind: BikeKind = .bike, color: BikeColor = .blue) -> Bike {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // The position is worked out first: setting the rider already inserts the bike.
        let position = (bikes().map(\.sortOrder).max() ?? -1) + 1
        let bike = Bike(name: trimmed.isEmpty ? env.defaultBikeName : trimmed)
        bike.kind = kind
        bike.color = color
        bike.sortOrder = position
        context.insert(bike)
        bike.rider = defaultRider()
        try? context.save()
        return bike
    }

    /// Archives a bike (B-134). Its rides stay assigned and the bike stays in the
    /// filters, but it leaves the import menu. If it was the active bike, the next
    /// one takes over. The last open bike cannot be archived.
    func archive(_ bike: Bike) throws(BikeArchiveError) {
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
    func unarchive(_ bike: Bike) {
        guard bike.isArchived else { return }
        bike.isArchived = false
        try? context.save()
    }

    // MARK: - First bike and body data (B-138)

    /// Names and colors the bike new rides go to, as the setup assistant does for the
    /// first bike. An empty or blank name leaves the name as it is. Returns the bike.
    @discardableResult
    func configureActiveBike(name: String, color: BikeColor) -> Bike {
        let bike = activeBike()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { bike.name = trimmed }
        bike.color = color
        try? context.save()
        return bike
    }

    /// Stores the body data of the profile; values outside the plausible range are
    /// dropped (`ProfileInput`), `nil` clears a value.
    func setBodyData(weightKg: Double?, heightCm: Double?, birthYear: Int?, sex: RiderSex) {
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
    func assign(_ rides: [Ride], to bike: Bike) -> Int {
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

    /// Brings a library from before 1.5 in line with the model of PROF-03: one bike
    /// named "Mein eBike" that belongs to the rider and is active, all rides stay
    /// on it. Safe to call at every launch. Returns `true` if something changed.
    @discardableResult
    func prepareBikes() -> Bool {
        let rider = defaultRider()
        var changed = false
        var all = bikes()
        if all.isEmpty {
            makeBike(name: env.defaultBikeName)
            all = bikes()
            changed = true
        }
        for bike in all {
            if bike.rider == nil { bike.rider = rider; changed = true }
            if bike.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { bike.name = env.defaultBikeName; changed = true }
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

    /// Merges the bikes earlier versions created from the export's serial number
    /// into one and deletes the surplus. Only bikes with a serial number are
    /// touched; bikes made in the profile (PROF-03) never have one. The serial
    /// number of each is kept on its rides as metadata. Rides without a bike go
    /// to the active bike. Returns the number of deleted bikes.
    @discardableResult
    func mergeBikes() -> Int {
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
}
