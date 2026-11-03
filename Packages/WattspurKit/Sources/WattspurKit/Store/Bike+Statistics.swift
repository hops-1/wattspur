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

    /// How much the wheel sensor measures more (positive) or less than GPS, from the newest
    /// `rides` Bosch rides of this bike, if it is large enough for the hint (B-237, `WheelCheck`).
    /// Parts of merged rides count, the merged ride not: it has no FIT of its own.
    public func wheelCheckHint(rides limit: Int = 20) -> Double? {
        let fit = (rides ?? [])
            .filter { $0.deletedAt == nil && !$0.isSample && !$0.isMerged && $0.source == .fit && $0.samplesData != nil }
            .sorted { $0.startDate > $1.startDate }
            .prefix(limit)
        return WheelCheck.hint(fit.map { WheelCheck.measure($0.samples) })
    }

    /// Bikes in the order of the profile: by position, then by creation.
    public static func sorted(_ bikes: [Bike]) -> [Bike] {
        bikes.sorted { ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString) }
    }
}
