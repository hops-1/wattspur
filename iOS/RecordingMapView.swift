import MapKit
import SwiftUI
import WattspurCore
import WattspurMap

/// The map while recording (B-211, B-226): an `MKMapView` in the chosen map style with the track so far
/// and the own position. North up it follows the position itself; with `heading` (direction of travel
/// up, B-280) the app turns it to the course of the GPS and keeps the zoom the rider chose.
struct RecordingMapView: View {
    var mapType: RideMapType
    /// The track so far, one line per recording segment.
    var segments: [[CLLocationCoordinate2D]]
    var colouring: RouteColouring
    /// Where the map points while the direction of travel is up; `nil` north up.
    var heading: Double?
    /// The position the map centres on while turned.
    var center: CLLocationCoordinate2D?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    /// The zoom the rider chose, kept while the map is taken down in the background.
    @State private var distance = RecordingMapZoom.standardDistance

    var body: some View {
        // In the background the map is taken down and gives its memory back (B-382): with its tiles it
        // was the largest part of the app, and iOS ends the app that holds the most when the camera
        // needs memory (B-380). It comes back with the rider's zoom when the app is in front again.
        if scenePhase == .background {
            Color(.systemBackground)
        } else {
            map
        }
    }

    private var map: some View {
        RecordingMapRepresentable(mapType: mapType, segments: segments, colouring: colouring,
                                  heading: heading, center: center, dark: colorScheme == .dark, phase: scenePhase,
                                  distance: $distance)
            .overlay(alignment: .bottomTrailing) {
                // At the bottom right as on every other map; the buttons and the legend leave room for it.
                if let source = mapType.tileSource {
                    TileAttribution(source: source)
                        .padding(.trailing, 6)
                        .padding(.bottom, 4)
                }
            }
    }
}

private struct RecordingMapRepresentable: UIViewRepresentable {
    let mapType: RideMapType
    let segments: [[CLLocationCoordinate2D]]
    let colouring: RouteColouring
    let heading: Double?
    let center: CLLocationCoordinate2D?
    let dark: Bool
    /// Only here so the map draws at once when the app comes back, also standing without a new position.
    let phase: ScenePhase
    /// The rider's zoom in metres from the ground; kept outside the map, which is rebuilt.
    @Binding var distance: Double

