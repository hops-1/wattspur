import AppKit
import SwiftUI
import WattspurKit
import WattspurSymbols

// How a bike looks: the symbol of its kind, its colour and the round chip (B-133, PROF-03).

extension BikeColor {
    /// The shade for the current appearance; the lighter one in dark mode keeps the
    /// symbol readable (3:1 against the background).
    var color: Color {
        let (light, dark): (NSColor, NSColor) = switch self {
        case .blue: (.hex(0x0A6ED1), .hex(0x4DA3FF))
        case .orange: (.hex(0xC2410C), .hex(0xFF8A4C))
        case .teal: (.hex(0x0E7C86), .hex(0x4FC3CF))
        case .purple: (.hex(0x6E56CF), .hex(0xA98BEF))
        case .pink: (.hex(0xC2255C), .hex(0xF06595))
        case .green: (.hex(0x2F7D3A), .hex(0x6FCF7E))
        // Symbols must stay readable on the light tile: white is a light grey there (B-333).
        case .black: (.hex(0x1F2328), .hex(0x8B949E))
        case .silver: (.hex(0x6E7781), .hex(0xAFB8C1))
        case .white: (.hex(0x9AA4AE), .hex(0xF2F4F7))
        }
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    var name: LocalizedStringKey {
        switch self {
        case .blue: "Blue"
        case .orange: "Orange"
        case .teal: "Teal"
        case .purple: "Purple"
        case .pink: "Pink"
        case .green: "Green"
        case .black: "Black"
        case .silver: "Silver"
        case .white: "White"
        }
    }
}

private extension NSColor {
    static func hex(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

extension BikeKind {
    var name: LocalizedStringKey {
        switch self {
        case .bike: "Bicycle"
        case .mountain: "Mountain bike"
        case .road: "Road bike"
        case .gravel: "Gravel bike"
        case .cargo: "Cargo bike"
        case .scooter: "E-scooter"
        case .motorcycle: "Motorcycle"
        case .car: "Car"
        case .runningShoe: "Running shoes"
        }
    }

    /// The same text for places that need a `String` (VoiceOver values, subtitles).
    var title: String {
        switch self {
        case .bike: String(localized: "Bicycle")
        case .mountain: String(localized: "Mountain bike")
        case .road: String(localized: "Road bike")
        case .gravel: String(localized: "Gravel bike")
        case .cargo: String(localized: "Cargo bike")
        case .scooter: String(localized: "E-scooter")
        case .motorcycle: String(localized: "Motorcycle")
        case .car: String(localized: "Car")
        case .runningShoe: String(localized: "Running shoes")
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .bike: "Safe riding on roads and cycle paths"
        case .mountain: "Off-road on rough trails and singletracks"
        case .road: "Fast riding on paved roads"
        case .gravel: "Mixed surfaces and gravel tracks"
        case .cargo: "For kids, shopping and luggage"
        case .scooter: "Electric kick scooter; counts as cycling"
        case .motorcycle: "Tracked with the iPhone; not in the totals and the CO₂ saved"
        case .car: "Tracked with the iPhone; not in the cycling totals and the CO₂ saved"
        case .runningShoe: "Kilometres per pair"
        }
    }
}

/// The round symbol of a bike in its colour: in the profile, the lists and the menus.
struct BikeChip: View {
    let kind: BikeKind
    let color: BikeColor
    var size: CGFloat = 28
    /// A light version on a selected (accent colored) row.
    var onAccent = false
    /// The bike's name for VoiceOver where the chip is the only sign of the bike (lists,
    /// tables); `nil` where the name stands next to it, so it is read once.
    var accessibilityName: String?

    /// Small chips (lists, menus) give the symbol more of the circle and a stronger tint, so
    /// the rider and the wheels stay readable at 18 to 24 pt (B-174).
    private var isSmall: Bool { size < 28 }

    var body: some View {
        BikeKindIcon(kind: kind, size: size * (isSmall ? 0.8 : 0.62))
            .foregroundStyle(onAccent ? Color.white : color.color)
            .frame(width: size, height: size)
            .background(onAccent ? Color.white.opacity(0.24) : color.color.opacity(isSmall ? 0.22 : 0.14), in: Circle())
            .accessibilityHidden(accessibilityName == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityName.map { Text("Vehicle: \($0)") } ?? Text(verbatim: ""))
    }
}

extension Bike {
    var chip: BikeChip { BikeChip(kind: kind, color: color) }

    /// "Gravel bike · Bosch Performance Line SX · 400 Wh", without the parts that are empty.
    var subtitle: String {
        // Drive unit and battery belong to a bicycle only (B-284).
        let cycling = kind.sport == .cycling
        return [kind.title, cycling ? driveUnit.nonEmpty : nil, cycling ? batteryWh.map { "\($0) Wh" } : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// The photo, if there is one that can be read.
    var photo: NSImage? { photoData.flatMap(NSImage.init(data:)) }
}

/// The six colors as round buttons; one is checked (VoiceOver: a button with the color's name).
struct BikeColorPicker: View {
    @Binding var selection: BikeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Color").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(BikeColor.allCases) { color in
                    let selected = selection == color
                    Button { selection = color } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(color.isLight ? .black : .white)
                            .opacity(selected ? 1 : 0)
                            .frame(width: 32, height: 32)
                            .background(color == .white ? Color.white : color.color, in: Circle())
                            .overlay { Circle().strokeBorder(.separator).opacity(color.isLight ? 1 : 0) }
                            .overlay { Circle().strokeBorder(color.color, lineWidth: 2).padding(-4).opacity(selected ? 1 : 0) }
                    }
                    .buttonStyle(.plain)
                    .help(Text(color.name))
                    .accessibilityLabel(Text(color.name))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Color"))
    }
}
