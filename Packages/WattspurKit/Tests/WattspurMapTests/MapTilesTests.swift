import CoreGraphics
import Foundation
import MapKit
import Synchronization
import Testing
@testable import WattspurCore
@testable import WattspurMap

/// A tile server in the test process: answers with what `respond` gives and counts the requests.
final class FakeTileServer: URLProtocol {
    struct Reply: Sendable {
        var status: Int
        var data: Data
        var headers: [String: String] = ["Cache-Control": "max-age=86400", "Content-Type": "image/png"]
    }

    /// `nil` fails like a network without connection.
    nonisolated(unsafe) static var respond: @Sendable (URLRequest) -> Reply? = { _ in nil }
    static let requests = Mutex<[URLRequest]>([])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // "Only from the cache" never reaches a server; a protocol of its own has to do that itself.
        if request.cachePolicy == .returnCacheDataDontLoad {
            if let cachedResponse {
                client?.urlProtocol(self, didReceive: cachedResponse.response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: cachedResponse.data)
                client?.urlProtocolDidFinishLoading(self)
            } else {
                client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            }
            return
        }
        Self.requests.withLock { $0.append(request) }
        guard let reply = Self.respond(request), let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1",
                                             headerFields: reply.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: reply.status == 200 ? .allowed : .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// A session like the app's, with this server and a cache in a new folder.
    static func session() -> (URLSession, URL) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "WattspurTiles-\(UUID().uuidString)")
        let configuration = TileLoader.configuration(cacheDirectory: folder)
        configuration.protocolClasses = [FakeTileServer.self]
        requests.withLock { $0.removeAll() }
        return (URLSession(configuration: configuration), folder)
    }
}

/// The tiles of the OpenStreetMap styles (B-360, S-32): addresses, the User-Agent the servers ask
/// for, the cache, the deeper zooms and the tiles of the PDF.
@Suite("Map tiles", .serialized)
struct MapTilesTests {
    /// A square PNG in one colour.
    static func png(_ color: CGColor, size: Int = 256) -> Data {
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return TileImage.png(context.makeImage()!)!
    }

    static let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

