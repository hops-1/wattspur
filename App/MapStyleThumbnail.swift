import SwiftUI

/// A small drawn picture of a map style for the "Customize Map" window (B-061), after komoot:
/// always the same scene (a park, a river, a main road and a path) in the colours of the style,
/// so the pictures differ only where the styles do. Drawn, not taken from real maps, so they are
/// sharp at any size and need no network and no licence (decided by Nils, 27.10.2026).
struct MapStyleThumbnail: View {
    enum Kind: Hashable {
        case map(RideMapType)
        case display(RidesMapStyle.Mode)
    }

    let kind: Kind
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    // MARK: The scene, in a unit square

    private func river(_ s: CGSize) -> Path {
        Path {
            $0.move(to: p(-0.05, 0.12, s))
            $0.addCurve(to: p(1.05, 0.78, s), control1: p(0.45, 0.15, s), control2: p(0.45, 0.8, s))
        }
    }

    private func mainRoad(_ s: CGSize) -> Path {
        Path {
            $0.move(to: p(0.28, 1.05, s))
            $0.addQuadCurve(to: p(1.05, 0.32, s), control: p(0.42, 0.38, s))
        }
    }

    private func path(_ s: CGSize) -> Path {
        Path {
            $0.move(to: p(0.08, 1.05, s))
            $0.addLine(to: p(0.9, -0.05, s))
        }
    }

    private func park(_ s: CGSize) -> Path {
        Path {
            $0.move(to: p(0, 0.35, s))
            $0.addQuadCurve(to: p(0.5, 0, s), control: p(0.3, 0.3, s))
            $0.addLine(to: p(0, 0, s))
            $0.closeSubpath()
        }
    }

    private func p(_ x: Double, _ y: Double, _ s: CGSize) -> CGPoint { CGPoint(x: x * s.width, y: y * s.height) }

    // MARK: Styles

    private struct Palette {
        var ground: Color
        var park: Color
        var water: Color
        var roadCasing: Color
        var road: Color
        var path: Color
        var dashedPath = false
    }

    private var dark: Bool { colorScheme == .dark }

