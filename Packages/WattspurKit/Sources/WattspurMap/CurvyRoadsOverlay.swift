import CoreGraphics
import Foundation
import MapKit
import WattspurCore

// The layer "Curvy roads" on the maps (B-183): roads from roadcurvature.com that the user has
// imported (B-182), drawn below the route in orange (from 300) and red (from 1000).

/// All imported roads in one piece, handed to the map renderers. Immutable, so any thread may read it.
public final class CurvyRoadSet: @unchecked Sendable {
    /// Tells the maps whether the set has changed.
    public let id = UUID()
    public let roads: [CurvyRoad]

    public init(roads: [CurvyRoad]) { self.roads = roads }

    /// The road nearest to a position within `metres`, for the tooltip.
    public func nearest(latitude: Double, longitude: Double, within metres: Double) -> CurvyRoad? {
        let margin = metres / 111_320 * 1.5
        let lonMargin = margin / max(0.2, cos(latitude * .pi / 180))
        var best: (road: CurvyRoad, distance: Double)?
        for road in roads where road.intersects(minLatitude: latitude - margin, maxLatitude: latitude + margin,
                                               minLongitude: longitude - lonMargin, maxLongitude: longitude + lonMargin) {
            let distance = road.distance(toLatitude: latitude, longitude: longitude)
            if distance <= metres, distance < (best?.distance ?? .infinity) { best = (road, distance) }
        }
        return best?.road
    }
}

extension CurvyRoad {
    public var coordinates2D: [CLLocationCoordinate2D] {
        (0..<pointCount).map { CLLocationCoordinate2D(latitude: Double(coordinates[2 * $0]), longitude: Double(coordinates[2 * $0 + 1])) }
    }
}

/// One overlay for all roads; the renderer draws the ones in the tile it is asked for.
public final class CurvyRoadsOverlay: NSObject, MKOverlay, @unchecked Sendable {
    public let set: CurvyRoadSet
    let curvyColor: CGColor
    let veryCurvyColor: CGColor
    public var boundingMapRect: MKMapRect { .world }
    public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }

    public init(set: CurvyRoadSet, dark: Bool) {
        self.set = set
        curvyColor = MapPalette.curvyRoad(veryCurvy: false).cgColor(dark: dark)
        veryCurvyColor = MapPalette.curvyRoad(veryCurvy: true).cgColor(dark: dark)
    }
}

public final class CurvyRoadsRenderer: MKOverlayRenderer {
    override public func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? CurvyRoadsOverlay else { return }
        // Zoomed out too far, all roads of a state would be a tangle.
        let centre = MKMapPoint(x: mapRect.midX, y: mapRect.midY).coordinate
        let metresPerPoint = (1 / zoomScale) / MKMapPointsPerMeterAtLatitude(centre.latitude)
        guard metresPerPoint <= CurvyRoads.maximumMetresPerPoint else { return }
        // The geographic box of the tile, with room for the width of the lines.
        let margin = mapRect.width * 0.05
        let northWest = MKMapPoint(x: mapRect.minX - margin, y: mapRect.minY - margin).coordinate
        let southEast = MKMapPoint(x: mapRect.maxX + margin, y: mapRect.maxY + margin).coordinate
        let scale = 1 / zoomScale
        context.setLineCap(.round)
        context.setLineJoin(.round)
        // The curvy ones first, so the very curvy lie on top.
        for veryCurvy in [false, true] {
            context.setStrokeColor(veryCurvy ? overlay.veryCurvyColor : overlay.curvyColor)
            context.setLineWidth((veryCurvy ? 4 : 3) * scale)
            context.beginPath()
            for road in overlay.set.roads where road.isVeryCurvy == veryCurvy
                && road.intersects(minLatitude: southEast.latitude, maxLatitude: northWest.latitude,
                                   minLongitude: northWest.longitude, maxLongitude: southEast.longitude) {
                for i in 0..<road.pointCount {
                    let p = point(for: MKMapPoint(CLLocationCoordinate2D(latitude: Double(road.coordinates[2 * i]),
                                                                          longitude: Double(road.coordinates[2 * i + 1]))))
                    if i == 0 { context.move(to: p) } else { context.addLine(to: p) }
                }
            }
            context.strokePath()
        }
    }
}
