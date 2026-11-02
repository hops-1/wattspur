import Foundation
import SwiftUI

/// Number formats of the iPhone app; units follow the device's region.
enum RideFormat {
    /// "21.4 km" (or miles where the region uses them).
    static func distance(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road,
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

    static func date(_ date: Date) -> String {
        date.formatted(date: .long, time: .shortened)
    }
}

extension Color {
    /// The track colour of the Mac app: magenta, lighter in dark mode so it stands out on the map.
    static let track = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF / 255, green: 0x4F / 255, blue: 0xAE / 255, alpha: 1)
            : UIColor(red: 0xC2 / 255, green: 0x18 / 255, blue: 0x7A / 255, alpha: 1)
    })
}
