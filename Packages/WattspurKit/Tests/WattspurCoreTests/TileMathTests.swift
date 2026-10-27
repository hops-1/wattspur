import Foundation
import Testing
@testable import WattspurCore

@Suite("Map tiles: sources, tile numbers and positions")
struct TileMathTests {
    private let darmstadt = RoutePoint(latitude: 49.8728, longitude: 8.6512)

    @Test("Tile numbers match the OSM scheme")
    func tileNumbers() {
        #expect(Tile(containing: MercatorPoint(darmstadt), zoom: 13) == Tile(zoom: 13, x: 4292, y: 2782))
        // The example on the OSM wiki: London at zoom 10.
        #expect(Tile(containing: MercatorPoint(RoutePoint(latitude: 51.5074, longitude: -0.1278)), zoom: 10)
                == Tile(zoom: 10, x: 511, y: 340))
        #expect(Tile(containing: MercatorPoint(RoutePoint(latitude: 0, longitude: 0)), zoom: 0) == Tile(zoom: 0, x: 0, y: 0))
    }

    @Test("Points on the edge of the world stay in the last tile")
    func edgeOfTheWorld() {
        #expect(Tile(containing: MercatorPoint(x: 1, y: 1), zoom: 3) == Tile(zoom: 3, x: 7, y: 7))
        #expect(Tile(containing: MercatorPoint(x: -0.1, y: 1.2), zoom: 3) == Tile(zoom: 3, x: 0, y: 7))
    }

    @Test("Coordinate → Mercator → coordinate comes back the same")
    func roundTrip() {
        for point in [darmstadt, RoutePoint(latitude: -33.86, longitude: 151.21), RoutePoint(latitude: 0, longitude: 0)] {
            let back = RoutePoint(MercatorPoint(point))
            #expect(abs(back.latitude - point.latitude) < 1e-9)
            #expect(abs(back.longitude - point.longitude) < 1e-9)
        }
    }

    @Test("A tile's rectangle contains the points it was made from")
    func tileRect() {
        let point = MercatorPoint(darmstadt)
        let rect = Tile(containing: point, zoom: 15).rect
        #expect(rect.minX <= point.x && point.x < rect.maxX)
        #expect(rect.minY <= point.y && point.y < rect.maxY)
        #expect(abs(rect.width - 1.0 / 32_768) < 1e-15)
    }

    @Test("Zoom: one tile pixel per image pixel, limited by the server")
    func zoom() {
        // A rectangle as wide as one tile at zoom 12, drawn 256 pixels wide.
        let rect = Tile(zoom: 12, x: 2146, y: 1391).rect
        #expect(TileMath.zoom(for: rect, pixelWidth: 256, maxZoom: 19) == 12)
        #expect(TileMath.zoom(for: rect, pixelWidth: 1024, maxZoom: 19) == 14)
        #expect(TileMath.zoom(for: rect, pixelWidth: 1024, maxZoom: 13) == 13)
        #expect(TileMath.zoom(for: MercatorRect(minX: 0, minY: 0, maxX: 0, maxY: 0), pixelWidth: 500, maxZoom: 17) == 0)
    }

    @Test("Tiles cover the rectangle, row by row from the north-west")
    func covering() {
        let bounds = GeoBounds(minLatitude: 49.80, maxLatitude: 49.90, minLongitude: 8.60, maxLongitude: 8.75)
        let rect = MercatorRect(bounds)
        let tiles = TileMath.tiles(covering: rect, zoom: 13)
        #expect(tiles.first == Tile(containing: MercatorPoint(x: rect.minX, y: rect.minY), zoom: 13))
        #expect(tiles.last == Tile(containing: MercatorPoint(x: rect.maxX, y: rect.maxY), zoom: 13))
        let columns = Set(tiles.map(\.x)).count, rows = Set(tiles.map(\.y)).count
        #expect(tiles.count == columns * rows)
        #expect(tiles[1].x == tiles[0].x + 1 && tiles[1].y == tiles[0].y)
    }

    @Test("Positions count from the top left: north is up")
    func position() {
        let bounds = GeoBounds(minLatitude: 49.80, maxLatitude: 49.90, minLongitude: 8.60, maxLongitude: 8.75)
        let rect = MercatorRect(bounds)
        let northWest = TileMath.position(of: MercatorPoint(RoutePoint(latitude: 49.90, longitude: 8.60)), in: rect, width: 400, height: 300)
        let southEast = TileMath.position(of: MercatorPoint(RoutePoint(latitude: 49.80, longitude: 8.75)), in: rect, width: 400, height: 300)
        #expect(abs(northWest.x) < 1e-9 && abs(northWest.y) < 1e-9)
        #expect(abs(southEast.x - 400) < 1e-9 && abs(southEast.y - 300) < 1e-9)
        let middle = TileMath.position(of: MercatorPoint(darmstadt), in: rect, width: 400, height: 300)
        #expect(middle.y < 150)  // Darmstadt (49.87°) lies in the northern half.
    }

    @Test("Tile addresses: zoom, column, row and a fixed subdomain per tile")
    func addresses() {
        let tile = Tile(zoom: 13, x: 4292, y: 2782)
        #expect(TileSource.openStreetMap.url(for: tile).absoluteString == "https://tile.openstreetmap.org/13/4292/2782.png")
        #expect(TileSource.openTopoMap.url(for: tile).absoluteString == "https://a.tile.opentopomap.org/13/4292/2782.png")
        #expect(TileSource.cyclOSM.url(for: tile) == TileSource.cyclOSM.url(for: tile))
        #expect(TileSource.cyclOSM.url(for: tile).absoluteString.hasPrefix("https://"))
        #expect(Set(TileSource.all.map(\.id)).count == TileSource.all.count)
        #expect(TileSource.all.allSatisfy { !$0.attribution.isEmpty && $0.maxZoom >= 17 })
    }
}
