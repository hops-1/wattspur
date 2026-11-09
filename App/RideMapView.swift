import AppKit
import MapKit
import SwiftUI
import WattspurKit
import WattspurMap

/// The names of the map types and SwiftUI's fallback; the type itself is in the package (B-186).
extension RideMapType {
    var label: LocalizedStringKey {
        switch self {
        case .standard: "Standard"
        case .satellite: "Satellite"
        case .hybrid: "Hybrid"
        case .openStreetMap: "OpenStreetMap"
        case .cyclOSM: "CyclOSM"
        case .openTopoMap: "OpenTopoMap"
        }
    }

    /// For SwiftUI's `Map`, which cannot show tiles: the OpenStreetMap styles fall back to Apple's standard map.
    var style: MapStyle {
        switch self {
        case .standard, .openStreetMap, .cyclOSM, .openTopoMap: .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
        case .satellite: .imagery(elevation: .realistic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
        }
    }
}

extension RouteColors {
    /// The accent colour and the grey of the Mac, resolved for the light or dark appearance.
    static func mac(dark: Bool) -> RouteColors {
        var colors = RouteColors(accent: CGColor(gray: 0, alpha: 1), noHeight: CGColor(gray: 0.5, alpha: 1))
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            colors = RouteColors(accent: NSColor.controlAccentColor.cgColor, noHeight: NSColor.systemGray.cgColor)
        }
        return colors
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
    /// The route in pieces by curve (B-181); empty draws it in one colour.
    var curves: [CurvatureAnalyzer.Piece] = []
    /// The route by lean angle (B-247); used only while `curves` is empty.
    var leanStretches: [RideMotion.LeanStretch] = []
    /// The route by road surface (B-248); used only while `curves` and `leanStretches` are empty.
    var surfaceStretches: [RideMotion.SurfaceStretch] = []
    /// The imported curvy roads, drawn below the route; `nil` while the layer is off (B-183).
    var curvyRoads: CurvyRoadSet?
    /// The route by height (B-063); used only while the other colourings are empty.
    var elevation: RouteElevation.Result?

    @Environment(\.colorScheme) private var colorScheme
    /// The spot shared with the charts (B-062); not there in the PDF.
    @Environment(RideCursor.self) private var cursor: RideCursor?

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// Start and finish closer than 100 m count as one point (a loop).
    private var isLoop: Bool { RideMarker.isLoop(coordinates) }

