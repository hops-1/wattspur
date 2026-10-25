import MapKit
import SwiftUI
import WattspurKit

/// Map type offered in the ride detail (MAP-01).
enum RideMapType: String, CaseIterable, Identifiable {
    case standard, satellite, hybrid
    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .standard: "Standard"
        case .satellite: "Satellite"
        case .hybrid: "Hybrid"
        }
    }

    var style: MapStyle {
        switch self {
        case .standard: .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
        case .satellite: .imagery(elevation: .realistic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
        }
    }
}

/// A short black line across the route where two parts of a merged ride meet (B-131).
struct JoinTick: Equatable {
    var coordinate: CLLocationCoordinate2D
    /// Degrees clockwise from north: the direction of travel, so the line can be drawn across it.
    var heading: Double

    static func == (a: JoinTick, b: JoinTick) -> Bool {
        a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude && a.heading == b.heading
    }

    /// One per end: a single one where the parts meet, two across a gap.
    static func ticks(of joins: [RideMerge.Join]) -> [JoinTick] {
        joins.flatMap(\.ends).map {
            JoinTick(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), heading: $0.heading)
        }
    }

    /// The unit vector across the direction of travel, in map or image coordinates where
    /// north is up and y grows downwards.
    var across: (dx: Double, dy: Double) {
        let radians = heading * .pi / 180
        return (cos(radians), sin(radians))
    }
}

/// Route on an Apple map with start and finish markers (B-016, TOUR-01).
struct RideMapView: View {
    let route: [RoutePoint]
    let mapType: RideMapType
    /// Where the parts of a merged ride meet (B-131).
    var joins: [RideMerge.Join] = []
    /// Stretches no earlier ride had passed (B-115), drawn wider in orange on top.
    var newStretches: [[RoutePoint]] = []

    @Environment(\.colorScheme) private var colorScheme
    /// The spot shared with the charts (B-062); not there in the PDF.
    @Environment(RideCursor.self) private var cursor: RideCursor?

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// Start and finish closer than 100 m count as one point (a loop).
    private var isLoop: Bool {
        guard let first = coordinates.first, let last = coordinates.last else { return false }
        return CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude)) < 100
    }

    var body: some View {
        RideMapRepresentable(coordinates: coordinates, newStretches: newStretches, ticks: JoinTick.ticks(of: joins), mapType: mapType,
                             isLoop: isLoop, dark: colorScheme == .dark, cursor: cursor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                if !newStretches.isEmpty {
                    NewPathsLegend().padding(.leading, 12).padding(.bottom, 40)
                }
            }
            .overlay {
                if coordinates.isEmpty {
                    ContentUnavailableView("No GPS data", systemImage: "location.slash")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(isLoop ? "Map of the route: loop with the same start and finish" : "Map of the route"))
    }
}

