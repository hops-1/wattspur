import MapKit
import SwiftData
import SwiftUI
import WattspurKit
import WattspurMap

// MARK: - Map of all compared routes

/// The routes on one map, each in its column's colour and dash, with its marker at the start.
/// An `MKMapView` like the other maps, so it can show the OpenStreetMap styles too (B-061c).
struct ComparisonMap: View {
    let rides: [Ride]
    let routes: [UUID: [RoutePoint]]
    @Binding var mapType: RideMapType
    @Environment(\.colorScheme) private var colorScheme
    /// The layer "Curvy roads" (B-183), below the routes.
    @Environment(CurvyRoadsStore.self) private var curvyStore
    @AppStorage(SettingsKey.showsCurvyRoads) private var showsCurvyRoads = false

    private var curvyRoads: CurvyRoadSet? { curvyStore.set(enabled: showsCurvyRoads) }

    private var hasRoutes: Bool { rides.contains { (routes[$0.id]?.count ?? 0) > 1 } }

    var body: some View {
        ComparisonMapRepresentable(
            routes: rides.enumerated().map { index, ride in
                ComparedRoute(id: ride.id, name: ride.name, index: index,
                              coordinates: (routes[ride.id] ?? []).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
            },
            curvyRoads: curvyRoads, mapType: mapType, dark: colorScheme == .dark)
        .frame(height: 340)
        .mapCredits(for: mapType, curvyRoads: curvyRoads != nil)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottomLeading) {
            if curvyRoads != nil {
                CurvyRoadsLegend()
                    .padding(.leading, 12)
                    // Above Apple's map attribution, which must stay visible.
                    .padding(.bottom, 40)
            }
        }
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
    let curvyRoads: CurvyRoadSet?
    let mapType: RideMapType
    let dark: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MKMapView {
        let map = TrackingMapView()
        // A curvy road under the mouse names itself in a tooltip (B-183).
        map.onMove = { [weak map, weak coordinator = context.coordinator] point in
            map?.updateCurvyRoadTooltip(at: point, roads: coordinator?.curvyRoads)
        }
        map.onExit = { [weak map] in map?.toolTip = nil }
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
        coordinator.curvyRoads = curvyRoads
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType)
        }
        // Rebuilt when rides, their routes or the appearance change.
        let key = routes.map { "\($0.id)|\($0.coordinates.count)" }.joined(separator: ",") + "|\(dark)|\(curvyRoads?.id.uuidString ?? "-")"
        guard coordinator.key != key else { return }
        // The routes are loaded after the map first appears, so fit whenever the rides that
        // have a route change, not only the rides: else the map stayed on its world overview.
        let routedIDs = routes.filter { $0.coordinates.count > 1 }.map(\.id)
        let ridesChanged = coordinator.routedIDs != routedIDs
        coordinator.key = key
        coordinator.routedIDs = routedIDs
        map.removeOverlays(map.drawnOverlays)
        map.removeAnnotations(map.annotations)
        if let curvyRoads { map.addOverlay(CurvyRoadsOverlay(set: curvyRoads, dark: dark), level: map.drawnOverlayLevel) }
        let overlay = ComparisonRoutesOverlay(lines: Self.lines(routes, dark: dark))
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

    /// Each route in its column's colour, resolved for the appearance, and its dash.
    private static func lines(_ routes: [ComparedRoute], dark: Bool) -> [ComparisonRoutesOverlay.Line] {
        var lines: [ComparisonRoutesOverlay.Line] = []
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            lines = routes.compactMap {
                ComparisonRoutesOverlay.Line(coordinates: $0.coordinates, color: NSColor(ComparisonStyle.color($0.index)).cgColor,
                                             dash: ComparisonStyle.dash($0.index).map { $0 * 1.6 })
            }
        }
        return lines
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
        var curvyRoads: CurvyRoadSet?

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            MapRenderers.renderer(for: overlay)
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
