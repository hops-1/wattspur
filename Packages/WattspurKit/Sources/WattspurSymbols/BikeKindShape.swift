import SwiftUI
import WattspurCore

// The drawn symbols of the device kinds and the e-bike mark, the same on the Mac, the iPhone and the
// iPad (B-342; first drawn for the Mac, B-133, B-201, B-284, B-330). Shapes only: no texts, no
// AppKit or UIKit, so the widgets can draw them too.

/// The symbol of a bike kind, drawn like komoot's: a rider on a bike, with sparkles
/// for the bicycle, waves for the mountain bike and dots for the gravel bike.
/// Drawn in a 24 × 24 box and scaled to the frame; stroke it, do not fill it.
public struct BikeKindShape: Shape {
    public let kind: BikeKind

    public init(kind: BikeKind) {
        self.kind = kind
    }

    public func path(in rect: CGRect) -> Path {
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
        if kind == .car {
            // A low body with a cabin on top, two wheels (B-284).
            circle(7, 16, 2.2)
            circle(17, 16, 2.2)
            line((4.8, 16), (2.5, 16), (2.5, 12.5), (5.5, 11.5), (8.5, 7.5), (15.5, 7.5), (18.5, 11.5), (21.5, 12.5), (21.5, 16), (19.2, 16))
            line((9.2, 16), (14.8, 16))
            line((6.5, 11.5), (18.5, 11.5))
            line((12, 7.5), (12, 11.5))
            return path
        }
        if kind == .runningShoe {
            // A running shoe from the side: heel left, toe right, laces on top (B-284).
            line((3, 18), (3, 9), (8, 9), (10.5, 12.5), (16, 14), (20.5, 15), (21.5, 16.5), (21.5, 18), (3, 18))
            line((3, 15.5), (21.5, 15.5))
            line((8.6, 10.6), (10.6, 9.6))
            line((10.4, 12.3), (12.4, 11.3))
            return path
        }
        if kind == .motorcycle {
            // Two big wheels, the tank between rider and fork, the rider leaning forward.
            circle(5.5, 16, 3.5)
            circle(18.5, 16, 3.5)
            line((5.5, 16), (9.5, 12.5), (15, 12.5), (18.5, 16))
            line((9.5, 12.5), (11.5, 9.5), (15.5, 10), (15, 12.5))
            line((18.5, 16), (16.5, 8.5), (18.5, 7.5))
            line((9.5, 12.5), (10.5, 8), (15, 9))
            circle(11.6, 5.2, 1.3)
            return path
        }
        if kind == .scooter {
            // An e-scooter from the side: two small wheels, the deck, the stem with the handlebar
            // and the rider standing on the deck (B-330).
            circle(5, 18, 2.5)
            circle(19.5, 18, 2.5)
            line((5, 18), (7.5, 16.5), (16, 16.5))
            line((19.5, 18), (16.5, 4.5))
            line((14.5, 4.5), (18.5, 4.5))
            line((10, 16.5), (11, 11), (10.5, 7.5))
            line((10.8, 9), (16.2, 6.5))
            circle(10.2, 5, 1.3)
            return path
        }
        if kind == .cargo {
            // A long john: big rear wheel, small front wheel and the box between the
            // rider and the front wheel, the handlebar steering it from above (B-201).
            circle(5.5, 16.5, 3)
            circle(20, 17, 2.5)
            line((5.5, 16.5), (11, 16.5))
            line((5.5, 16.5), (8, 11))
            line((11, 16.5), (18, 16.5), (20, 17))
            line((11, 10.5), (18, 10.5), (18, 16.5))
            line((11, 10.5), (11, 16.5))
            line((8, 11), (8.6, 6.8), (11, 8.6), (11, 10.5))
            circle(8.8, 4.2, 1.2)
            return path
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
        case .road, .cargo, .scooter, .motorcycle, .car, .runningShoe:
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
public struct EbikeShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
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
public struct BikeKindIcon: View {
    public let kind: BikeKind
    public var size: CGFloat

    public init(kind: BikeKind, size: CGFloat = 18) {
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        BikeKindShape(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: max(1.4, size / 16), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
