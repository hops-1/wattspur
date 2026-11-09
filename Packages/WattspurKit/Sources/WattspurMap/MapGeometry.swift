import CoreGraphics
import Foundation
import MapKit
import WattspurCore

extension MKMapRect {
    /// The smallest rectangle around `points`; `.null` without any.
    public init(covering points: some Sequence<MKMapPoint>) {
        self = points.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
    }

    /// The smallest rectangle around `coordinates`; `.null` without any.
    public init(covering coordinates: [CLLocationCoordinate2D]) {
        self.init(covering: coordinates.lazy.map(MKMapPoint.init))
    }

    /// Widened to the shape of `size` around the same centre, so an image of that size is not distorted.
    public func fitted(to size: CGSize) -> MKMapRect {
        guard width > 0, height > 0, size.height > 0 else { return self }
        let aspect = size.width / size.height
        if width / height > aspect {
            let height = width / aspect
            return MKMapRect(x: minX, y: midY - height / 2, width: width, height: height)
        }
        let width = height * aspect
        return MKMapRect(x: midX - width / 2, y: minY, width: width, height: height)
    }
}

extension MKMapView {
    /// How many metres `points` of the screen cover to the right of `point` (in the view's coordinates):
    /// the reach of the cursor, a click or a tooltip, so it feels the same at every zoom.
    public func metres(across points: CGFloat, at point: CGPoint) -> (coordinate: CLLocationCoordinate2D, metres: Double) {
        let here = convert(point, toCoordinateFrom: self)
        let beside = convert(CGPoint(x: point.x + points, y: point.y), toCoordinateFrom: self)
        let metres = CLLocation(latitude: here.latitude, longitude: here.longitude)
            .distance(from: CLLocation(latitude: beside.latitude, longitude: beside.longitude))
        return (here, metres)
    }
}

/// The renderer for each overlay the package makes; the apps' map delegates hand every overlay here.
public enum MapRenderers {
    public static func renderer(for overlay: any MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let tiles as MKTileOverlay: MutedTileRenderer.make(for: tiles)
        case is CurvyRoadsOverlay: CurvyRoadsRenderer(overlay: overlay)
        case is RideRouteOverlay: RideRouteRenderer(overlay: overlay)
        case is RidesMapOverlay: RidesMapRenderer(overlay: overlay)
        case is ComparisonRoutesOverlay: ComparisonRoutesRenderer(overlay: overlay)
        default: MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Compared routes

/// All compared routes (B-061c) in map coordinates with their colours resolved, so the renderer can
/// draw them from any thread in a fixed order: the first column at the bottom.
public final class ComparisonRoutesOverlay: NSObject, MKOverlay, @unchecked Sendable {
    public struct Line: Sendable {
        var points: [MKMapPoint]
        var color: CGColor
        var dash: [CGFloat]

        /// A route of two points or more in `color` and `dash` (in points).
        public init?(coordinates: [CLLocationCoordinate2D], color: CGColor, dash: [CGFloat]) {
            guard coordinates.count > 1 else { return nil }
            points = coordinates.map(MKMapPoint.init)
            self.color = color
            self.dash = dash
        }
    }

    public let lines: [Line]
    /// The routes alone, to fit the map around them.
    public let routesRect: MKMapRect
    public let boundingMapRect: MKMapRect
    public var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }

    public init(lines: [Line]) {
        self.lines = lines
        let rect = MKMapRect(covering: lines.flatMap(\.points))
        routesRect = rect
        // Margin for the width of the lines at the edges.
        boundingMapRect = rect.isNull ? .world : rect.insetBy(dx: -rect.width * 0.05 - 500, dy: -rect.height * 0.05 - 500)
    }
}

/// A white outline under each route, then the route in its colour and dash, as the SwiftUI map drew them.
public final class ComparisonRoutesRenderer: MKOverlayRenderer {
    override public func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
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

// MARK: - Tiles for the PDF

/// The tiles of an area put together into one image, because `MKMapSnapshotter` draws no tile
/// overlays (B-061d): loaded at the given pixel size, drawn and made pale like on screen. The app
/// adds the server's credit and draws the routes on top with `point(for:)`.
public struct TileMosaic: Sendable {
    public let image: CGImage
    /// The area of the image, in Mercator units of 0 … 1.
    public let area: MercatorRect

    /// The place of a coordinate in an image of `size`, counted from the top left.
    public func point(for coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let position = TileMath.position(of: MercatorPoint(RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)),
                                         in: area, width: size.width, height: size.height)
        return CGPoint(x: position.x, y: position.y)
    }

    /// `nil` when the area would need more than 200 tiles (a bulk download, which the servers
    /// forbid) or a tile could not be loaded: a map with holes is worse than Apple's map.
    public static func make(_ source: TileSource, rect: MKMapRect, pixelWidth: Int, pixelHeight: Int) async -> TileMosaic? {
        let world = MKMapSize.world.width
        let area = MercatorRect(minX: rect.minX / world, minY: rect.minY / world,
                                maxX: rect.maxX / world, maxY: rect.maxY / world)
        let zoom = TileMath.zoom(for: area, pixelWidth: Double(pixelWidth), tileSize: source.tileSize, maxZoom: source.maxZoom)
        let needed = TileMath.tiles(covering: area, zoom: zoom)
        guard !needed.isEmpty, needed.count <= 200 else { return nil }
        let loaded = await withTaskGroup(of: (Tile, CGImage?).self) { group in
            for tile in needed {
                group.addTask {
                    let data = try? await TileLoader.data(for: tile, from: source)
                    return (tile, data.flatMap(TileImage.decode))
                }
            }
            return await group.reduce(into: [(Tile, CGImage)]()) { result, item in
                if let image = item.1 { result.append((item.0, image)) }
            }
        }
        guard loaded.count == needed.count,
              let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        for (tile, image) in loaded {
            let tileRect = tile.rect
            let topLeft = TileMath.position(of: MercatorPoint(x: tileRect.minX, y: tileRect.minY), in: area,
                                            width: Double(pixelWidth), height: Double(pixelHeight))
            let bottomRight = TileMath.position(of: MercatorPoint(x: tileRect.maxX, y: tileRect.maxY), in: area,
                                                width: Double(pixelWidth), height: Double(pixelHeight))
            // The context counts y from the bottom.
            context.draw(image, in: CGRect(x: topLeft.x, y: Double(pixelHeight) - bottomRight.y,
                                           width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
        }
        MutedTileRenderer.mute(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight), in: context)
        guard let image = context.makeImage() else { return nil }
        return TileMosaic(image: image, area: area)
    }
}
