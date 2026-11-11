import CoreGraphics
import MapKit
import WattspurCore

/// A short black line across the route where two parts of a merged ride meet (B-131).
public struct JoinTick: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    /// Degrees clockwise from north: the direction of travel, so the line can be drawn across it.
    public var heading: Double

    public init(coordinate: CLLocationCoordinate2D, heading: Double) {
        self.coordinate = coordinate
        self.heading = heading
    }

    public static func == (a: JoinTick, b: JoinTick) -> Bool {
        a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude && a.heading == b.heading
    }

    /// One per end: a single one where the parts meet, two across a gap.
    public static func ticks(of joins: [RideMerge.Join]) -> [JoinTick] {
        joins.flatMap(\.ends).map {
            JoinTick(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), heading: $0.heading)
        }
    }

    /// The unit vector across the direction of travel, in map or image coordinates where
    /// north is up and y grows downwards.
    public var across: (dx: Double, dy: Double) {
        let radians = heading * .pi / 180
        return (cos(radians), sin(radians))
    }
}

/// How the route of one ride is coloured: in one colour, or in pieces by curve (B-181), lean angle
/// (B-247), road surface (B-248) or height (B-063). Only one at a time; `pieces(dark:colors:)`
/// resolves the colours.
public enum RouteColouring: Sendable {
    case plain
    case curves([CurvatureAnalyzer.Piece])
    case lean([RideMotion.LeanStretch])
    case surface([RideMotion.SurfaceStretch])
    case elevation([RouteElevation.Stretch])

    /// The first colouring that has pieces, in the order the ride's map offers them; plain without any.
    public static func first(curves: [CurvatureAnalyzer.Piece], lean: [RideMotion.LeanStretch],
                             surface: [RideMotion.SurfaceStretch], elevation: [RouteElevation.Stretch]) -> RouteColouring {
        if !curves.isEmpty { return .curves(curves) }
        if !lean.isEmpty { return .lean(lean) }
        if !surface.isEmpty { return .surface(surface) }
        if !elevation.isEmpty { return .elevation(elevation) }
        return .plain
    }

    /// A short key that changes when the drawing changes, so a map knows when to replace the overlay.
    public var key: String {
        switch self {
        case .plain: "plain"
        case .curves(let pieces): "curves|\(pieces.count)|\(pieces.first?.points.count ?? 0)"
        case .lean(let stretches): "lean|\(stretches.count)|\(stretches.first?.latitude.count ?? 0)"
        case .surface(let stretches): "surface|\(stretches.count)|\(stretches.first?.latitude.count ?? 0)"
        case .elevation(let stretches): "elevation|\(stretches.count)|\(stretches.first?.latitude.count ?? 0)"
        }
    }

    /// The coloured pieces with their coordinates; empty for `plain`.
    public func pieces(dark: Bool, colors: RouteColors) -> [(color: CGColor, coordinates: [CLLocationCoordinate2D])] {
        func coordinates(_ latitude: [Double], _ longitude: [Double]) -> [CLLocationCoordinate2D] {
            zip(latitude, longitude).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
        }
        switch self {
        case .plain:
            return []
        case .curves(let pieces):
            return pieces.map { piece in
                (MapPalette.curve(piece.kind).cgColor(dark: dark),
                 piece.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
            }
        case .lean(let stretches):
            return stretches.map { (MapPalette.lean($0.band).cgColor(dark: dark), coordinates($0.latitude, $0.longitude)) }
        case .surface(let stretches):
            return stretches.map { (MapPalette.surface($0.band).cgColor(dark: dark), coordinates($0.latitude, $0.longitude)) }
        case .elevation(let stretches):
            return stretches.map { stretch in
                (stretch.band.map { MapPalette.cgColor(MapPalette.elevation($0)) } ?? colors.noHeight,
                 coordinates(stretch.latitude, stretch.longitude))
            }
        }
    }
}

/// The route of one ride and its new stretches in map coordinates, with the colours resolved
/// for the appearance, so the renderer can draw from any thread.
public final class RideRouteOverlay: NSObject, MKOverlay, @unchecked Sendable {
    /// One line per recording, so a merged ride keeps the gap between its parts.
    let route: [[MKMapPoint]]
    let stretches: [[MKMapPoint]]
    /// The coloured pieces of the route; empty draws it in `routeColor`.
    let pieces: [(color: CGColor, points: [MKMapPoint])]
    let ticks: [(point: MKMapPoint, across: (dx: Double, dy: Double))]
    let routeColor: CGColor
    let newColor: CGColor
    public let boundingMapRect: MKMapRect
    public var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }

    /// - Parameter newStretches: stretches no earlier ride had passed (B-115), drawn on top in orange.
    /// - Parameter ticks: where the parts of a merged ride meet (B-131).
    public convenience init(route: [CLLocationCoordinate2D], newStretches: [[RoutePoint]], colouring: RouteColouring,
                            ticks: [JoinTick], dark: Bool, colors: RouteColors) {
        self.init(segments: [route], newStretches: newStretches, colouring: colouring, ticks: ticks, dark: dark, colors: colors)
    }

