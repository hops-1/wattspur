import Foundation

// Value types around the profile and the bikes (PROF-01, PROF-03, B-074).
// Raw values are stored in the model, so they must not change.

/// The sport of a ride (B-284, `DESIGN-SPORTARTEN.md`): each has its own totals and records.
/// Vehicles and running never count towards the cycling totals, records or the CO₂ saved.
public enum Sport: String, CaseIterable, Identifiable, Sendable {
    case cycling, vehicle, running

    public var id: Self { self }
}

/// The kind of device (in the model still “bike”), as in komoot; it decides the symbol (B-133)
/// and the sport (B-284). The cargo bike (B-201) is only a name and a symbol: it changes no
/// calculation.
///
/// Older versions (iPhone 1.0, Mac 1.8.x) read an unknown raw value as a bicycle, so a car counts
/// as a bike there; the handbook names the minimum version.
public enum BikeKind: String, CaseIterable, Identifiable, Sendable {
    case bike, mountain, road, gravel, cargo
    /// An e-scooter (B-330): counts as cycling, like a bicycle without pedalling (decision Nils
    /// 19.11.2026). Older versions read it as a bicycle.
    case scooter
    /// Tracked with the iPhone, e.g. by a friend on a motorcycle. Its rides stay out of the cycling
    /// totals, records and the CO₂ saved, unless the filter shows only this device.
    case motorcycle
    /// A car (B-284), like a motorcycle a vehicle.
    case car
    /// A pair of running shoes (B-284). The sport running comes with B-285; until then the kind
    /// is only known, not offered in the editor.
    case runningShoe

    public var id: Self { self }

    public var sport: Sport {
        switch self {
        case .bike, .mountain, .road, .gravel, .cargo, .scooter: .cycling
        case .motorcycle, .car: .vehicle
        case .runningShoe: .running
        }
    }

    /// Ridden with an engine: no own effort, nothing saved against a car.
    public var isMotorized: Bool { sport == .vehicle }

    /// The kinds the editor offers. Running shoes join with the sport running (B-285).
    public static var selectable: [BikeKind] { allCases.filter { $0 != .runningShoe } }

    /// The kind of a ride: its device's kind, else the kind stored with the ride (a ride without a
    /// device, e.g. recorded as “motorcycle”), else a bicycle. Unknown raw values from newer
    /// versions count as a bicycle.
    public static func of(device: String?, ride: String?) -> BikeKind {
        device.flatMap(BikeKind.init(rawValue:)) ?? ride.flatMap(BikeKind.init(rawValue:)) ?? .bike
    }
}

/// The colour of a bike's symbol. The shade for light and dark mode is the app's business.
public enum BikeColor: String, CaseIterable, Identifiable, Sendable {
    case blue, orange, teal, purple, pink, green
    /// The common car colours, for every device (B-333, wish Nils 19.11.2026). Older versions read
    /// them as blue.
    case black, silver, white

    public var id: Self { self }

    /// A light colour: its swatch needs a rim and a dark check mark.
    public var isLight: Bool { self == .silver || self == .white }
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
