import AppKit
import MapKit
import WattspurKit
import WattspurMap

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

    /// The tiles of `rect` at twice the resolution of the image, made pale like on screen
    /// (`TileMosaic` in the package), with the server's credit in the corner.
    private static func tiles(_ source: TileSource, rect: MKMapRect, size: CGSize) async -> MapBackdrop? {
        let scale = 2.0
        guard let mosaic = await TileMosaic.make(source, rect: rect, pixelWidth: Int(size.width * scale),
                                                 pixelHeight: Int(size.height * scale)) else { return nil }
        let image = NSImage(size: size)
        image.lockFocusFlipped(true)
        NSImage(cgImage: mosaic.image, size: size).draw(in: CGRect(origin: .zero, size: size))
        drawCredit(source.attribution, in: size)
        image.unlockFocus()
        return MapBackdrop(image: image) { mosaic.point(for: $0, in: size) }
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
