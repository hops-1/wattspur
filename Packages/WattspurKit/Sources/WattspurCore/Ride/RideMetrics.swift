import Foundation

/// Estimates calories for a ride (Requirements chapter 7: exchangeable strategy).
public protocol CalorieEstimator: Sendable {
    func kilocalories(for metrics: RideMetrics) -> Double
}

/// Work only: kcal ≈ mechanical work (kJ) × factor, without the time share. The app uses
/// `CalorieModel`, which matches the Flow app (V-01).
public struct WorkBasedCalorieEstimator: CalorieEstimator {
    public var factor: Double

    public init(factor: Double = CalorieModel.flowFactor) {
        self.factor = factor
    }

    public func kilocalories(for metrics: RideMetrics) -> Double {
        metrics.workKilojoules * factor
    }
}

/// Values Wattspur derives itself because the source file does not contain them.
public struct RideMetrics: Sendable, Equatable {
    /// Mechanical work of the rider in kJ (Σ power × 1 s per record).
    public var workKilojoules: Double
    public var pausedTime: TimeInterval
    public var minAltitude: Double?
    public var maxAltitude: Double?
    /// Ride distance in kilometres (from the summary).
    public var distanceKilometres: Double

    public init(ride: ParsedRide) {
        let powerSum = ride.samples.reduce(0) { $0 + ($1.power ?? 0) }
        workKilojoules = ride.workKilojoules ?? Double(powerSum) / 1000
        pausedTime = max(0, ride.summary.elapsedTime - ride.summary.timerTime)
        let altitudes = ride.samples.compactMap(\.altitude)
        minAltitude = altitudes.min()
        maxAltitude = altitudes.max()
        distanceKilometres = ride.summary.distance / 1000
    }

    /// CO₂ saved compared to a car in kg/km; a hypothesis from one ride (Requirements 3.4).
    public static let defaultCO2PerKilometre = 0.159

    /// CO₂ saved compared to a car.
    public func co2SavedKilograms(factorPerKilometre: Double = defaultCO2PerKilometre) -> Double {
        distanceKilometres * factorPerKilometre
    }
}
