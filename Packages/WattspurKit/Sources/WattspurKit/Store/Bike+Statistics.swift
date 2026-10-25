import Foundation

extension Ride {
    /// Counts in a bike's statistics: not in the trash, no sample, and not a part
    /// of a merged ride (the merged ride counts instead, as in all other totals).
    var countsForBikeStatistics: Bool { deletedAt == nil && !isSample && mergedInto == nil }
}

extension Bike {
    /// Rides, distance and first / last ride of this bike.
    public var statistics: BikeStatistics {
        let counted = (rides ?? []).filter(\.countsForBikeStatistics)
        return BikeStatistics(rides: counted.map { ($0.startDate, $0.distance) }, startKilometers: startKilometers)
    }

    /// Bikes in the order of the profile: by position, then by creation.
    public static func sorted(_ bikes: [Bike]) -> [Bike] {
        bikes.sorted { ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString) }
    }
}
