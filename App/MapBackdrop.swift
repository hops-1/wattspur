import AppKit
import MapKit
import WattspurKit

/// The map under the routes of a PDF (B-061d): Apple's snapshot or, for an OpenStreetMap style,
/// the server's tiles put together by the app, because `MKMapSnapshotter` draws no tile overlays.
/// Either way the routes go on top with `point(for:)`, counted from the top like the PDFs draw.
struct MapBackdrop {
    let image: NSImage
    let point: (CLLocationCoordinate2D) -> CGPoint

    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint { point(coordinate) }

    /// The map of `rect`, widened to the shape of `size` so nothing is distorted. An OpenStreetMap
    /// style falls back to Apple's standard map when its tiles cannot be loaded (offline).
    static func make(_ mapType: RideMapType, rect: MKMapRect, size: CGSize) async -> MapBackdrop? {
        let rect = rect.fitted(to: size)
        if let source = mapType.tileSource, let tiles = await tiles(source, rect: rect, size: size) {
            return tiles
        }
        return await apple(mapType, rect: rect, size: size)
    }

    private static func apple(_ mapType: RideMapType, rect: MKMapRect, size: CGSize) async -> MapBackdrop? {
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = size
        options.appearance = NSAppearance(named: .aqua)
        switch mapType {
        case .standard, .openStreetMap, .cyclOSM, .openTopoMap:
            let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
            configuration.pointOfInterestFilter = .excludingAll
            options.preferredConfiguration = configuration
        case .satellite: options.preferredConfiguration = MKImageryMapConfiguration()
        case .hybrid:
            let configuration = MKHybridMapConfiguration()
            configuration.pointOfInterestFilter = .excludingAll
            options.preferredConfiguration = configuration
        }
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return MapBackdrop(image: snapshot.image) { snapshot.topDownPoint(for: $0, height: size.height) }
    }

    /// Loads the tiles of `rect` at twice the resolution of the image, draws them, makes them pale
    /// like on screen (`MutedTileRenderer`) and puts the server's credit in the corner.
    private static func tiles(_ source: TileSource, rect: MKMapRect, size: CGSize) async -> MapBackdrop? {
        let world = MKMapSize.world.width
        let area = MercatorRect(minX: rect.minX / world, minY: rect.minY / world,
                                maxX: rect.maxX / world, maxY: rect.maxY / world)
        let scale = 2.0
        let pixels = (width: Int(size.width * scale), height: Int(size.height * scale))
        let zoom = TileMath.zoom(for: area, pixelWidth: Double(pixels.width), tileSize: source.tileSize, maxZoom: source.maxZoom)
        let needed = TileMath.tiles(covering: area, zoom: zoom)
        // A large area at a high zoom would be a bulk download, which the servers forbid.
        guard !needed.isEmpty, needed.count <= 200 else { return nil }
        let loaded = await withTaskGroup(of: (Tile, CGImage?).self) { group in
            for tile in needed {
                group.addTask {
                    let data = try? await TileLoader.data(for: tile, from: source)
                    return (tile, data.flatMap { NSBitmapImageRep(data: $0)?.cgImage })
                }
            }
            return await group.reduce(into: [(Tile, CGImage)]()) { result, item in
                if let image = item.1 { result.append((item.0, image)) }
            }
        }
        // A map with holes is worse than Apple's map.
        guard loaded.count == needed.count,
              let context = CGContext(data: nil, width: pixels.width, height: pixels.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        let full = CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height)
        for (tile, image) in loaded {
            let tileRect = tile.rect
            let topLeft = TileMath.position(of: MercatorPoint(x: tileRect.minX, y: tileRect.minY), in: area,
                                            width: Double(pixels.width), height: Double(pixels.height))
            let bottomRight = TileMath.position(of: MercatorPoint(x: tileRect.maxX, y: tileRect.maxY), in: area,
                                                width: Double(pixels.width), height: Double(pixels.height))
            // The context counts y from the bottom.
            context.draw(image, in: CGRect(x: topLeft.x, y: Double(pixels.height) - bottomRight.y,
                                           width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
        }
        context.setBlendMode(.saturation)
        context.setFillColor(CGColor(gray: 0.5, alpha: MutedTileRenderer.desaturation))
        context.fill(full)
        context.setBlendMode(.normal)
        context.setFillColor(CGColor(gray: 1, alpha: MutedTileRenderer.veil))
        context.fill(full)
        guard let map = context.makeImage() else { return nil }
        let image = NSImage(size: size)
        image.lockFocusFlipped(true)
        NSImage(cgImage: map, size: size).draw(in: CGRect(origin: .zero, size: size))
        drawCredit(source.attribution, in: size)
        image.unlockFocus()
        return MapBackdrop(image: image) { coordinate in
            let position = TileMath.position(of: MercatorPoint(RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)),
                                             in: area, width: size.width, height: size.height)
            return CGPoint(x: position.x, y: position.y)
        }
    }

    /// The server's credit at the bottom right, small on a white box; the licences ask for it.
    private static func drawCredit(_ text: String, in size: CGSize) {
        let string = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 7),
            .foregroundColor: NSColor.black,
        ])
        let bounds = string.boundingRect(with: CGSize(width: size.width - 16, height: 40), options: [.usesLineFragmentOrigin])
        let box = CGRect(x: size.width - bounds.width - 10, y: size.height - bounds.height - 6,
                         width: bounds.width + 6, height: bounds.height + 2)
        NSColor.white.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: box, xRadius: 2, yRadius: 2).fill()
        string.draw(with: box.insetBy(dx: 3, dy: 1), options: [.usesLineFragmentOrigin])
    }
}

extension MKMapRect {
    /// Widened to the shape of `size` around the same centre, so an image of that size is not distorted.
    func fitted(to size: CGSize) -> MKMapRect {
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
