import Foundation

// Value types around the profile and the bikes (PROF-01, PROF-03, B-074).
// Raw values are stored in the model, so they must not change.

/// The kind of bike, as in komoot; it decides the symbol (B-133).
public enum BikeKind: String, CaseIterable, Identifiable, Sendable {
    case bike, mountain, road, gravel

    public var id: Self { self }
}

/// The colour of a bike's symbol. The shade for light and dark mode is the app's business.
public enum BikeColor: String, CaseIterable, Identifiable, Sendable {
    case blue, orange, teal, purple, pink, green

    public var id: Self { self }
}

/// For the basal metabolic rate (B-067); "not specified" takes the mean of both formulas.
public enum RiderSex: String, CaseIterable, Identifiable, Sendable {
    case male, female, unspecified

    public var id: Self { self }
}

/// What the tile of a bike shows (B-134): number of rides, distance and the first and last ride.
public struct BikeStatistics: Sendable, Equatable {
    public var rideCount: Int
    /// Metres ridden in the bike's rides.
    public var ridesDistance: Double
    /// Metres the bike had before the first ride in Wattspur (`Bike.startKilometers`).
    public var startDistance: Double
    public var firstRide: Date?
    public var lastRide: Date?

    /// Metres including the start value.
    public var totalDistance: Double { ridesDistance + startDistance }

    public init(rideCount: Int = 0, ridesDistance: Double = 0, startDistance: Double = 0,
                firstRide: Date? = nil, lastRide: Date? = nil) {
        self.rideCount = rideCount
        self.ridesDistance = ridesDistance
        self.startDistance = startDistance
        self.firstRide = firstRide
        self.lastRide = lastRide
    }

    /// Statistics from the start date and distance (metres) of each ride.
    public init(rides: [(startDate: Date, distance: Double)], startKilometers: Double = 0) {
        self.init(
            rideCount: rides.count,
            ridesDistance: rides.reduce(0) { $0 + $1.distance },
            startDistance: max(0, startKilometers) * 1000,
            firstRide: rides.map(\.startDate).min(),
            lastRide: rides.map(\.startDate).max()
        )
    }
}
