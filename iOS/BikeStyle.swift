import SwiftUI
import WattspurCore

/// A bike from the Mac as a small symbol in its colour. The shades are those of the Mac app
/// (`App/BikeAppearance.swift`); sharing them without AppKit is B-187.
struct BikeBadge: View {
    var bike: RideExchange.Bike

    var body: some View {
        Image(systemName: Self.symbol(BikeKind(rawValue: bike.kind) ?? .bike))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityLabel(bike.name)
    }

    /// The SF Symbol of a kind (B-284): a car, a motorcycle, a shoe or a bicycle.
    nonisolated static func symbol(_ kind: BikeKind) -> String {
        switch kind {
        case .motorcycle: "motorcycle"
        case .car: "car"
        case .runningShoe: "shoe"
        case .bike, .mountain, .road, .gravel, .cargo: "bicycle"
        }
    }

    var color: Color { Self.color(BikeColor(rawValue: bike.color) ?? .blue) }

    /// The shade of a bike colour, light and dark like on the Mac.
    static func color(_ bikeColor: BikeColor) -> Color {
        let (light, dark): (UInt32, UInt32) = switch bikeColor {
        case .blue: (0x0A6ED1, 0x4DA3FF)
        case .orange: (0xC2410C, 0xFF8A4C)
        case .teal: (0x0E7C86, 0x4FC3CF)
        case .purple: (0x6E56CF, 0xA98BEF)
        case .pink: (0xC2255C, 0xF06595)
        case .green: (0x2F7D3A, 0x6FCF7E)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? .hex(dark) : .hex(light) })
    }
}

private extension UIColor {
    static func hex(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