    private func palette(_ type: RideMapType) -> Palette {
        switch type {
        case .standard:
            dark ? Palette(ground: Color(white: 0.2), park: Color(red: 0.18, green: 0.27, blue: 0.2), water: Color(red: 0.2, green: 0.3, blue: 0.42),
                           roadCasing: Color(white: 0.35), road: Color(white: 0.45), path: Color(white: 0.38))
                : Palette(ground: Color(red: 0.96, green: 0.95, blue: 0.93), park: Color(red: 0.82, green: 0.91, blue: 0.78),
                          water: Color(red: 0.62, green: 0.8, blue: 0.95), roadCasing: Color(white: 0.78), road: .white, path: Color(white: 0.85))
        case .openStreetMap:
            Palette(ground: Color(red: 0.95, green: 0.94, blue: 0.91), park: Color(red: 0.8, green: 0.92, blue: 0.69),
                    water: Color(red: 0.67, green: 0.83, blue: 0.87), roadCasing: Color(red: 0.75, green: 0.5, blue: 0.55),
                    road: Color(red: 0.99, green: 0.84, blue: 0.64), path: Color(red: 0.98, green: 0.5, blue: 0.45), dashedPath: true)
        case .cyclOSM:
            Palette(ground: Color(red: 0.95, green: 0.94, blue: 0.92), park: Color(red: 0.8, green: 0.9, blue: 0.72),
                    water: Color(red: 0.67, green: 0.83, blue: 0.87), roadCasing: Color(white: 0.7), road: .white,
                    path: Color(red: 0.1, green: 0.3, blue: 0.95))
        case .openTopoMap:
            Palette(ground: Color(red: 0.93, green: 0.92, blue: 0.86), park: Color(red: 0.75, green: 0.86, blue: 0.66),
                    water: Color(red: 0.55, green: 0.75, blue: 0.9), roadCasing: Color(red: 0.6, green: 0.45, blue: 0.3),
                    road: Color(red: 0.98, green: 0.83, blue: 0.5), path: Color(red: 0.45, green: 0.35, blue: 0.25), dashedPath: true)
        case .satellite, .hybrid:
            Palette(ground: Color(red: 0.2, green: 0.3, blue: 0.16), park: Color(red: 0.13, green: 0.24, blue: 0.11),
                    water: Color(red: 0.12, green: 0.2, blue: 0.22), roadCasing: Color(red: 0.6, green: 0.5, blue: 0.2),
                    road: Color(red: 0.98, green: 0.85, blue: 0.4), path: Color(white: 0.9))
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        switch kind {
        case .map(let type):
            drawMap(type, in: &context, size: size)
        case .display(let mode):
            drawMap(.standard, in: &context, size: size, muted: true)
            if mode == .lines {
                // Thin lines for rare rides, a wide strong band where many ride.
                let magenta = dark ? Color(red: 1, green: 0.31, blue: 0.68) : Color(red: 0.76, green: 0.09, blue: 0.48)
                context.stroke(path(size), with: .color(magenta.opacity(0.35)), lineWidth: size.width * 0.03)
                context.stroke(river(size).offsetBy(dx: 0, dy: size.height * 0.12), with: .color(magenta.opacity(0.5)), lineWidth: size.width * 0.05)
                context.stroke(mainRoad(size), with: .color(magenta.opacity(0.9)), lineWidth: size.width * 0.11)
            } else {
                var heat = context
                heat.addFilter(.blur(radius: size.width * 0.07))
                for (x, y, r, color) in [(0.62, 0.62, 0.34, Color.blue), (0.66, 0.58, 0.22, Color.yellow),
                                         (0.7, 0.55, 0.12, Color.red), (0.2, 0.85, 0.16, Color.cyan)] {
                    heat.fill(Path(ellipseIn: CGRect(x: (x - r) * size.width, y: (y - r) * size.height,
                                                     width: 2 * r * size.width, height: 2 * r * size.height)),
                              with: .color(color.opacity(0.7)))
                }
            }
        }
        context.stroke(Path(rect), with: .color(.black.opacity(0.08)), lineWidth: 1)
    }

    private func drawMap(_ type: RideMapType, in context: inout GraphicsContext, size: CGSize, muted: Bool = false) {
        let colors = palette(type)
        let w = size.width
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colors.ground))
        if type == .satellite || type == .hybrid {
            // Fields of different greens and browns.
            let fields: [(Double, Double, Double, Double, Color)] = [
                (0.0, 0.45, 0.4, 0.3, Color(red: 0.32, green: 0.38, blue: 0.2)), (0.55, 0.0, 0.45, 0.35, Color(red: 0.36, green: 0.33, blue: 0.22)),
                (0.45, 0.6, 0.55, 0.4, Color(red: 0.25, green: 0.36, blue: 0.18)), (0.05, 0.78, 0.3, 0.22, Color(red: 0.42, green: 0.4, blue: 0.28)),
            ]
            for (x, y, fw, fh, color) in fields {
                context.fill(Path(CGRect(x: x * w, y: y * size.height, width: fw * w, height: fh * size.height)), with: .color(color))
            }
        }
        context.fill(park(size), with: .color(colors.park))
        if type == .openTopoMap {
            // Hill shading towards the south-east and brown contour lines around a hill.
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.22)]),
                                               startPoint: p(0.3, 0.3, size), endPoint: p(1, 1, size)))
            for radius in [0.12, 0.22, 0.32, 0.42] {
                context.stroke(Path(ellipseIn: CGRect(x: (0.78 - radius) * w, y: (0.82 - radius * 0.8) * size.height,
                                                      width: 2 * radius * w, height: 1.6 * radius * size.height)),
                               with: .color(Color(red: 0.7, green: 0.5, blue: 0.3).opacity(0.75)), lineWidth: max(0.7, w * 0.012))
            }
        }
        context.stroke(river(size), with: .color(colors.water), lineWidth: w * 0.07)
        if type != .satellite {
            context.stroke(mainRoad(size), with: .color(colors.roadCasing), lineWidth: w * 0.13)
            context.stroke(mainRoad(size), with: .color(colors.road), lineWidth: w * 0.09)
            let style = StrokeStyle(lineWidth: w * (colors.dashedPath ? 0.035 : 0.05), lineCap: .butt,
                                    dash: colors.dashedPath ? [w * 0.07, w * 0.04] : [])
            context.stroke(path(size), with: .color(colors.path), style: style)
            if type == .cyclOSM {
                // A red cycle lane along the main road.
                context.stroke(mainRoad(size), with: .color(Color(red: 0.9, green: 0.2, blue: 0.2)),
                               style: StrokeStyle(lineWidth: w * 0.025, dash: [w * 0.06, w * 0.03]))
            }
        }
        if muted {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color((dark ? Color.black : .white).opacity(0.25)))
        }
    }
}
