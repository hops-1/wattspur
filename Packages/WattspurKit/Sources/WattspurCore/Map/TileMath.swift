import Foundation

// Which tiles a map image needs and where a coordinate lands in it (B-061). The app
// stitches the tiles for the PDF itself, because `MKMapSnapshotter` cannot draw tile
// overlays. Everything is in Web Mercator units (`MercatorPoint`): the world is the unit
// square, x to the east, y to the south, so positions are linear in x and y.

/// One tile of a tile server: at zoom z the world is 2^z × 2^z tiles.
public struct Tile: Sendable, Hashable {
    public var zoom: Int
    public var x: Int
    public var y: Int

    public init(zoom: Int, x: Int, y: Int) {
        self.zoom = zoom
        self.x = x
        self.y = y
    }

    /// The tile that contains the point; points on the edge of the world stay inside.
    public init(containing point: MercatorPoint, zoom: Int) {
        let count = 1 << zoom
        self.init(zoom: zoom,
                  x: min(count - 1, max(0, Int((point.x * Double(count)).rounded(.down)))),
                  y: min(count - 1, max(0, Int((point.y * Double(count)).rounded(.down)))))
    }

    /// The square the tile covers.
    public var rect: MercatorRect {
        let size = 1 / Double(1 << zoom)
        return MercatorRect(minX: Double(x) * size, minY: Double(y) * size,
                            maxX: Double(x + 1) * size, maxY: Double(y + 1) * size)
    }
}

/// A rectangle in Web Mercator units; `minY` is the northern edge.
public struct MercatorRect: Sendable, Hashable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(_ bounds: GeoBounds) {
        let northWest = MercatorPoint(RoutePoint(latitude: bounds.maxLatitude, longitude: bounds.minLongitude))
        let southEast = MercatorPoint(RoutePoint(latitude: bounds.minLatitude, longitude: bounds.maxLongitude))
        self.init(minX: northWest.x, minY: northWest.y, maxX: southEast.x, maxY: southEast.y)
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
}

public extension RoutePoint {
    /// The coordinate of a Web Mercator point; the inverse of `MercatorPoint(_:)`.
    init(_ point: MercatorPoint) {
        self.init(latitude: atan(sinh(.pi * (1 - 2 * point.y))) * 180 / .pi,
                  longitude: point.x * 360 - 180)
    }
}

public enum TileMath {
    /// The zoom at which one tile pixel is about one image pixel across `rect`,
    /// limited to what the server renders.
    /// - Parameter pixelWidth: width of the image in pixels (points × scale).
    public static func zoom(for rect: MercatorRect, pixelWidth: Double, tileSize: Int = 256, maxZoom: Int) -> Int {
        guard rect.width > 0, pixelWidth > 0 else { return 0 }
        let zoom = log2(pixelWidth / (Double(tileSize) * rect.width)).rounded()
        return min(maxZoom, max(0, Int(zoom)))
    }

    /// The tiles that cover `rect`, row by row from the north-west.
    public static func tiles(covering rect: MercatorRect, zoom: Int) -> [Tile] {
        let northWest = Tile(containing: MercatorPoint(x: rect.minX, y: rect.minY), zoom: zoom)
        let southEast = Tile(containing: MercatorPoint(x: rect.maxX, y: rect.maxY), zoom: zoom)
        return (northWest.y...southEast.y).flatMap { y in
            (northWest.x...southEast.x).map { Tile(zoom: zoom, x: $0, y: y) }
        }
    }

    /// Where `point` lands in an image of `width` × `height` that shows `rect`,
    /// counted from the top left like the PDF draws (see B-126).
    public static func position(of point: MercatorPoint, in rect: MercatorRect,
                                width: Double, height: Double) -> (x: Double, y: Double) {
        ((point.x - rect.minX) / rect.width * width, (point.y - rect.minY) / rect.height * height)
    }
}