/// The ride's map as an `MKMapView` with one overlay that draws the route and the
/// new stretches itself (B-127). SwiftUI's `Map` stacks its polylines in the order
/// they reach MapKit, so now and then the route covered the new stretches although
/// they had arrived; drawn in one renderer, the new stretches always lie on top.
private struct RideMapRepresentable: NSViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let newStretches: [[RoutePoint]]
    let ticks: [JoinTick]
    let mapType: RideMapType
    let isLoop: Bool
    let dark: Bool
    let cursor: RideCursor?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MKMapView {
        let map = TrackingMapView()
        map.delegate = context.coordinator
        map.onMove = { [weak map, weak coordinator = context.coordinator] point in
            guard let map, let cursor = coordinator?.cursor else { return }
            let here = map.convert(point, toCoordinateFrom: map)
            // Close enough to the route: 20 points of the screen, in metres.
            let beside = map.convert(CGPoint(x: point.x + 20, y: point.y), toCoordinateFrom: map)
            let metres = CLLocation(latitude: here.latitude, longitude: here.longitude)
                .distance(from: CLLocation(latitude: beside.latitude, longitude: beside.longitude))
            cursor.hover(latitude: here.latitude, longitude: here.longitude, within: metres)
        }
        map.onExit = { [weak coordinator = context.coordinator] in coordinator?.cursor?.endHover() }
        map.addGestureRecognizer(NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:))))
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsZoomControls = true
        map.showsCompass = true
        map.showsScale = true
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.cursor = cursor
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            // Without points of interest, as before; the configuration's filter wins
            // over the map view's.
            switch mapType {
            case .standard:
                let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
                configuration.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = configuration
            case .satellite:
                map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            case .hybrid:
                let configuration = MKHybridMapConfiguration(elevationStyle: .realistic)
                configuration.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = configuration
            }
        }
        // Rebuilt whenever route, new stretches or appearance change; one overlay, so
        // there is no order between route and new stretches left to MapKit.
        let drawingKey = "\(coordinates.count)|\(coordinates.first.map { "\($0.latitude),\($0.longitude)" } ?? "")"
            + "|\(newStretches.map(\.count))|\(ticks.count)|\(ticks.first.map { "\($0.coordinate.latitude)" } ?? "")|\(dark)"
        if coordinator.drawingKey != drawingKey {
            coordinator.drawingKey = drawingKey
            map.removeOverlays(map.overlays)
            if coordinates.count > 1 {
                map.addOverlay(RideRouteOverlay(route: coordinates, newStretches: newStretches, ticks: ticks, dark: dark), level: .aboveRoads)
            }
        }
        // Markers and the visible area follow the route only, not the new stretches.
        let routeKey = "\(coordinates.count)|\(coordinates.first.map { "\($0.latitude),\($0.longitude)" } ?? "")"
        if coordinator.routeKey != routeKey {
            coordinator.routeKey = routeKey
            map.removeAnnotations(map.annotations)
            if let start = coordinates.first {
                map.addAnnotation(RideMarker(coordinate: start, kind: isLoop ? .loop : .start))
            }
            if !isLoop, coordinates.count > 1, let finish = coordinates.last {
                map.addAnnotation(RideMarker(coordinate: finish, kind: .finish))
            }
            Self.fit(map, to: coordinates)
        }
        coordinator.showCursor(cursor?.current, on: map)
    }

    /// Shows the whole route. Waits until the map has its size: fitted while it is
    /// still zero by zero, it would end up near the route but not around it.
    private static func fit(_ map: MKMapView, to coordinates: [CLLocationCoordinate2D], attempt: Int = 0) {
        DispatchQueue.main.async {
            if map.bounds.width < 10 || map.bounds.height < 10, attempt < 20 {
                fit(map, to: coordinates, attempt: attempt + 1)
                return
            }
            let rect = coordinates.reduce(MKMapRect.null) {
                $0.union(MKMapRect(origin: MKMapPoint($1), size: MKMapSize(width: 0, height: 0)))
            }
            guard !rect.isNull else { return }
            map.setVisibleMapRect(rect, edgePadding: NSEdgeInsets(top: 50, left: 40, bottom: 40, right: 40), animated: false)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var drawingKey: String?
        var routeKey: String?
        var cursor: RideCursor?
        private var cursorAnnotation: CursorAnnotation?

        /// Moves the dot that shows the spot of the coupling, or takes it off the map.
        func showCursor(_ fix: RideTrack.Fix?, on map: MKMapView) {
            guard let fix, let latitude = fix.latitude, let longitude = fix.longitude else {
                if let cursorAnnotation { map.removeAnnotation(cursorAnnotation) }
                cursorAnnotation = nil
                return
            }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if let cursorAnnotation, map.annotations.contains(where: { $0 === cursorAnnotation }) {
                cursorAnnotation.coordinate = coordinate
            } else {
                let annotation = CursorAnnotation(coordinate: coordinate)
                cursorAnnotation = annotation
                map.addAnnotation(annotation)
            }
        }

        /// A click on the map: holds the spot under the mouse or lets go of it.
        @objc func clicked(_ gesture: NSClickGestureRecognizer) {
            guard let cursor, cursor.isHeld || cursor.hover != nil else { return }
            cursor.toggleHold()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            overlay is RideRouteOverlay ? RideRouteRenderer(overlay: overlay) : MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if annotation is CursorAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
                view.image = CursorAnnotation.image
                view.displayPriority = .required
                view.zPriority = .max
                view.canShowCallout = false
                return view
            }
            guard let marker = annotation as? RideMarker else { return nil }
            let view = MKAnnotationView(annotation: marker, reuseIdentifier: nil)
            view.image = marker.kind.image
            view.displayPriority = .required
            view.toolTip = marker.title
            return view
        }
    }
}

