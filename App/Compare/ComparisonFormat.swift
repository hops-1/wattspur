import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Formatting

/// Titles and locale-aware values for the comparison (NFR-10).
enum ComparisonFormat {
    static func title(_ group: ComparisonGroup) -> LocalizedStringKey {
        switch group {
        case .ride: "Ride"
        case .speed: "Speed"
        case .elevation: "Elevation"
        case .power: "Power and cadence"
        case .estimates: "Estimates"
        case .perKilometre: "Comparable across ride lengths"
        }
    }

    static func title(_ metric: ComparisonMetric) -> LocalizedStringKey {
        switch metric {
        case .rideTime: "Ride time"
        case .totalTime: "Total time"
        case .pausedTime: "Paused"
        case .distance: "Distance"
        case .averageSpeed: "Avg speed"
        case .maxSpeed: "Max speed"
        case .ascent: "Ascent"
        case .descent: "Descent"
        case .minAltitude: "Min elevation"
        case .maxAltitude: "Max elevation"
        case .averagePower: "Avg power"
        case .maxPower: "Max power"
        case .averageCadence: "Avg cadence"
        case .maxCadence: "Max cadence"
        case .work: "Work"
        case .calories: "Calories"
        case .co2Saved: "CO₂ saved"
        case .caloriesPerKilometre: "Calories per km"
        case .ascentPerKilometre: "Ascent per km"
        case .workPerKilometre: "Work per km"
        case .coastingShare: "Coasting share"
        case .averagePowerOverRideTime: "Avg power over ride time"
        }
    }

    /// A value in its display unit, e.g. "24.1 km/h" or "00:48:36".
    static func value(_ v: Double, _ metric: ComparisonMetric) -> String {
        switch metric {
        case .rideTime, .totalTime, .pausedTime: RideFormat.duration(v)
        default: "\(number(v, metric)) \(unit(metric))"
        }
    }

    /// "+2.1 km/h · +9 %"; durations as "+0:12 h" or "−8 min"; the coasting share in percentage points.
    static func deviation(_ d: ComparisonDeviation, _ metric: ComparisonMetric) -> String {
        let sign = d.absolute > 0.0005 ? "+" : d.absolute < -0.0005 ? "−" : "±"
        let magnitude = abs(d.absolute)
        let absolute: String = switch metric {
        case .rideTime, .totalTime, .pausedTime: shortDuration(magnitude)
        case .coastingShare: "\((magnitude * 100).formatted(.number.precision(.fractionLength(0)))) \(String(localized: "pp"))"
        default: "\(number(magnitude, metric)) \(unit(metric))"
        }
        guard metric != .coastingShare, let relative = d.relative else { return sign + absolute }
        let percent = Int((relative * 100).rounded())
        let pSign = percent > 0 ? "+" : percent < 0 ? "−" : "±"
        return "\(sign)\(absolute) · \(pSign)\(abs(percent)) %"
    }

    private static func number(_ v: Double, _ metric: ComparisonMetric) -> String {
        switch metric {
        case .distance: (v / 1000).formatted(.number.precision(.fractionLength(1)))
        case .averageSpeed, .maxSpeed: (v * 3.6).formatted(.number.precision(.fractionLength(1)))
        case .co2Saved, .caloriesPerKilometre, .ascentPerKilometre, .workPerKilometre:
            v.formatted(.number.precision(.fractionLength(1)))
        case .coastingShare: (v * 100).formatted(.number.precision(.fractionLength(0)))
        default: v.formatted(.number.precision(.fractionLength(0)))
        }
    }

    private static func unit(_ metric: ComparisonMetric) -> String {
        switch metric {
        case .rideTime, .totalTime, .pausedTime: ""
        case .distance: "km"
        case .averageSpeed, .maxSpeed: "km/h"
        case .ascent, .descent, .minAltitude, .maxAltitude: "m"
        case .averagePower, .maxPower, .averagePowerOverRideTime: "W"
        case .averageCadence, .maxCadence: String(localized: "rpm")
        case .work: "kJ"
        case .calories: "kcal"
        case .co2Saved: "kg"
        case .caloriesPerKilometre: "kcal/km"
        case .ascentPerKilometre: "m/km"
        case .workPerKilometre: "kJ/km"
        case .coastingShare: "%"
        }
    }

    /// "12 min" or "1:05 h".
    private static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = total % 3600 / 60
        return hours > 0 ? String(format: "%d:%02d h", hours, minutes) : "\(minutes) min"
    }
}
