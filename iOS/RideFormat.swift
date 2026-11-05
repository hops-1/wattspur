import Foundation
import SwiftUI
import WattspurCore

/// Number formats of the iPhone app; units follow the device's region.
enum RideFormat {
    /// "21.4 km" (or miles where the region uses them), also for short and zero distances: a
    /// week without rides reads “0.0 km”, not “0.0 m”.
    static func distance(_ metres: Double) -> String {
        let unit: UnitLength = Locale.current.measurementSystem == .metric ? .kilometers : .miles
        return Measurement(value: metres, unit: UnitLength.meters).converted(to: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(1))))
    }

    /// "1:24 h"-style riding time, from the moving time of the ride.
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinute))
    }

    /// "312 m" of climbing.
    static func ascent(_ metres: Int) -> String {
        Measurement(value: Double(metres), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    /// “2. November 2026 um 14:12”, in the time zone where the ride started (as on the Mac).
    static func date(_ date: Date, timeZone: String? = nil) -> String {
        var style = Date.FormatStyle(date: .long, time: .shortened)
        style.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        return date.formatted(style)
    }

    /// “Mo., 2. Nov., 14:12” for a row of the ride list.
    static func shortDate(_ date: Date, timeZone: String? = nil) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).hour().minute()
        style.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        return date.formatted(style)
    }

    /// “November 2026” above the rides of a month.
    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    /// “Heute, 14:02” or “31.10.26, 09:15”: when the Mac wrote its state.
    static func stateDate(_ date: Date) -> String {
        relativeFormatter.string(from: date)
    }

    private static let relativeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    /// “23.5 km/h”.
    static func speed(_ metresPerSecond: Double) -> String {
        Measurement(value: metresPerSecond, unit: UnitSpeed.metersPerSecond).converted(to: .kilometersPerHour)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(1))))
    }

    /// “23.5” without the unit, for the large speed of the landscape recording (B-243); always km/h, as `speed`.
    static func speedNumber(_ metresPerSecond: Double) -> String {
        (metresPerSecond * 3.6).formatted(.number.precision(.fractionLength(1)))
    }

    /// “184 m” of altitude.
    static func altitude(_ metres: Double) -> String {
        ascent(Int(metres.rounded()))
    }

    /// “38°” of lean, without a sign (B-246).
    static func lean(_ degrees: Double) -> String {
        "\(abs(degrees).formatted(.number.precision(.fractionLength(0))))°"
    }

    /// “0.62 g” of acceleration or braking, without a sign (B-246).
    static func gForce(_ g: Double) -> String {
        "\(abs(g).formatted(.number.precision(.fractionLength(2)))) g"
    }

    /// “12 %” of the distance (B-248).
    static func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }

    /// “3.5 s” for a sprint (B-246).
    static func seconds(_ seconds: Double) -> String {
        "\(seconds.formatted(.number.precision(.fractionLength(1)))) s"
    }
}

extension Color {
    /// The track colour of the Mac app: magenta, lighter in dark mode so it stands out on the map.
    static let track = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF / 255, green: 0x4F / 255, blue: 0xAE / 255, alpha: 1)
            : UIColor(red: 0xC2 / 255, green: 0x18 / 255, blue: 0x7A / 255, alpha: 1)
    })

    /// The track by lean angle (B-246): from green upright through yellow and orange to red and purple.
    static func lean(_ band: RideMotion.LeanBand) -> Color {
        switch band {
        case .upright: .green
        case .slight: .yellow
        case .medium: .orange
        case .strong: .red
        case .extreme: .purple
        }
    }

    /// The track by road surface (B-248): grey smooth, yellow uneven, brown rough.
    static func surface(_ band: RideMotion.SurfaceBand) -> Color {
        switch band {
        case .smooth: .gray
        case .uneven: .yellow
        case .rough: .brown
        }
    }
}
