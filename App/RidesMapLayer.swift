import AppKit
import MapKit
import SwiftUI
import WattspurKit
import WattspurMap

extension RidesMapStyle {
    /// The style with the comparison's colours and the accent colour of the Mac, resolved for the appearance.
    init(rides: [MapRide], highlighted: [UUID], selected: Set<UUID> = [], focused: UUID? = nil,
         mode: Mode = .lines, dark: Bool) {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        func resolved(_ color: () -> NSColor) -> CGColor {
            var cgColor = CGColor(gray: 0, alpha: 1)
            appearance?.performAsCurrentDrawingAppearance { cgColor = color().cgColor }
            return cgColor
        }
        self.init(rides: rides, highlighted: highlighted, selected: selected, focused: focused, mode: mode, dark: dark,
                  highlightColor: { index in resolved { NSColor(ComparisonStyle.color(index)) } },
                  highlightDash: ComparisonStyle.dash,
                  accent: resolved { NSColor.controlAccentColor })
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
    /// The imported curvy roads, below the rides; `nil` while the layer is off (B-183).
    var curvyRoads: CurvyRoadSet?
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(onVisibleAreaChange: onVisibleAreaChange) }

    func makeNSView(context: Context) -> MKMapView {
        let map = TrackingMapView()
        map.onMove = { [weak map, weak coordinator = context.coordinator] point in
            map?.updateCurvyRoadTooltip(at: point, roads: coordinator?.curvyRoads)
        }
        map.onExit = { [weak map] in map?.toolTip = nil }
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
        context.coordinator.curvyRoads = curvyRoads
        if context.coordinator.mapType != mapType {
            context.coordinator.mapType = mapType
            map.show(mapType, muted: true)
        }
        let drawingKey = "\(styleKey)|\(curvyRoads?.id.uuidString ?? "-")|\(colorScheme == .dark)"
        if context.coordinator.styleKey != drawingKey {
            context.coordinator.styleKey = drawingKey
            map.removeOverlays(map.drawnOverlays)
            if let curvyRoads { map.addOverlay(CurvyRoadsOverlay(set: curvyRoads, dark: colorScheme == .dark), level: map.drawnOverlayLevel) }
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
        var curvyRoads: CurvyRoadSet?
        var mapType: RideMapType?
        var styleKey: String?
        var fitKey: [UUID]?
        var fitRequest: Int?

        init(onVisibleAreaChange: @escaping (MKMapRect) -> Void) {
            self.onVisibleAreaChange = onVisibleAreaChange
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            MapRenderers.renderer(for: overlay)
        }

        /// The click radius is 10 pt on screen, so it feels the same at every zoom
        /// (Requirements 10.11); MapKit's own controls keep their clicks.
        @objc func clicked(_ recognizer: NSClickGestureRecognizer) {
            guard let map = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: map)
            let (coordinate, radius) = map.metres(across: 10, at: point)
            let topLeft = CGPoint(x: point.x, y: map.isFlipped ? point.y : map.bounds.height - point.y)
            onClick(coordinate, radius, topLeft)
        }

        /// Tiles below the map update once panning or zooming ends (B-114).
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onVisibleAreaChange(mapView.visibleMapRect)
        }
    }
}
