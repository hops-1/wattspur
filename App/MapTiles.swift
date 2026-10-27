import AppKit
import MapKit
import SwiftUI
import WattspurKit

// Map styles from OpenStreetMap tile servers on the app's maps (B-061, MAP-02). The servers'
// terms are in docs/RECHERCHE-KARTEN.md: our own User-Agent, the credit on the map, caching by
// the HTTP headers and only the tiles that are on screen, never prefetched.

/// Loads tiles for all maps and the PDF through one session with a disk cache.
enum TileLoader {
    /// "Wattspur/1.8.0 (+https://github.com/hops-1/wattspur)"
    static let userAgent = "Wattspur/\(AppInfo.version) (+https://github.com/hops-1/wattspur)"

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let directory = URL.cachesDirectory.appending(path: "Tiles", directoryHint: .isDirectory)
        configuration.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 300 << 20, directory: directory)
        // Fresh tiles come from the cache; the servers say how long a tile stays fresh.
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        // The volunteer servers ask for restraint.
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    /// The tile's image data. Without a network a tile seen before still comes from the
    /// cache, even when the server would want it checked again.
    static func data(for tile: Tile, from source: TileSource) async throws -> Data {
        let url = source.url(for: tile)
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            return data
        } catch {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataDontLoad
            let (data, _) = try await session.data(for: request)
            guard !data.isEmpty else { throw error }
            return data
        }
    }
}

/// The tiles of one `TileSource` instead of Apple's map. Beyond the server's highest zoom
/// it enlarges the matching part of the last tile, so the map does not turn blank.
final class CachingTileOverlay: MKTileOverlay, @unchecked Sendable {
    let source: TileSource

    init(source: TileSource) {
        self.source = source
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: source.tileSize, height: source.tileSize)
        maximumZ = 21
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        source.url(for: Tile(zoom: min(path.z, source.maxZoom), x: path.x >> max(0, path.z - source.maxZoom),
                             y: path.y >> max(0, path.z - source.maxZoom)))
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping @Sendable (Data?, (any Error)?) -> Void) {
        let source = source
        Task {
            do {
                let steps = max(0, path.z - source.maxZoom)
                let parent = Tile(zoom: path.z - steps, x: path.x >> steps, y: path.y >> steps)
                let data = try await TileLoader.data(for: parent, from: source)
                result(steps == 0 ? data : Self.enlarge(data, steps: steps, x: path.x, y: path.y, size: source.tileSize), nil)
            } catch {
                result(nil, error)
            }
        }
    }

    /// The part of a parent tile that a tile `steps` zoom levels deeper covers, scaled up.
    private static func enlarge(_ data: Data, steps: Int, x: Int, y: Int, size: Int) -> Data? {
        guard let image = NSBitmapImageRep(data: data)?.cgImage else { return nil }
        let parts = 1 << steps
        let part = CGFloat(image.width) / CGFloat(parts)
        let crop = CGRect(x: CGFloat(x % parts) * part, y: CGFloat(y % parts) * part, width: part, height: part)
        guard let piece = image.cropping(to: crop.integral),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(piece, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage().flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
    }
}

/// Draws the tiles paler and less colourful, so the routes stand out on them like on Apple's
/// muted map (wish of Nils after testing 1.8, 27.10.2026). Only on screen; the PDF does the same.
final class MutedTileRenderer: MKTileOverlayRenderer {
    /// How much colour is taken out, 0 … 1.
    static let desaturation: CGFloat = 0.45
    /// How strong the white veil over the tiles is, 0 … 1.
    static let veil: CGFloat = 0.3

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        let rect = self.rect(for: mapRect)
        context.saveGState()
        context.setBlendMode(.saturation)
        context.setFillColor(CGColor(gray: 0.5, alpha: Self.desaturation))
        context.fill(rect)
        context.setBlendMode(.normal)
        context.setFillColor(CGColor(gray: 1, alpha: Self.veil))
        context.fill(rect)
        context.restoreGState()
    }
}

extension MKMapView {
    /// Shows `mapType`: Apple's configuration, and for an OpenStreetMap style its tiles
    /// below the app's own overlays. Points of interest stay off; the filter must sit on
    /// the configuration, which overrides the map view's own (B-132).
    func show(_ mapType: RideMapType, muted: Bool = false) {
        switch mapType {
        case .satellite:
            preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        case .hybrid:
            let configuration = MKHybridMapConfiguration(elevationStyle: .realistic)
            configuration.pointOfInterestFilter = .excludingAll
            preferredConfiguration = configuration
        case .standard, .openStreetMap, .cyclOSM, .openTopoMap:
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: muted ? .muted : .default)
            configuration.pointOfInterestFilter = .excludingAll
            preferredConfiguration = configuration
        }
        let current = overlays.compactMap { $0 as? CachingTileOverlay }
        guard current.map(\.source) != [mapType.tileSource].compactMap({ $0 }) else { return }
        // Apple draws its place names above the roads level even when tiles replace its map,
        // so they showed twice beside the tiles' own names at some zooms. The tiles therefore lie
        // above the labels, and the app's own overlays move along to stay on top of them.
        let drawn = drawnOverlays
        removeOverlays(current + drawn)
        if let source = mapType.tileSource {
            addOverlay(CachingTileOverlay(source: source), level: .aboveLabels)
        }
        addOverlays(drawn, level: drawnOverlayLevel)
    }

    /// The app's own overlays, without the tiles, to replace them.
    var drawnOverlays: [any MKOverlay] { overlays.filter { !($0 is CachingTileOverlay) } }

    /// Where the app's own overlays go: above the roads on Apple's maps, as before, and above
    /// the tiles on an OpenStreetMap style.
    var drawnOverlayLevel: MKOverlayLevel {
        overlays.contains { $0 is CachingTileOverlay } ? .aboveLabels : .aboveRoads
    }
}

/// The credit a tile server asks for, at the bottom right of the map; always visible.
struct TileAttribution: View {
    let source: TileSource

    var body: some View {
        Link(destination: source.attributionURL) {
            Text(verbatim: source.attribution)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        .help(Text("Map data and style: open the licence"))
        .accessibilityLabel(Text(verbatim: source.attribution))
    }
}

extension View {
    /// Puts the credit of an OpenStreetMap style on the map.
    func tileAttribution(for mapType: RideMapType) -> some View {
        overlay(alignment: .bottomTrailing) {
            if let source = mapType.tileSource {
                TileAttribution(source: source)
                    .frame(maxWidth: 360, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
            }
        }
    }
}
