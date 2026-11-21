import SwiftUI
import WattspurCore
import WattspurSymbols

/// A bike from the Mac as a small symbol in its colour. The shades are those of the Mac app
/// (`App/BikeAppearance.swift`); sharing them without AppKit is B-187.
struct BikeBadge: View {
    var bike: RideExchange.Bike
    var size: CGFloat = BikeKind.imageSize

    var body: some View {
        (BikeKind(rawValue: bike.kind) ?? .bike).image(size: size)
            .foregroundStyle(color)
            .accessibilityLabel(bike.name)
    }

    /// The SF Symbol closest to a kind (B-284), only where no drawn symbol can go: Siri and
    /// Shortcuts. Everywhere else the app shows the drawn symbol of the Mac (`BikeKind.image`, B-342).
    nonisolated static func symbol(_ kind: BikeKind) -> String {
        switch kind {
        case .motorcycle: "motorcycle"
        case .car: "car"
        case .runningShoe: "shoe"
        case .scooter: "scooter"
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
        case .black: (0x1F2328, 0x8B949E)
        case .silver: (0x6E7781, 0xAFB8C1)
        case .white: (0x9AA4AE, 0xF2F4F7)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? .hex(dark) : .hex(light) })
    }
}

extension BikeKind {
    /// Points; the size of a symbol beside a line of body text.
    static let imageSize: CGFloat = 22

    /// The kind's drawn symbol, the same as on the Mac (B-342), as a template image: menus,
    /// pickers and labels show only images, no shapes. Tint it with `foregroundStyle`.
    @MainActor func image(size: CGFloat = imageSize) -> Image {
        let key = "\(rawValue)-\(size)"
        if let image = BikeKindImages.cache[key] { return image }
        let renderer = ImageRenderer(content: BikeKindIcon(kind: self, size: size).foregroundStyle(.black))
        renderer.scale = 3
        let image = renderer.uiImage.map { Image(uiImage: $0.withRenderingMode(.alwaysTemplate)) }
            ?? Image(systemName: BikeBadge.symbol(self))
        BikeKindImages.cache[key] = image
        return image
    }
}

/// Each kind is drawn once per size.
@MainActor private enum BikeKindImages {
    static var cache: [String: Image] = [:]
}

private extension UIColor {
    static func hex(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
