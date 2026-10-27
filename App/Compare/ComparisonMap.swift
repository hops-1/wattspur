import MapKit
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Map of all compared routes

/// The routes on one map, each in its column's colour and dash, with its marker at the start.
/// An `MKMapView` like the other maps, so it can show the OpenStreetMap styles too (B-061c).
struct ComparisonMap: View {
    let rides: [Ride]
    let routes: [UUID: [RoutePoint]]
    @Binding var mapType: RideMapType
    @Environment(\.colorScheme) private var colorScheme

    private var hasRoutes: Bool { rides.contains { (routes[$0.id]?.count ?? 0) > 1 } }

    var body: some View {
        ComparisonMapRepresentable(
            routes: rides.enumerated().map { index, ride in
                ComparedRoute(id: ride.id, name: ride.name, index: index,
                              coordinates: (routes[ride.id] ?? []).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
            },
            mapType: mapType, dark: colorScheme == .dark)
        .frame(height: 340)
        .tileAttribution(for: mapType)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            MapCustomizeButton(mapType: $mapType)
                .padding(12)
        }
        .overlay {
            if !hasRoutes && !routes.isEmpty {
                ContentUnavailableView("No GPS data", systemImage: "location.slash")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Map of the compared routes"))
    }
}

/// One compared ride's route with its place in the comparison (colour, dash, marker).
private struct ComparedRoute {
    var id: UUID
    var name: String
    var index: Int
    var coordinates: [CLLocationCoordinate2D]
}

private struct ComparisonMapRepresentable: NSViewRepresentable {
    let routes: [ComparedRoute]
    let mapType: RideMapType
    let dark: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
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
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType)
        }
        // Rebuilt when rides, their routes or the appearance change.
        let key = routes.map { "\($0.id)|\($0.coordinates.count)" }.joined(separator: ",") + "|\(dark)"
        guard coordinator.key != key else { return }
        // The routes are loaded after the map first appears, so fit whenever the rides that
        // have a route change, not only the rides: else the map stayed on its world overview.
        let routedIDs = routes.filter { $0.coordinates.count > 1 }.map(\.id)
        let ridesChanged = coordinator.routedIDs != routedIDs
        coordinator.key = key
        coordinator.routedIDs = routedIDs
        map.removeOverlays(map.drawnOverlays)
        map.removeAnnotations(map.annotations)
        let overlay = ComparisonRoutesOverlay(routes: routes, dark: dark)
        if !overlay.lines.isEmpty {
            map.addOverlay(overlay, level: map.drawnOverlayLevel)
        }
        map.addAnnotations(routes.compactMap { route in
            route.coordinates.first.map { ComparisonStartMarker(coordinate: $0, route: route, dark: dark) }
        })
        // Fit again when rides are added or removed, as before.
        if ridesChanged && !routedIDs.isEmpty {
            Self.fit(map, to: overlay.routesRect)
        }
    }

    /// Shows all routes once the map has its size (see `RideMapRepresentable.fit`).
    private static func fit(_ map: MKMapView, to rect: MKMapRect, attempt: Int = 0) {
        DispatchQueue.main.async {
            if map.bounds.width < 10 || map.bounds.height < 10, attempt < 20 {
                fit(map, to: rect, attempt: attempt + 1)
                return
            }
            guard !rect.isNull else { return }
            map.setVisibleMapRect(rect, edgePadding: NSEdgeInsets(top: 50, left: 40, bottom: 40, right: 40), animated: false)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var key: String?
        var routedIDs: [UUID]?

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay { return MutedTileRenderer(tileOverlay: tiles) }
            return overlay is ComparisonRoutesOverlay ? ComparisonRoutesRenderer(overlay: overlay) : MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let marker = annotation as? ComparisonStartMarker else { return nil }
            let view = MKAnnotationView(annotation: marker, reuseIdentifier: nil)
            view.image = marker.image
            view.displayPriority = .required
            view.toolTip = marker.title
            return view
        }
    }
}

/// The marker of a column at the start of its route, white round with the symbol in its colour.
private final class ComparisonStartMarker: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let image: NSImage

    init(coordinate: CLLocationCoordinate2D, route: ComparedRoute, dark: Bool) {
        self.coordinate = coordinate
        title = route.name
        var color = NSColor.black
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            color = NSColor(ComparisonStyle.color(route.index)).usingColorSpace(.sRGB) ?? .black
        }
        let symbol = NSImage(systemSymbolName: ComparisonStyle.marker(route.index), accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [color])))
        image = NSImage(size: NSSize(width: 26, height: 26), flipped: false) { _ in
            let circle = NSRect(x: 3, y: 3, width: 20, height: 20)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 1.5
            shadow.shadowColor = .black.withAlphaComponent(0.33)
            shadow.set()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: circle).fill()
            NSGraphicsContext.restoreGraphicsState()
            if let symbol {
                symbol.draw(in: NSRect(x: circle.midX - symbol.size.width / 2, y: circle.midY - symbol.size.height / 2,
                                       width: symbol.size.width, height: symbol.size.height))
            }
            return true
        }
    }
}

/// All compared routes in map coordinates with their colours resolved, so the renderer can
/// draw them from any thread in a fixed order: the first column at the bottom.
private final class ComparisonRoutesOverlay: NSObject, MKOverlay {
    struct Line {
        var points: [MKMapPoint]
        var color: CGColor
        var dash: [CGFloat]
    }

    let lines: [Line]
    let routesRect: MKMapRect
    let boundingMapRect: MKMapRect
    var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }

    init(routes: [ComparedRoute], dark: Bool) {
        var lines: [Line] = []
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            lines = routes.filter { $0.coordinates.count > 1 }.map {
                Line(points: $0.coordinates.map(MKMapPoint.init), color: NSColor(ComparisonStyle.color($0.index)).cgColor,
                     dash: ComparisonStyle.dash($0.index).map { $0 * 1.6 })
            }
        }
        self.lines = lines
        let rect = lines.flatMap(\.points).reduce(MKMapRect.null) {
            $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0)))
        }
        routesRect = rect
        // Margin for the width of the lines at the edges.
        boundingMapRect = rect.isNull ? .world : rect.insetBy(dx: -rect.width * 0.05 - 500, dy: -rect.height * 0.05 - 500)
    }
}

/// A white outline under each route, then the route in its colour and dash, as the SwiftUI map drew them.
private final class ComparisonRoutesRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? ComparisonRoutesOverlay else { return }
        let scale = 1 / zoomScale
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for line in overlay.lines {
            for (width, color, dash) in [(7, CGColor(gray: 1, alpha: 1), [] as [CGFloat]), (4, line.color, line.dash)] as [(CGFloat, CGColor, [CGFloat])] {
                context.beginPath()
                context.move(to: point(for: line.points[0]))
                for p in line.points.dropFirst() { context.addLine(to: point(for: p)) }
                context.setLineWidth(width * scale)
                context.setLineDash(phase: 0, lengths: dash.map { $0 * scale })
                context.setStrokeColor(color)
                context.strokePath()
            }
        }
    }
}