    var body: some View {
        RideMapRepresentable(coordinates: coordinates, newStretches: newStretches,
                             colouring: .first(curves: curves, lean: leanStretches, surface: surfaceStretches,
                                               elevation: elevation?.stretches ?? []),
                             curvyRoads: curvyRoads,
                             ticks: JoinTick.ticks(of: joins), mapType: mapType, isLoop: isLoop, dark: colorScheme == .dark, cursor: cursor)
            .mapCredits(for: mapType, curvyRoads: curvyRoads != nil)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if curvyRoads != nil { CurvyRoadsLegend() }
                    if !curves.isEmpty {
                        CurvesLegend()
                    } else if !leanStretches.isEmpty {
                        LeanLegend()
                    } else if !surfaceStretches.isEmpty {
                        SurfaceLegend()
                    } else if let elevation {
                        ElevationLegend(scale: elevation.scale)
                    }
                    if !newStretches.isEmpty { NewPathsLegend() }
                }
                .padding(.leading, 12)
                .padding(.bottom, 40)
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
    let colouring: RouteColouring
    let curvyRoads: CurvyRoadSet?
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
            guard let map, let coordinator else { return }
            // Close enough to the route: 20 points of the screen, in metres.
            let (here, metres) = map.metres(across: 20, at: point)
            // A curvy road under the mouse says its name and curvature in a tooltip (B-183).
            map.updateCurvyRoadTooltip(at: point, roads: coordinator.curvyRoads)
            guard let cursor = coordinator.cursor else { return }
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
        coordinator.curvyRoads = curvyRoads
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType)
        }
        // Rebuilt whenever route, new stretches or appearance change; one overlay, so
        // there is no order between route and new stretches left to MapKit.
        let drawingKey = "\(coordinates.count)|\(coordinates.first.map { "\($0.latitude),\($0.longitude)" } ?? "")"
            + "|\(newStretches.map(\.count))|\(colouring.key)|\(curvyRoads?.id.uuidString ?? "-")|\(ticks.count)|\(ticks.first.map { "\($0.coordinate.latitude)" } ?? "")|\(dark)"
        if coordinator.drawingKey != drawingKey {
            coordinator.drawingKey = drawingKey
            map.removeOverlays(map.drawnOverlays)
            // The curvy roads first, so the route lies on top of them.
            if let curvyRoads { map.addOverlay(CurvyRoadsOverlay(set: curvyRoads, dark: dark), level: map.drawnOverlayLevel) }
            if coordinates.count > 1 {
                map.addOverlay(RideRouteOverlay(route: coordinates, newStretches: newStretches, colouring: colouring,
                                                 ticks: ticks, dark: dark, colors: .mac(dark: dark)), level: map.drawnOverlayLevel)
            }
        }
        // Markers and the visible area follow the route only, not the new stretches.
        // The loop marker is in the label colour, so it is made again with the appearance.
        let markerKey = "\(coordinates.count)|\(coordinates.first.map { "\($0.latitude),\($0.longitude)" } ?? "")"
        let routeKey = "\(markerKey)|\(dark)"
        if coordinator.routeKey != routeKey {
            let routeChanged = coordinator.routeKey?.hasPrefix(markerKey + "|") != true
            coordinator.routeKey = routeKey
            coordinator.dark = dark
            map.removeAnnotations(map.annotations.filter { $0 is RideMarker })
            if let start = coordinates.first {
                map.addAnnotation(RideMarker(coordinate: start, kind: isLoop ? .loop : .start, title: RideMarker.title(isLoop ? .loop : .start)))
            }
            if !isLoop, coordinates.count > 1, let finish = coordinates.last {
                map.addAnnotation(RideMarker(coordinate: finish, kind: .finish, title: RideMarker.title(.finish)))
            }
            if routeChanged { Self.fit(map, to: coordinates) }
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
            let rect = MKMapRect(covering: coordinates)
            guard !rect.isNull else { return }
            map.setVisibleMapRect(rect, edgePadding: NSEdgeInsets(top: 50, left: 40, bottom: 40, right: 40), animated: false)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var drawingKey: String?
        var routeKey: String?
        var cursor: RideCursor?
        var curvyRoads: CurvyRoadSet?
        var dark = false
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
            MapRenderers.renderer(for: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if annotation is CursorAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
                view.image = Self.cursorImage
                view.displayPriority = .required
                view.zPriority = .max
                view.canShowCallout = false
                return view
            }
            guard let marker = annotation as? RideMarker else { return nil }
            let view = MKAnnotationView(annotation: marker, reuseIdentifier: nil)
            view.image = RideMarker.image(marker.kind, dark: dark)
            view.displayPriority = .required
            view.toolTip = marker.title
            return view
        }

        static let cursorImage = RouteMarkerImage.cursor().map { NSImage(cgImage: $0, size: NSSize(width: 18, height: 18)) }
    }
}

/// A map that reports where the mouse moves, to couple it with the charts (B-062).
final class TrackingMapView: MKMapView {
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

extension RideMarker {
    static func title(_ kind: Kind) -> String {
        switch kind {
        case .start: String(localized: "Start")
        case .finish: String(localized: "Finish")
        case .loop: String(localized: "Start & finish")
        }
    }

    /// A 14 pt dot with a white ring and a light shadow: green start, red finish, label colour for a loop.
    static func image(_ kind: Kind, dark: Bool) -> NSImage? {
        var color = CGColor(gray: 0, alpha: 1)
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            color = switch kind {
            case .start: NSColor.systemGreen.cgColor
            case .finish: NSColor.systemRed.cgColor
            case .loop: NSColor.labelColor.cgColor
            }
        }
        return RouteMarkerImage.marker(color: color).map { NSImage(cgImage: $0, size: NSSize(width: 22, height: 22)) }
    }
}