    func makeCoordinator() -> Coordinator { Coordinator(distance: $distance) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        map.showsUserLocation = true
        map.showsCompass = false
        map.setUserTrackingMode(.follow, animated: false)
        // The button that brings the own position back and the compass, at the top right below the
        // map style button (44 pt with 12 pt margin, from RecordingView).
        let buttons = UIStackView(arrangedSubviews: [MKUserTrackingButton(mapView: map), {
            let compass = MKCompassButton(mapView: map)
            compass.compassVisibility = .adaptive
            return compass
        }()])
        buttons.axis = .vertical
        buttons.spacing = 8
        buttons.alignment = .center
        buttons.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(buttons)
        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(equalTo: map.safeAreaLayoutGuide.topAnchor, constant: 68),
            buttons.centerXAnchor.constraint(equalTo: map.safeAreaLayoutGuide.trailingAnchor, constant: -34),
        ])
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType)
        }
        coordinator.draw(map, segments: segments, colouring: colouring, dark: dark)
        coordinator.turn(map, heading: heading, center: center)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var drawingKey: String?
        /// The track in pieces (B-365), by segment and first point, with the last point each was drawn
        /// to: the last point of the track may still move (`RideRecording.route` keeps it in any case).
        private var pieces: [String: (end: Int, last: CLLocationCoordinate2D?, overlay: RideRouteOverlay)] = [:]
        private var style: String?
        private var lastDraw = Date.distantPast
        /// The zoom the rider chose, in metres from the ground, kept while the map turns and while it is
        /// taken down in the background (B-382).
        private var zoom: Binding<Double>
        private var distance: Double {
            get { zoom.wrappedValue }
            set { if zoom.wrappedValue != newValue { zoom.wrappedValue = newValue } }
        }

        init(distance: Binding<Double>) {
            zoom = distance
        }
        private var turned = false
        private var lastTurn: (heading: Double, latitude: Double, longitude: Double)?

        /// The track grows with every fix. Plain, only its last piece is drawn again, so MapKit keeps
        /// the tiles of the rest (B-365); coloured by height the colours come from the whole ride, so
        /// it is drawn as one line, at most every few seconds. Hidden or hot, the map waits.
        func draw(_ map: MKMapView, segments: [[CLLocationCoordinate2D]], colouring: RouteColouring, dark: Bool) {
            guard UIApplication.shared.applicationState == .active else { return }
            let key = "\(segments.map(\.count))|\(colouring.key)|\(dark)"
            guard key != drawingKey else { return }
            let plain = if case .plain = colouring { true } else { false }
            let style = "\(plain)|\(dark)"
            let restyled = style != self.style
            let interval = RecordingMapPace.interval(thermal: ProcessInfo.processInfo.thermalState, plain: plain)
            guard restyled || Date.now.timeIntervalSince(lastDraw) >= interval else { return }
            drawingKey = key
            lastDraw = .now
            if restyled {
                self.style = style
                map.removeOverlays(pieces.values.map(\.overlay))
                pieces = [:]
            }
            let colors = RouteColors.phone(dark: dark)
            guard plain else {
                let old = pieces.values.map(\.overlay)
                pieces = [:]
                if segments.contains(where: { $0.count > 1 }) {
                    let overlay = RideRouteOverlay(segments: segments, colouring: colouring, dark: dark, colors: colors)
                    map.addOverlay(overlay, level: map.drawnOverlayLevel)
                    pieces["all"] = (0, nil, overlay)
                }
                map.removeOverlays(old)
                return
            }
            var wanted = Set<String>()
            for (index, segment) in segments.enumerated() {
                for range in RecordingTrackChunks.ranges(count: segment.count) where range.count > 1 {
                    let id = "\(index)|\(range.lowerBound)"
                    wanted.insert(id)
                    let last = segment[range.upperBound - 1]
                    if let drawn = pieces[id], drawn.end == range.upperBound, drawn.last?.latitude == last.latitude,
                       drawn.last?.longitude == last.longitude { continue }
                    if let old = pieces[id] { map.removeOverlay(old.overlay) }
                    let overlay = RideRouteOverlay(segments: [Array(segment[range])], colouring: .plain, dark: dark,
                                                   colors: colors, flatEnds: true)
                    map.addOverlay(overlay, level: map.drawnOverlayLevel)
                    pieces[id] = (range.upperBound, last, overlay)
                }
            }
            for (id, piece) in pieces where !wanted.contains(id) {
                map.removeOverlay(piece.overlay)
                pieces[id] = nil
            }
        }

        /// Direction of travel up: centre on the position and turn to `heading`. North up again: follow
        /// the position as MapKit does it.
        func turn(_ map: MKMapView, heading: Double?, center: CLLocationCoordinate2D?) {
            guard let heading, let center else {
                // North up, still showing the whole world (B-363): after a crash the recording goes on
                // before MapKit's follow mode zooms in, and the map stayed that wide. Zoom to the position.
                if !turned, let center, RecordingMapZoom.showsTooMuch(map.camera.centerCoordinateDistance) {
                    // The rider's zoom when the map comes back from the background (B-382).
                    map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: distance,
                                              pitch: 0, heading: 0), animated: false)
                    map.setUserTrackingMode(.follow, animated: false)
                }
                if turned {
                    turned = false
                    lastTurn = nil
                    // Following keeps the turn, so north goes up first, as with SwiftUI's map before.
                    let camera = map.camera.copy() as? MKMapCamera ?? map.camera
                    camera.heading = 0
                    UIView.animate(withDuration: 0.4, animations: { map.camera = camera }) { _ in
                        map.setUserTrackingMode(.follow, animated: true)
                    }
                }
                return
            }
            if let lastTurn, lastTurn.heading == heading, lastTurn.latitude == center.latitude,
               lastTurn.longitude == center.longitude { return }
            lastTurn = (heading, center.latitude, center.longitude)
            if !turned {
                turned = true
                map.setUserTrackingMode(.none, animated: false)
            }
            let camera = MKMapCamera(lookingAtCenter: center, fromDistance: distance, pitch: 0, heading: heading)
            UIView.animate(withDuration: 0.8, delay: 0, options: [.curveLinear, .beginFromCurrentState, .allowUserInteraction]) {
                map.camera = camera
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // The world view of a fresh map is not a zoom the rider chose (B-363); it keeps the last one,
            // also the one from before the map was taken down in the background (B-382).
            let current = mapView.camera.centerCoordinateDistance
            if !RecordingMapZoom.showsTooMuch(current) { distance = current }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            MapRenderers.renderer(for: overlay)
        }
    }
}
