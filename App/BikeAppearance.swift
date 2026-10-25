import AppKit
import SwiftUI
import WattspurKit

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
        }
    }

    /// The same text for places that need a `String` (VoiceOver values, subtitles).
    var title: String {
        switch self {
        case .bike: String(localized: "Bicycle")
        case .mountain: String(localized: "Mountain bike")
        case .road: String(localized: "Road bike")
        case .gravel: String(localized: "Gravel bike")
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .bike: "Safe riding on roads and cycle paths"
        case .mountain: "Off-road on rough trails and singletracks"
        case .road: "Fast riding on paved roads"
        case .gravel: "Mixed surfaces and gravel tracks"
        }
    }
}

/// The symbol of a bike kind, drawn like komoot's: a rider on a bike, with sparkles
/// for the bicycle, waves for the mountain bike and dots for the gravel bike.
/// Drawn in a 24 × 24 box and scaled to the frame; stroke it, do not fill it.
struct BikeKindShape: Shape {
    let kind: BikeKind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + x * s, y: origin.y + y * s) }
        func circle(_ x: Double, _ y: Double, _ r: Double) {
            path.addEllipse(in: CGRect(x: origin.x + (x - r) * s, y: origin.y + (y - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        func line(_ points: (Double, Double)...) {
            guard let first = points.first else { return }
            path.move(to: p(first.0, first.1))
            for point in points.dropFirst() { path.addLine(to: p(point.0, point.1)) }
        }
        // Wheels, frame, rider and head.
        circle(6, 15, 3)
        circle(18, 15, 3)
        line((6, 15), (9, 10), (14, 10))
        line((14, 10), (18, 15))
        line((9, 10), (8, 7.5))
        line((14, 10), (15.2, 6.5), (17.2, 7))
        circle(14.8, 3.2, 1.2)
        switch kind {
        case .road:
            break
        case .bike, .mountain, .gravel:
            line((20.5, 2.5), (20.5, 5.5))
            line((19, 4), (22, 4))
        }
        if kind == .mountain {
            // Waves under the wheels.
            path.move(to: p(3, 20))
            for step in 0..<6 {
                let x = 3 + Double(step) * 3
                path.addQuadCurve(to: p(x + 3, 20), control: p(x + 1.5, step.isMultiple(of: 2) ? 18.5 : 21.5))
            }
        }
        if kind == .gravel {
            // Dots: gravel.
            for step in 0..<6 {
                let x = 4 + Double(step) * 3
                path.addEllipse(in: CGRect(x: origin.x + (x - 0.25) * s, y: origin.y + 20.25 * s, width: 0.5 * s, height: 0.5 * s))
            }
        }
        return path
    }
}

/// The "E-Bike" symbol: speed lines and a bolt.
struct EbikeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + x * s, y: origin.y + y * s) }
        for (x1, x2, y) in [(2.0, 6.0, 9.0), (1.0, 5.0, 13.0), (3.0, 7.0, 17.0)] {
            path.move(to: p(x1, y))
            path.addLine(to: p(x2, y))
        }
        path.move(to: p(16, 3))
        for point in [(11.0, 11.0), (15.0, 11.0), (13.0, 19.0), (20.0, 9.0), (16.0, 9.0), (18.0, 3.0)] {
            path.addLine(to: p(point.0, point.1))
        }
        path.closeSubpath()
        return path
    }
}

/// A symbol of a bike kind in a stroke of the right weight for its size.
struct BikeKindIcon: View {
    let kind: BikeKind
    var size: CGFloat = 18

    var body: some View {
        BikeKindShape(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: max(1.1, size / 16), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
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

    var body: some View {
        BikeKindIcon(kind: kind, size: size * 0.62)
            .foregroundStyle(onAccent ? Color.white : color.color)
            .frame(width: size, height: size)
            .background(onAccent ? Color.white.opacity(0.24) : color.color.opacity(0.14), in: Circle())
            .accessibilityHidden(accessibilityName == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityName.map { Text("Bike: \($0)") } ?? Text(verbatim: ""))
    }
}

extension Bike {
    var chip: BikeChip { BikeChip(kind: kind, color: color) }

    /// "Gravel bike · Bosch Performance Line SX · 400 Wh", without the parts that are empty.
    var subtitle: String {
        [kind.title, driveUnit.nonEmpty, batteryWh.map { "\($0) Wh" }]
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
                            .foregroundStyle(.white)
                            .opacity(selected ? 1 : 0)
                            .frame(width: 32, height: 32)
                            .background(color.color, in: Circle())
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