/// A map that reports where the mouse moves, to couple it with the charts (B-062).
private final class TrackingMapView: MKMapView {
    var onMove: ((NSPoint) -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMove?(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onExit?()
    }
}

/// The spot shared with the charts: a white dot with a dark ring.
private final class CursorAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }

    static let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        let dot = NSRect(x: 3, y: 3, width: 12, height: 12)
        NSColor.black.setFill()
        NSBezierPath(ovalIn: dot.insetBy(dx: -2, dy: -2)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: dot).fill()
        return true
    }
}

/// Start, finish, or both in one for a loop.
private final class RideMarker: NSObject, MKAnnotation {
    enum Kind {
        case start, finish, loop

        var color: NSColor {
            switch self {
            case .start: .systemGreen
            case .finish: .systemRed
            case .loop: .labelColor
            }
        }

        /// A 14 pt dot with a white ring and a light shadow, as before in SwiftUI.
        var image: NSImage {
            NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
                let dot = NSRect(x: 4, y: 4, width: 14, height: 14)
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowBlurRadius = 2
                shadow.shadowColor = .black.withAlphaComponent(0.33)
                shadow.set()
                NSColor.white.setFill()
                NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
                NSGraphicsContext.restoreGraphicsState()
                color.setFill()
                NSBezierPath(ovalIn: dot.insetBy(dx: 1.5, dy: 1.5)).fill()
                return true
            }
        }
    }

    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    var title: String? {
        switch kind {
        case .start: String(localized: "Start")
        case .finish: String(localized: "Finish")
        case .loop: String(localized: "Start & finish")
        }
    }

    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
    }
}

/// The route and its new stretches in map coordinates, with the colours resolved
/// for the appearance, so the renderer can draw from any thread.
private final class RideRouteOverlay: NSObject, MKOverlay {
    let route: [MKMapPoint]
    let stretches: [[MKMapPoint]]
    let ticks: [(point: MKMapPoint, across: (dx: Double, dy: Double))]
    let routeColor: CGColor
    let newColor: CGColor
    let boundingMapRect: MKMapRect
    var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }

    init(route: [CLLocationCoordinate2D], newStretches: [[RoutePoint]], ticks: [JoinTick], dark: Bool) {
        self.route = route.map(MKMapPoint.init)
        stretches = newStretches.map { $0.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) } }
        self.ticks = ticks.map { (MKMapPoint($0.coordinate), $0.across) }
        var routeColor = CGColor(gray: 0, alpha: 1)
        var newColor = CGColor(gray: 0, alpha: 1)
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            routeColor = NSColor.controlAccentColor.cgColor
            newColor = NSColor(Color.newPaths).cgColor
        }
        self.routeColor = routeColor
        self.newColor = newColor
        let rect = (self.route + stretches.joined()).reduce(MKMapRect.null) {
            $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0)))
        }
        // Margin for the width of the lines at the edges.
        boundingMapRect = rect.isNull ? .world : rect.insetBy(dx: -rect.width * 0.05 - 500, dy: -rect.height * 0.05 - 500)
    }
}

/// Draws, in this order: the route's white outline and accent line, then the new
/// stretches' white outline and orange line, so the new stretches are always on top,
/// and last the black ticks where the parts of a merged ride meet.
private final class RideRouteRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
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
        stroke(overlay.route, width: 8, color: white)
        stroke(overlay.route, width: 4.5, color: overlay.routeColor)
        for stretch in overlay.stretches { stroke(stretch, width: 10, color: white) }
        for stretch in overlay.stretches { stroke(stretch, width: 6.5, color: overlay.newColor) }
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

/// "New – never ridden before" and "Ridden before" on the ride's map (B-115).
private struct NewPathsLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paths").font(.caption.weight(.bold))
            row(Color.newPaths, width: 6, text: "New – never ridden before")
            row(Color.accentColor, width: 3.5, text: "Ridden before")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func row(_ color: Color, width: CGFloat, text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(color).frame(width: 30, height: width).accessibilityHidden(true)
            Text(text).font(.caption)
        }
    }
}
