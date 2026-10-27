import AppKit
import MapKit
import SwiftUI
import WattspurKit

/// How the map of all rides draws its routes (B-107, MAP-04a), shared by the live
/// map and the PDF so both look the same.
///
/// Like komoot's heat map: every ride is a thin, translucent line, so where many
/// rides overlap the line gets stronger. A second, wide and very faint stroke per
/// ride adds up to a broad band on often ridden roads, so they also get wider.
/// Selected rides (1 to 4) are drawn instead in the comparison's colours and dashes.
///
/// As a heat map (B-108, MAP-04b) it fills grid cells of about 16 pt instead, in
/// fixed steps by the number of different rides per cell.
struct RidesMapStyle: Sendable {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case lines, heat
        var id: Self { self }
    }

    /// One ride in map coordinates, ready to draw from any thread.
    struct Line: Sendable {
        var segments: [[MKMapPoint]]
        var rect: MKMapRect
        /// `nil`: part of the heat lines; else the comparison style of a selected ride.
        var highlight: Highlight?
    }

    struct Highlight: Sendable {
        var color: CGColor
        var dash: [CGFloat]
    }

    var lines: [Line]
    var mode: Mode
    /// 1, or less while a ride picked in the popover stands out (B-109).
    var fade: CGFloat
    /// The rides of the heat map, without the highlighted ones (they are drawn on top).
    var heatRides: [MapRide]
    /// Magenta, resolved for the light or dark appearance (Requirements 10.11).
    var heatColor: CGColor
    var haloColor: CGColor
    /// Lines and heat map hidden with a second click in "Customize Map" (B-061): only the
    /// rides that stand out are drawn, so a ride selected in the list still shows.
    var onlyHighlights = false

    static let thinWidth: CGFloat = 1.6
    static let thinAlpha: CGFloat = 0.32
    static let bandWidth: CGFloat = 7
    static let bandAlpha: CGFloat = 0.035

    /// - Parameter selected: rides selected in the list beside the map (B-123), drawn
    ///   on top in the accent colour.
    /// - Parameter focused: the ride picked in the map's popover (B-109): drawn on top in
    ///   the accent colour while everything else fades.
    init(rides: [MapRide], highlighted: [UUID], selected: Set<UUID> = [], focused: UUID? = nil,
         mode: Mode = .lines, dark: Bool) {
        self.mode = mode
        fade = focused == nil ? 1 : 0.35
        let selected = focused.map { selected.union([$0]) } ?? selected
        heatRides = rides.filter { !highlighted.contains($0.id) && !selected.contains($0.id) }
        heatColor = dark ? CGColor(srgbRed: 1, green: 0.31, blue: 0.68, alpha: 1)
                         : CGColor(srgbRed: 0.76, green: 0.09, blue: 0.48, alpha: 1)
        haloColor = dark ? CGColor(gray: 0.1, alpha: 1) : CGColor(gray: 1, alpha: 1)
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        lines = rides.map { ride in
            let segments = ride.route.segments.map { $0.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) } }
            let rect = segments.joined().reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
            var highlight: Highlight?
            if let index = highlighted.firstIndex(of: ride.id) {
                var color = CGColor(gray: 0, alpha: 1)
                appearance?.performAsCurrentDrawingAppearance { color = NSColor(ComparisonStyle.color(index)).cgColor }
                highlight = Highlight(color: color, dash: ComparisonStyle.dash(index))
            } else if selected.contains(ride.id) {
                var color = CGColor(gray: 0, alpha: 1)
                appearance?.performAsCurrentDrawingAppearance { color = NSColor.controlAccentColor.cgColor }
                highlight = Highlight(color: color, dash: [])
            }
            return Line(segments: segments, rect: rect, highlight: highlight)
        }
    }

    /// The same style, drawing only the rides that stand out when `only` is true.
    func onlyHighlights(_ only: Bool) -> RidesMapStyle {
        var style = self
        style.onlyHighlights = only
        return style
    }

    var boundingRect: MKMapRect { lines.reduce(MKMapRect.null) { $0.union($1.rect) } }

    /// Draws everything that touches `area`. `point` converts into the context's
    /// coordinates, `scale` is how many context units one screen point is.
    /// `mapPointsPerPoint` is how many MapKit map points one screen point covers;
    /// it sets the size of the heat map's cells.
    func draw(in context: CGContext, area: MKMapRect, scale: CGFloat, mapPointsPerPoint: Double,
              point: (MKMapPoint) -> CGPoint) {
        if mode == .heat && !onlyHighlights {
            drawHeat(in: context, area: area, mapPointsPerPoint: mapPointsPerPoint, point: point)
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        // The margin keeps lines whose stroke reaches into the area from just outside.
        let margin = Double(Self.bandWidth * scale)
        let visible = area.insetBy(dx: -margin, dy: -margin)
        func stroke(_ line: Line, width: CGFloat, color: CGColor, dash: [CGFloat] = []) {
            for segment in line.segments where !segment.isEmpty {
                context.beginPath()
                context.move(to: point(segment[0]))
                // A ride without movement still shows as a dot.
                if segment.count == 1 { context.addLine(to: point(segment[0])) }
                for p in segment.dropFirst() { context.addLine(to: point(p)) }
                context.setLineWidth(width * scale)
                context.setLineDash(phase: 0, lengths: dash.map { $0 * scale })
                context.setStrokeColor(color)
                context.strokePath()
            }
        }
        let shown = lines.filter { $0.rect.intersects(visible) }
        if mode == .lines && !onlyHighlights {
            for line in shown where line.highlight == nil {
                stroke(line, width: Self.bandWidth, color: heatColor.copy(alpha: Self.bandAlpha * fade) ?? heatColor)
            }
            for line in shown where line.highlight == nil {
                stroke(line, width: Self.thinWidth, color: heatColor.copy(alpha: Self.thinAlpha * fade) ?? heatColor)
            }
        }
        for line in shown {
            guard let highlight = line.highlight else { continue }
            stroke(line, width: 6, color: haloColor)
            stroke(line, width: 3.5, color: highlight.color, dash: highlight.dash)
        }
    }

    /// The fixed steps of the heat map: blue → turquoise → yellow → orange → red.
    static let stepColors: [DensityStep: CGColor] = [
        .one: CGColor(srgbRed: 0.18, green: 0.42, blue: 1, alpha: 1),
        .few: CGColor(srgbRed: 0.13, green: 0.76, blue: 0.76, alpha: 1),
        .some: CGColor(srgbRed: 0.96, green: 0.83, blue: 0.23, alpha: 1),
        .many: CGColor(srgbRed: 0.95, green: 0.55, blue: 0.16, alpha: 1),
        .most: CGColor(srgbRed: 0.9, green: 0.2, blue: 0.18, alpha: 1),
    ]
    static let heatAlpha: CGFloat = 0.72

    /// Cells of about 16 pt, each a soft dot in the colour of its step.
    private func drawHeat(in context: CGContext, area: MKMapRect, mapPointsPerPoint: Double,
                          point: (MKMapPoint) -> CGPoint) {
        let world = MKMapSize.world.width
        let size = RouteDensity.cellSize(unitsPerPoint: mapPointsPerPoint / world)
        guard size > 0 else { return }
        let margin = size * world
        let density = RouteDensity(rides: heatRides, cellSize: size,
                                   area: GeoBounds(area.insetBy(dx: -margin, dy: -margin)))
        for (cell, count) in density.counts {
            let origin = density.origin(of: cell)
            let topLeft = point(MKMapPoint(x: origin.x * world, y: origin.y * world))
            let bottomRight = point(MKMapPoint(x: (origin.x + size) * world, y: (origin.y + size) * world))
            let rect = CGRect(x: min(topLeft.x, bottomRight.x), y: min(topLeft.y, bottomRight.y),
                              width: abs(bottomRight.x - topLeft.x), height: abs(bottomRight.y - topLeft.y))
            let color = Self.stepColors[DensityStep(count: count)] ?? heatColor
            // A soft dot reaching into the neighbours: full colour in the middle of the
            // cell, fading out beyond its edge, so cells blend into areas without steps.
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let colors = [color.copy(alpha: Self.heatAlpha * fade) ?? color, color.copy(alpha: Self.heatAlpha * 0.8 * fade) ?? color,
                          color.copy(alpha: 0) ?? color] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors,
                                            locations: [0, 0.55, 1]) else { continue }
            context.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre,
                                       endRadius: rect.width * 1.1, options: [])
        }
    }

    /// What `n` overlapping rides look like, for the legend: opacity of the thin
    /// line and of the band after `n` translucent strokes on top of each other.
    static func legendOpacity(rides n: Int) -> (thin: Double, band: Double) {
        (1 - pow(1 - Double(thinAlpha), Double(n)), 1 - pow(1 - Double(bandAlpha), Double(n)))
    }
}

