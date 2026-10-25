import Foundation

/// Which bike's rides an area shows (B-137, PROF-03): all of them or one bike. Each
/// area (rides, analysis, map, highlights) keeps its own choice, stored as `rawValue`.
public enum BikeFilter: RawRepresentable, Equatable, Hashable, Sendable {
    case all
    case bike(UUID)

    /// An empty text is "all bikes"; so is anything that is no bike id.
    public init(rawValue: String) {
        if let id = UUID(uuidString: rawValue) { self = .bike(id) } else { self = .all }
    }

    public var rawValue: String {
        switch self {
        case .all: ""
        case .bike(let id): id.uuidString
        }
    }

    public var bikeID: UUID? {
        if case .bike(let id) = self { id } else { nil }
    }

    public var isActive: Bool { self != .all }

    /// Whether a ride on the bike with this id (or none) passes the filter.
    public func admits(bikeID rideBikeID: UUID?) -> Bool {
        switch self {
        case .all: true
        case .bike(let id): rideBikeID == id
        }
    }

    /// The filter that applies given the bikes there are: with fewer than two bikes there
    /// is nothing to filter and the menu is hidden, so a choice made earlier must not
    /// keep working unseen; a bike that no longer exists counts as "all" as well.
    public func resolved(knownBikeIDs: Set<UUID>) -> BikeFilter {
        guard knownBikeIDs.count >= 2, let id = bikeID, knownBikeIDs.contains(id) else { return .all }
        return self
    }
}

extension Ride {
    /// Whether the ride passes a bike filter.
    public func isOnBike(_ filter: BikeFilter) -> Bool { filter.admits(bikeID: bike?.id) }
}
