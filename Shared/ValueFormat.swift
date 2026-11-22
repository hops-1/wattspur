import Foundation

/// The number formats the shared texts use (rule 6, `Shared/`), the same on the Mac and the
/// iPhone/iPad. Each app keeps its own `RideFormat` for the rest; the iPhone's shorter duration
/// ("1:24") stays for its lists and the recording.
enum ValueFormat {
    /// "00:48:36"
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2)))
    }

    /// "19.5" / "19,5" (kilometres, one decimal)
    static func distanceValue(_ metres: Double) -> String {
        (metres / 1000).formatted(.number.precision(.fractionLength(1)))
    }

    /// "19.5 km", always kilometres (S-16).
    static func distance(_ metres: Double) -> String {
        "\(distanceValue(metres)) km"
    }

    /// "24.1" (km/h, one decimal)
    static func speedValue(_ metresPerSecond: Double?) -> String {
        guard let metresPerSecond else { return "–" }
        return (metresPerSecond * 3.6).formatted(.number.precision(.fractionLength(1)))
    }
}