/// The overlay MapKit asks to draw; it covers all routes.
final class RidesMapOverlay: NSObject, MKOverlay {
    let style: RidesMapStyle
    let boundingMapRect: MKMapRect
    var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }

    init(style: RidesMapStyle) {
        self.style = style
        let rect = style.boundingRect
        // Generous margin for the wide band at the edges.
        boundingMapRect = rect.isNull ? MKMapRect.world : rect.insetBy(dx: -rect.width * 0.05 - 2_000, dy: -rect.height * 0.05 - 2_000)
    }
}

/// Draws the overlay tile by tile; MapKit calls this on background threads, so
/// the style holds only values.
final class RidesMapRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? RidesMapOverlay else { return }
        overlay.style.draw(in: context, area: mapRect, scale: 1 / zoomScale, mapPointsPerPoint: 1 / zoomScale) {
            self.point(for: $0)
        }
    }
}

/// The map of all rides: an `MKMapView`, because SwiftUI's `Map` cannot draw a
/// custom overlay; one overlay for all rides keeps 1 000 rides smooth.
struct RidesMapRepresentable: NSViewRepresentable {
    let style: RidesMapStyle
    /// Changes whenever the drawing changes (rides, selection, appearance); only
    /// then the overlay is replaced, so panning does not redraw every tile.
    let styleKey: String
    let mapType: RideMapType
    /// Changes when the shown rides change; the map then fits them again.
    let fitKey: [UUID]
    let onVisibleAreaChange: (MKMapRect) -> Void
    /// Set from outside to show all rides again.
    @Binding var fitRequest: Int
    /// The area shown before the section was left; used instead of fitting when
    /// the map comes back with the same rides.
    var restoredArea: MKMapRect?
    /// A click on the map (B-109): the coordinate, 10 pt in metres at the current
    /// zoom, and the point in the view (origin top left).
    var onClick: (CLLocationCoordinate2D, Double, CGPoint) -> Void = { _, _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onVisibleAreaChange: onVisibleAreaChange) }

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsZoomControls = true
        map.showsCompass = true
        map.showsScale = true
        map.pointOfInterestFilter = .excludingAll
        map.addGestureRecognizer(NSClickGestureRecognizer(target: context.coordinator,
                                                          action: #selector(Coordinator.clicked(_:))))
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        context.coordinator.onVisibleAreaChange = onVisibleAreaChange
        context.coordinator.onClick = onClick
        if context.coordinator.mapType != mapType {
            context.coordinator.mapType = mapType
            map.show(mapType, muted: true)
        }
        if context.coordinator.styleKey != styleKey {
            context.coordinator.styleKey = styleKey
            map.removeOverlays(map.drawnOverlays)
            map.addOverlay(RidesMapOverlay(style: style), level: map.drawnOverlayLevel)
        }
        if context.coordinator.fitKey != fitKey || context.coordinator.fitRequest != fitRequest {
            let firstTime = context.coordinator.fitKey == nil
            context.coordinator.fitKey = fitKey
            context.coordinator.fitRequest = fitRequest
            if firstTime, let restoredArea {
                Self.fit(map, to: restoredArea, padding: 0, report: onVisibleAreaChange)
            } else {
                Self.fit(map, to: style.boundingRect, report: onVisibleAreaChange)
            }
        }
    }

    /// Shows all routes. Waits until the map has its size: fitted while it is still
    /// zero by zero, it would end up somewhere near the routes but not around them.
    /// Runs after the view update, because reporting the area changes SwiftUI state.
    private static func fit(_ map: MKMapView, to rect: MKMapRect, padding: CGFloat = 40,
                            report: @escaping (MKMapRect) -> Void, attempt: Int = 0) {
        DispatchQueue.main.async {
            if map.bounds.width < 10 || map.bounds.height < 10, attempt < 20 {
                fit(map, to: rect, padding: padding, report: report, attempt: attempt + 1)
                return
            }
            if !rect.isNull {
                let inset = NSEdgeInsets(top: padding * 1.25, left: padding, bottom: padding, right: padding)
                map.setVisibleMapRect(rect, edgePadding: inset, animated: false)
            }
            report(map.visibleMapRect)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onVisibleAreaChange: (MKMapRect) -> Void
        var onClick: (CLLocationCoordinate2D, Double, CGPoint) -> Void = { _, _, _ in }
        var mapType: RideMapType?
        var styleKey: String?
        var fitKey: [UUID]?
        var fitRequest: Int?

        init(onVisibleAreaChange: @escaping (MKMapRect) -> Void) {
            self.onVisibleAreaChange = onVisibleAreaChange
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay { return MutedTileRenderer(tileOverlay: tiles) }
            return overlay is RidesMapOverlay ? RidesMapRenderer(overlay: overlay) : MKOverlayRenderer(overlay: overlay)
        }

        /// The click radius is 10 pt on screen, so it feels the same at every zoom
        /// (Requirements 10.11); MapKit's own controls keep their clicks.
        @objc func clicked(_ recognizer: NSClickGestureRecognizer) {
            guard let map = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            let beside = map.convert(CGPoint(x: point.x + 10, y: point.y), toCoordinateFrom: map)
            let radius = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: beside.latitude, longitude: beside.longitude))
            let topLeft = CGPoint(x: point.x, y: map.isFlipped ? point.y : map.bounds.height - point.y)
            onClick(coordinate, radius, topLeft)
        }

        /// Tiles below the map update once panning or zooming ends (B-114).
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onVisibleAreaChange(mapView.visibleMapRect)
        }
    }
}

extension GeoBounds {
    /// The geographic rectangle of a visible map area.
    init(_ rect: MKMapRect) {
        let northWest = MKMapPoint(x: rect.minX, y: rect.minY).coordinate
        let southEast = MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate
        self.init(minLatitude: southEast.latitude, maxLatitude: northWest.latitude,
                  minLongitude: northWest.longitude, maxLongitude: southEast.longitude)
    }
}