    /// The route as one line per recording (the iPhone's `RideExchange.Route`).
    public init(segments: [[CLLocationCoordinate2D]], newStretches: [[RoutePoint]] = [], colouring: RouteColouring,
                ticks: [JoinTick] = [], dark: Bool, colors: RouteColors) {
        // No line across a gap in the track, e.g. a train ride without recording (B-309).
        route = segments.flatMap(TrackGap.split).map { $0.map(MKMapPoint.init) }
        stretches = newStretches.map { $0.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) } }
        self.ticks = ticks.map { (MKMapPoint($0.coordinate), $0.across) }
        pieces = colouring.pieces(dark: dark, colors: colors).flatMap { piece in
            TrackGap.split(piece.coordinates).map { (piece.color, $0.map(MKMapPoint.init)) }
        }
        routeColor = colors.accent
        newColor = MapPalette.newPaths.cgColor(dark: dark)
        let rect = MKMapRect(covering: Array(route.joined()) + Array(stretches.joined()))
        // Margin for the width of the lines at the edges.
        boundingMapRect = rect.isNull ? .world : rect.insetBy(dx: -rect.width * 0.05 - 500, dy: -rect.height * 0.05 - 500)
    }
}

/// Draws, in this order: the route's white outline and accent line, then the new
/// stretches' white outline and orange line, so the new stretches are always on top,
/// and last the black ticks where the parts of a merged ride meet.
public final class RideRouteRenderer: MKOverlayRenderer {
    override public func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? RideRouteOverlay else { return }
        let scale = 1 / zoomScale
        context.setLineCap(.round)
        context.setLineJoin(.round)
        func stroke(_ points: [MKMapPoint], width: CGFloat, color: CGColor) {
            guard points.count > 1 else { return }
            context.beginPath()
            context.move(to: point(for: points[0]))
            for p in points.dropFirst() { context.addLine(to: point(for: p)) }
            context.setLineWidth(width * scale)
            context.setStrokeColor(color)
            context.strokePath()
        }
        let white = CGColor(gray: 1, alpha: 1)
        // Both lines are equally wide, so neither looks heavier at any zoom; the new stretches
        // stand out by colour and by lying on top.
        for line in overlay.route { stroke(line, width: 8, color: white) }
        if overlay.pieces.isEmpty {
            for line in overlay.route { stroke(line, width: 4.5, color: overlay.routeColor) }
        } else {
            // Round caps make the pieces join without a gap.
            for piece in overlay.pieces { stroke(piece.points, width: 4.5, color: piece.color) }
        }
        for stretch in overlay.stretches { stroke(stretch, width: 8, color: white) }
        for stretch in overlay.stretches { stroke(stretch, width: 4.5, color: overlay.newColor) }
        // A tick reaches a few points beyond the line on both sides.
        let half = 12 * scale
        context.setLineCap(.butt)
        for tick in overlay.ticks {
            let from = point(for: MKMapPoint(x: tick.point.x - tick.across.dx * half, y: tick.point.y - tick.across.dy * half))
            let to = point(for: MKMapPoint(x: tick.point.x + tick.across.dx * half, y: tick.point.y + tick.across.dy * half))
            for (width, color) in [(4.5, white), (2.5, CGColor(gray: 0, alpha: 1))] as [(CGFloat, CGColor)] {
                context.beginPath()
                context.move(to: from)
                context.addLine(to: to)
                context.setLineWidth(width * scale)
                context.setStrokeColor(color)
                context.strokePath()
            }
        }
    }
}

// MARK: - Markers and the cursor

/// Start, finish, or both in one for a loop. The app gives the title (rule 8) and makes the
/// image from `RouteMarkerImage`.
public final class RideMarker: NSObject, MKAnnotation {
    public enum Kind: Sendable {
        case start, finish, loop
    }

    public let coordinate: CLLocationCoordinate2D
    public let kind: Kind
    public let title: String?

    public init(coordinate: CLLocationCoordinate2D, kind: Kind, title: String?) {
        self.coordinate = coordinate
        self.kind = kind
        self.title = title
    }

    /// Start and finish closer than 100 m count as one point (a loop).
    public static func isLoop(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard let first = coordinates.first, let last = coordinates.last else { return false }
        return CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude)) < 100
    }
}

/// The spot shared with the charts (B-062): a white dot with a dark ring.
public final class CursorAnnotation: NSObject, MKAnnotation {
    @objc public dynamic var coordinate: CLLocationCoordinate2D

    public init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

/// The images of the markers, drawn with Core Graphics at `scale` pixels per point, so each app
/// only wraps them in its image type. Origin bottom left, as in the drawing before.
public enum RouteMarkerImage {
    /// The cursor: a 12 pt white dot with a 2 pt black ring, in 18 × 18 pt.
    public static func cursor(scale: CGFloat = 2) -> CGImage? {
        draw(size: 18, scale: scale) { context in
            let dot = CGRect(x: 3, y: 3, width: 12, height: 12)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fillEllipse(in: dot.insetBy(dx: -2, dy: -2))
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fillEllipse(in: dot)
        }
    }

    /// Start or finish: a 14 pt dot in `color` with a white ring and a light shadow, in 22 × 22 pt.
    public static func marker(color: CGColor, scale: CGFloat = 2) -> CGImage? {
        draw(size: 22, scale: scale) { context in
            let dot = CGRect(x: 4, y: 4, width: 14, height: 14)
            context.saveGState()
            // The blur is in pixels, not affected by the scale: 2 pt as before.
            context.setShadow(offset: .zero, blur: 2 * scale, color: CGColor(gray: 0, alpha: 0.33))
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fillEllipse(in: dot.insetBy(dx: -1.5, dy: -1.5))
            context.restoreGState()
            context.setFillColor(color)
            context.fillEllipse(in: dot.insetBy(dx: 1.5, dy: 1.5))
        }
    }

    private static func draw(size: CGFloat, scale: CGFloat, _ body: (CGContext) -> Void) -> CGImage? {
        let pixels = Int((size * scale).rounded())
        guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        body(context)
        return context.makeImage()
    }
}
