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

    var body: some View {
        RecordingMapRepresentable(mapType: mapType, segments: segments, colouring: colouring,
                                  heading: heading, center: center, dark: colorScheme == .dark)
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        map.showsUserLocation = true
        map.showsCompass = false
        map.setUserTrackingMode(.follow, animated: false)
        // The button that brings the own position back and the compass, at the top right as before.
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
            buttons.topAnchor.constraint(equalTo: map.safeAreaLayoutGuide.topAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: map.safeAreaLayoutGuide.trailingAnchor, constant: -8),
        ])
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType)
        }
        // The track grows with every fix: drawn again when a point, the colouring or the appearance changes.
        let drawingKey = "\(segments.map(\.count))|\(colouring.key)|\(dark)"
        if coordinator.drawingKey != drawingKey {
            coordinator.drawingKey = drawingKey
            map.removeOverlays(map.drawnOverlays)
            if segments.contains(where: { $0.count > 1 }) {
                map.addOverlay(RideRouteOverlay(segments: segments, colouring: colouring, dark: dark, colors: .phone(dark: dark)),
                               level: map.drawnOverlayLevel)
            }
        }
        coordinator.turn(map, heading: heading, center: center)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var drawingKey: String?
        /// The zoom the rider chose, in metres from the ground, kept while the map turns.
        private var distance = 1_500.0
        private var turned = false
        private var lastTurn: (heading: Double, latitude: Double, longitude: Double)?

        /// Direction of travel up: centre on the position and turn to `heading`. North up again: follow
        /// the position as MapKit does it.
        func turn(_ map: MKMapView, heading: Double?, center: CLLocationCoordinate2D?) {
            guard let heading, let center else {
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
            distance = mapView.camera.centerCoordinateDistance
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            MapRenderers.renderer(for: overlay)
        }
    }
}
