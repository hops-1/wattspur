import Foundation

/// The totals and records of one sport for the profile on the iPhone (B-299): distance, rides and
/// ride time, the longest ride and the top speed. Every sport counts on its own (B-284), so a car
/// never lands in the cycling totals and the other way round.
public struct SportTotals: Sendable, Equatable, Identifiable {
    /// A record: the ride that holds it and its value (metres, or metres per second).
    public struct Best: Sendable, Equatable {
        public var rideID: UUID
        public var value: Double
    }

    public var sport: Sport
    public var rides: Int
    /// Metres.
    public var distance: Double
    /// Seconds in motion.
    public var rideTime: TimeInterval
    public var longest: Best?
    public var fastest: Best?

    public var id: Sport { sport }

    /// The totals of the given rides, all of one sport.
    public init(sport: Sport, rides: [RideExchange.Ride]) {
        self.sport = sport
        self.rides = rides.count
        distance = rides.reduce(0) { $0 + max($1.distance, 0) }
        rideTime = rides.reduce(0) { $0 + max($1.timerTime, 0) }
        longest = rides.filter { $0.distance > 0 }
            .max { ($0.distance, $1.id.uuidString) < ($1.distance, $0.id.uuidString) }
            .map { Best(rideID: $0.id, value: $0.distance) }
        fastest = rides.compactMap { ride in ride.maxSpeed.flatMap { $0 > 0 && $0.isFinite ? Best(rideID: ride.id, value: $0) : nil } }
            .max { ($0.value, $1.rideID.uuidString) < ($1.value, $0.rideID.uuidString) }
    }
}

extension RideExchange.Library {
    /// The totals per sport, cycling first, then vehicles and running; only sports with rides.
    /// Without any ride, cycling with zeros, so the profile always has its first tiles.
    public func sportTotals() -> [SportTotals] {
        let bySport = Dictionary(grouping: rides) { sport(of: $0) }
        let totals = Sport.allCases.compactMap { sport in
            bySport[sport].map { SportTotals(sport: sport, rides: $0) }
        }
        return totals.isEmpty ? [SportTotals(sport: .cycling, rides: [])] : totals
    }

    /// The devices grouped by sport for the profile (B-299): bikes, vehicles, shoes, each by name;
    /// archived ones last. Only sports that have a device.
    public func devicesBySport() -> [(sport: Sport, devices: [RideExchange.Bike])] {
        let bySport = Dictionary(grouping: bikes) { (BikeKind(rawValue: $0.kind) ?? .bike).sport }
        return Sport.allCases.compactMap { sport in
            guard let devices = bySport[sport] else { return nil }
            return (sport, devices.sorted {
                ($0.isArchived ? 1 : 0, $0.name.localizedLowercase, $0.id.uuidString)
                    < ($1.isArchived ? 1 : 0, $1.name.localizedLowercase, $1.id.uuidString)
            })
        }
    }

    /// The rides on a device and their distance in metres, for its row in the profile.
    public func usage(of bikeID: UUID) -> (rides: Int, distance: Double) {
        let onIt = rides.filter { $0.bikeID == bikeID }
        return (onIt.count, onIt.reduce(0) { $0 + max($1.distance, 0) })
    }
}