    @Test("Each style has its own tile address; the subdomain follows from the tile")
    func addresses() {
        let tile = Tile(zoom: 12, x: 2140, y: 1393)
        #expect(TileSource.openStreetMap.url(for: tile).absoluteString == "https://tile.openstreetmap.org/12/2140/1393.png")
        #expect(TileSource.cyclOSM.url(for: tile).absoluteString
            == "https://\(["a", "b", "c"][(2140 + 1393) % 3]).tile-cyclosm.openstreetmap.fr/cyclosm/12/2140/1393.png")
        #expect(TileSource.openTopoMap.url(for: tile).absoluteString.hasSuffix(".tile.opentopomap.org/12/2140/1393.png"))
        // The same tile always has the same address, so the cache finds it again.
        #expect(TileSource.cyclOSM.url(for: tile) == TileSource.cyclOSM.url(for: tile))
        #expect(TileSource.cyclOSM.url(for: tile) != TileSource.cyclOSM.url(for: Tile(zoom: 12, x: 2141, y: 1393)))
        #expect(Set(TileSource.all.map(\.id)) == ["osm", "cyclosm", "opentopomap"])
    }

    @Test("Beyond the server's highest zoom the overlay asks for the parent tile")
    func deeperZoom() {
        let overlay = CachingTileOverlay(source: .openTopoMap)
        #expect(overlay.canReplaceMapContent)
        #expect(overlay.tileSize == CGSize(width: 256, height: 256))
        #expect(overlay.maximumZ == 21)
        let within = overlay.url(forTilePath: MKTileOverlayPath(x: 100, y: 200, z: 17, contentScaleFactor: 2))
        #expect(within == TileSource.openTopoMap.url(for: Tile(zoom: 17, x: 100, y: 200)))
        let beyond = overlay.url(forTilePath: MKTileOverlayPath(x: 403, y: 805, z: 19, contentScaleFactor: 2))
        #expect(beyond == TileSource.openTopoMap.url(for: Tile(zoom: 17, x: 100, y: 201)))
    }

    @Test("Every tile request carries Wattspur's own User-Agent and the session is restrained")
    func userAgent() async throws {
        #expect(TileLoader.userAgent == "Wattspur/\(AppInfo.version) (+https://github.com/hops-1/wattspur)")
        let configuration = TileLoader.configuration(cacheDirectory: FileManager.default.temporaryDirectory)
        #expect(configuration.httpAdditionalHeaders?["User-Agent"] as? String == TileLoader.userAgent)
        #expect(configuration.httpMaximumConnectionsPerHost == 4)
        #expect(configuration.requestCachePolicy == .useProtocolCachePolicy)
        #expect(configuration.urlCache?.diskCapacity == 300 << 20)

        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = Self.png(Self.red)
        FakeTileServer.respond = { _ in .init(status: 200, data: image) }
        let data = try await TileLoader.data(for: Tile(zoom: 3, x: 1, y: 2), from: .openStreetMap, session: session)
        #expect(data == image)
        let sent = FakeTileServer.requests.withLock { $0 }
        #expect(sent.count == 1)
        #expect(sent.first?.url == TileSource.openStreetMap.url(for: Tile(zoom: 3, x: 1, y: 2)))
        #expect(sent.first?.value(forHTTPHeaderField: "User-Agent") == TileLoader.userAgent)
    }

    @Test("Without a network a tile seen before comes from the cache, an unknown one fails")
    func offlineFromCache() async throws {
        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        let tile = Tile(zoom: 5, x: 16, y: 10)
        let url = TileSource.cyclOSM.url(for: tile)
        let image = Self.png(Self.red)
        // As if the tile had been loaded before; the server would want it checked again.
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Cache-Control": "max-age=0"])!
        session.configuration.urlCache?.storeCachedResponse(CachedURLResponse(response: response, data: image),
                                                            for: URLRequest(url: url))
        FakeTileServer.respond = { _ in nil }
        let cached = try await TileLoader.data(for: tile, from: .cyclOSM, session: session)
        #expect(cached == image)

        await #expect(throws: (any Error).self) {
            try await TileLoader.data(for: Tile(zoom: 5, x: 17, y: 10), from: .cyclOSM, session: session)
        }
    }

    @Test("A server error is not taken for a tile")
    func serverError() async {
        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        FakeTileServer.respond = { _ in .init(status: 503, data: Data("busy".utf8), headers: [:]) }
        await #expect(throws: (any Error).self) {
            try await TileLoader.data(for: Tile(zoom: 2, x: 1, y: 1), from: .openStreetMap, session: session)
        }
    }

    @Test("A stored error answer is not taken for a tile without a network")
    func cachedError() async {
        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        let tile = Tile(zoom: 6, x: 33, y: 21)
        let url = TileSource.openStreetMap.url(for: tile)
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!
        session.configuration.urlCache?.storeCachedResponse(CachedURLResponse(response: response, data: Data("gone".utf8)),
                                                            for: URLRequest(url: url))
        FakeTileServer.respond = { _ in nil }
        await #expect(throws: (any Error).self) {
            try await TileLoader.data(for: tile, from: .openStreetMap, session: session)
        }
    }

    @Test("Simulated offline, every tile fails without asking the server")
    func simulatedOffline() async {
        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        FakeTileServer.respond = { _ in .init(status: 200, data: Data([1])) }
        TileLoader.simulatesOffline = true
        defer { TileLoader.simulatesOffline = false }
        await #expect(throws: URLError.self) {
            try await TileLoader.data(for: Tile(zoom: 1, x: 0, y: 0), from: .openStreetMap, session: session)
        }
        #expect(FakeTileServer.requests.withLock { $0.isEmpty })
    }

    /// Asks the overlay for one tile and waits for the answer.
    private func load(_ overlay: CachingTileOverlay, _ path: MKTileOverlayPath) async -> (Data?, Bool) {
        await withCheckedContinuation { continuation in
            overlay.loadTile(at: path) { data, error in continuation.resume(returning: (data, error != nil)) }
        }
    }

    @Test("The overlay hands over a tile, enlarges the parent beyond the highest zoom and tries twice")
    func overlayLoads() async throws {
        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        let overlay = CachingTileOverlay(source: .openStreetMap)
        overlay.session = session
        overlay.retryDelay = .milliseconds(10)
        let image = Self.png(Self.red)
        FakeTileServer.respond = { _ in .init(status: 200, data: image) }

        let (plain, plainFailed) = await load(overlay, MKTileOverlayPath(x: 1, y: 1, z: 2, contentScaleFactor: 2))
        #expect(plain == image && !plainFailed)

        let (enlarged, enlargedFailed) = await load(overlay, MKTileOverlayPath(x: 5, y: 3, z: 21, contentScaleFactor: 2))
        #expect(!enlargedFailed)
        let decoded = try #require(enlarged.flatMap(TileImage.decode))
        #expect(decoded.width == 256)
        #expect(FakeTileServer.requests.withLock { $0.last?.url }
            == TileSource.openStreetMap.url(for: Tile(zoom: 19, x: 1, y: 0)))

        FakeTileServer.respond = { _ in nil }
        FakeTileServer.requests.withLock { $0.removeAll() }
        let (none, failed) = await load(overlay, MKTileOverlayPath(x: 7, y: 7, z: 4, contentScaleFactor: 2))
        #expect(none == nil && failed)
        #expect(FakeTileServer.requests.withLock { $0.count } == 2)
    }

    @Test("The PDF's tiles make one image of the area, or nothing with a hole or too many tiles")
    func mosaic() async throws {
        let (session, folder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = Self.png(Self.red)
        FakeTileServer.respond = { _ in .init(status: 200, data: image) }
        let rect = MKMapRect(covering: [CLLocationCoordinate2D(latitude: 49.8, longitude: 8.6),
                                        CLLocationCoordinate2D(latitude: 49.9, longitude: 8.8)])
        let size = CGSize(width: 400, height: 300)
        let mosaic = try #require(await TileMosaic.make(.openStreetMap, rect: rect, pixelWidth: 400, pixelHeight: 300,
                                                        session: session))
        #expect(mosaic.image.width == 400 && mosaic.image.height == 300)
        // The corners of the area land on the corners of the image.
        let topLeft = mosaic.point(for: MKMapPoint(x: rect.minX, y: rect.minY).coordinate, in: size)
        #expect(abs(topLeft.x) < 0.5 && abs(topLeft.y) < 0.5)
        let bottomRight = mosaic.point(for: MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate, in: size)
        #expect(abs(bottomRight.x - 400) < 0.5 && abs(bottomRight.y - 300) < 0.5)

        // One tile missing: no image with a hole.
        let missing = FakeTileServer.requests.withLock { $0.first?.url }
        FakeTileServer.respond = { request in request.url == missing ? nil : .init(status: 200, data: image) }
        let (fresh, freshFolder) = FakeTileServer.session()
        defer { try? FileManager.default.removeItem(at: freshFolder) }
        #expect(await TileMosaic.make(.openStreetMap, rect: rect, pixelWidth: 400, pixelHeight: 300, session: fresh) == nil)

        // The whole world in detail would be a bulk download.
        #expect(await TileMosaic.make(.openStreetMap, rect: .world, pixelWidth: 8000, pixelHeight: 8000,
                                      session: session) == nil)
    }
}
