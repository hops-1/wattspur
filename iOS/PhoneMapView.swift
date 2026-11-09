import MapKit
import SwiftUI
import WattspurCore
import WattspurMap

/// The map of a ride on the iPhone (B-226): an `MKMapView` with the overlays of the package, so it
/// shows the OpenStreetMap styles, which SwiftUI's `Map` cannot, and draws the route like the Mac
/// (`RideRouteOverlay`). Without `interactive` it is a picture: no panning or zooming.
struct PhoneMapView: View {
    var mapType: RideMapType
    /// One line per recording.
    var segments: [[CLLocationCoordinate2D]]
    var colouring: RouteColouring = .plain
    /// The spot under the finger on the chart (B-221), as a dot on the track.
    var marker: CLLocationCoordinate2D?
    var interactive = false
    /// The area to show first; the track with a margin.
    var area: MKMapRect
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PhoneMapRepresentable(mapType: mapType, segments: segments, colouring: colouring, marker: marker,
                              interactive: interactive, area: area, dark: colorScheme == .dark)
            .overlay(alignment: .bottomTrailing) {
                if let source = mapType.tileSource {
                    TileAttribution(source: source, interactive: interactive)
                        .padding(.trailing, 6)
                        .padding(.bottom, 4)
                }
            }
    }
}

extension RouteColors {
    /// The track colour of the iPhone and the system grey, resolved for the light or dark appearance.
    static func phone(dark: Bool) -> RouteColors {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        return RouteColors(accent: UIColor(Color.track).resolvedColor(with: traits).cgColor,
                           noHeight: UIColor.systemGray.resolvedColor(with: traits).cgColor)
    }
}

private struct PhoneMapRepresentable: UIViewRepresentable {
    let mapType: RideMapType
    let segments: [[CLLocationCoordinate2D]]
    let colouring: RouteColouring
    let marker: CLLocationCoordinate2D?
    let interactive: Bool
    let area: MKMapRect
    let dark: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> FittingMapView {
        let map = FittingMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        // North stays up, so the compass would only cover the style button.
        map.isRotateEnabled = false
        map.showsCompass = false
        map.showsScale = false
        return map
    }

    func updateUIView(_ map: FittingMapView, context: Context) {
        let coordinator = context.coordinator
        map.isUserInteractionEnabled = interactive
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType)
        }
        let drawingKey = "\(segments.map(\.count))|\(segments.first?.first.map { "\($0.latitude),\($0.longitude)" } ?? "")|\(colouring.key)|\(dark)"
        if coordinator.drawingKey != drawingKey {
            coordinator.drawingKey = drawingKey
            map.removeOverlays(map.drawnOverlays)
            if segments.contains(where: { $0.count > 1 }) {
                map.addOverlay(RideRouteOverlay(segments: segments, colouring: colouring, dark: dark, colors: .phone(dark: dark)),
                               level: map.drawnOverlayLevel)
            }
        }
        // Room below the track for the credit of an OpenStreetMap style.
        map.bottomRoom = mapType.tileSource == nil ? 0 : (interactive ? 36 : 22)
        map.area = area
        coordinator.show(marker, on: map, dark: dark)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var drawingKey: String?
        private var markerAnnotation: CursorAnnotation?
        private var markerDark: Bool?

        /// Moves the dot under the finger, or takes it off the map.
        func show(_ coordinate: CLLocationCoordinate2D?, on map: MKMapView, dark: Bool) {
            guard let coordinate else {
                if let markerAnnotation { map.removeAnnotation(markerAnnotation) }
                markerAnnotation = nil
                return
            }
            if let markerAnnotation, markerDark == dark {
                markerAnnotation.coordinate = coordinate
            } else {
                if let markerAnnotation { map.removeAnnotation(markerAnnotation) }
                let annotation = CursorAnnotation(coordinate: coordinate)
                markerAnnotation = annotation
                markerDark = dark
                map.addAnnotation(annotation)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            MapRenderers.renderer(for: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard annotation is CursorAnnotation else { return nil }
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            let color = UIColor(Color.track).resolvedColor(with: UITraitCollection(userInterfaceStyle: markerDark == true ? .dark : .light))
            let scale = mapView.traitCollection.displayScale
            view.image = RouteMarkerImage.marker(color: color.cgColor, scale: scale)
                .map { UIImage(cgImage: $0, scale: scale, orientation: .up) }
            view.displayPriority = .required
            view.zPriority = .max
            view.isAccessibilityElement = false
            return view
        }
    }
}

/// A map that shows its `area` whenever its size changes, until the rider moves it: SwiftUI gives it
/// its final size only after a few passes, and fitted before that the track ran out of the picture.
final class FittingMapView: MKMapView {
    var area: MKMapRect? {
        didSet {
            guard let area, oldValue.map({ $0.origin.x != area.origin.x || $0.origin.y != area.origin.y
                                          || $0.size.width != area.size.width || $0.size.height != area.size.height }) ?? true else { return }
            moved = false
            fittedSize = nil
            setNeedsLayout()
        }
    }
    /// Points at the bottom the track keeps clear of, for the tile server's credit.
    var bottomRoom: CGFloat = 0 {
        didSet { if bottomRoom != oldValue { fittedSize = nil; setNeedsLayout() } }
    }
    private var fittedSize: CGSize?
    private var moved = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let area, !moved, bounds.width >= 10, bounds.height >= 10, bounds.size != fittedSize else { return }
        fittedSize = bounds.size
        let padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomRoom, right: 0)
        setVisibleMapRect(area, edgePadding: padding, animated: false)
        // With tiles MapKit snaps to a whole zoom level, often the closer one, and the track ran out of
        // the picture; then one level further out.
        if !visibleMapRect.contains(area) {
            setVisibleMapRect(area.insetBy(dx: -area.width / 2, dy: -area.height / 2), edgePadding: padding, animated: false)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        moved = true
        super.touchesBegan(touches, with: event)
    }
}

/// The credit a tile server asks for, at the bottom right of the map; always visible (B-226).
struct TileAttribution: View {
    let source: TileSource
    /// Only the detail's map opens the licence; a picture passes every tap on to its tile.
    var interactive = true

    var body: some View {
        // Small and on one line where it can, so it covers little of the map.
        let text = Text(verbatim: source.attribution)
            .font(.system(size: interactive ? 9 : 7.5))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: 300, alignment: .trailing)
        if interactive {
            Link(destination: source.attributionURL) { text }
                .accessibilityLabel(Text(verbatim: source.attribution))
                .accessibilityHint(Text("Map data and style: open the licence"))
        } else {
            text.accessibilityHidden(true)
        }
    }
}

extension RideMapType {
    /// The names in the style choice (B-226), as on the Mac.
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
}