/// "New – never ridden before" and "Ridden before" on the ride's map (B-115).
private struct NewPathsLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paths").font(.caption.weight(.bold))
            row(Color.newPaths, width: 4.5, text: "New – never ridden before")
            row(Color.accentColor, width: 4.5, text: "Ridden before")
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

extension Color {
    /// The colours of the curve kinds on the ride's map (B-181): red tight, amber gentle, grey straight.
    static func curve(_ kind: CurvatureAnalyzer.Kind) -> Color { .map(MapPalette.curve(kind)) }

    /// A colour of the maps' palette (B-186), for the light or dark appearance.
    static func map(_ pair: MapPalette.Pair) -> Color { .adaptive(light: pair.light, dark: pair.dark) }
}

/// "Tight curve", "Gentle curve" and "Straight" for the colours of the route (B-181, NFR-16).
private struct CurvesLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Curves").font(.caption.weight(.bold))
            row(.tight, text: "Tight curve")
            row(.gentle, text: "Gentle curve")
            row(.straight, text: "Straight")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func row(_ kind: CurvatureAnalyzer.Kind, text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(Color.curve(kind)).frame(width: 30, height: 4.5).accessibilityHidden(true)
            Text(text).font(.caption)
        }
    }
}

extension Color {
    /// The route by lean angle (B-247), as on the iPhone (B-246): from green upright through yellow and
    /// orange to red and purple.
    static func lean(_ band: RideMotion.LeanBand) -> Color { .map(MapPalette.lean(band)) }
}

/// What the colours of the route by lean angle mean (B-247).
private struct LeanLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lean Angle").font(.caption.weight(.bold))
            ForEach(RideMotion.LeanBand.allCases.reversed(), id: \.self) { band in
                HStack(spacing: 8) {
                    Capsule().fill(Color.lean(band)).frame(width: 30, height: 4.5).accessibilityHidden(true)
                    Text(verbatim: band == .extreme ? "40° +" : "\(Int(band.lowerBound))–\(Int(band.lowerBound) + 10)°")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Track coloured by lean angle, from green upright to purple at 40° and more"))
    }
}

extension Color {
    /// The route by road surface (B-248): grey smooth, yellow-orange uneven, red rough (B-276).
    static func surface(_ band: RideMotion.SurfaceBand) -> Color { .map(MapPalette.surface(band)) }
}

/// What the colours of the route by road surface mean (B-248).
private struct SurfaceLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Surface").font(.caption.weight(.bold))
            row(.rough, text: "Rough")
            row(.uneven, text: "Uneven")
            row(.smooth, text: "Smooth")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func row(_ band: RideMotion.SurfaceBand, text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(Color.surface(band)).frame(width: 30, height: 4.5).accessibilityHidden(true)
            Text(text).font(.caption)
        }
    }
}

extension Color {
    /// A step of the route by height (B-063): blue low to red high, from the palette in the Kit.
    static func elevation(_ level: Int) -> Color {
        let rgb = MapPalette.elevation(level)
        return Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

/// What the colours of the route by height mean (B-063): a bar from blue to red with the lowest and
/// the highest point of the ride.
struct ElevationLegend: View {
    let scale: RouteElevation.Scale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Route Elevation").font(.caption.weight(.bold))
            HStack(spacing: 8) {
                Text(RideFormat.altitude(scale.lowest)).font(.caption).monospacedDigit()
                Capsule()
                    .fill(LinearGradient(colors: (0..<RouteElevation.levels).map(Color.elevation), startPoint: .leading, endPoint: .trailing))
                    .frame(width: 70, height: 4.5)
                    .accessibilityHidden(true)
                Text(RideFormat.altitude(scale.highest)).font(.caption).monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Track coloured by elevation, from blue at \(RideFormat.altitude(scale.lowest)) to red at \(RideFormat.altitude(scale.highest))"))
    }
}
