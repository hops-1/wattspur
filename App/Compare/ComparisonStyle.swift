import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Ride identity: colour, dash and shape (NFR-16)

/// Each column has a colour, a dash pattern and a marker shape, so rides stay apart
/// for colour-blind readers and in black and white. Colours have at least 4.5:1
/// against the window background in both modes.
enum ComparisonStyle {
    static let colors: [Color] = [
        .adaptive(light: 0x0B6BCB, dark: 0x4DA3FF),
        .adaptive(light: 0xC2410C, dark: 0xFF8A4C),
        .adaptive(light: 0x0E7C6B, dark: 0x3CC7A6),
        .adaptive(light: 0x8E44AD, dark: 0xC38BEF),
    ]

    static func color(_ index: Int) -> Color { colors[index % colors.count] }
    /// Dashes and markers come from the Kit (`ComparisonMarks`, B-294), so the iPad uses the same.
    static func dash(_ index: Int) -> [CGFloat] { ComparisonMarks.dash(index).map { CGFloat($0) } }
    static func marker(_ index: Int) -> String { ComparisonMarks.marker(index) }
}

/// Marker and dash of a ride, as in the legend.
struct ComparisonLegendMark: View {
    let index: Int

    var body: some View {
        HStack(spacing: 2) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 5))
                p.addLine(to: CGPoint(x: 24, y: 5))
            }
            .stroke(ComparisonStyle.color(index),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: ComparisonStyle.dash(index)))
            .frame(width: 24, height: 10)
            Image(systemName: ComparisonStyle.marker(index))
                .font(.system(size: 9))
                .foregroundStyle(ComparisonStyle.color(index))
        }
        .accessibilityHidden(true)
    }
}
