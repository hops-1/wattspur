import CoreGraphics
import MapKit
import Testing
@testable import WattspurCore
@testable import WattspurMap

/// The map parts both apps share (B-186): what used to be drawn in the Mac app is drawn the same way here.
@Suite("Maps")
struct WattspurMapTests {
    private let colors = RouteColors(accent: CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
                                     noHeight: CGColor(gray: 0.5, alpha: 1))

    private func hex(_ color: CGColor) -> UInt32 {
        let c = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components ?? []
        return c.prefix(3).reduce(0) { $0 << 8 | UInt32(($1 * 255).rounded()) }
    }

    @Test("The stored map types keep their raw values and tile servers")
    func mapTypes() {
        #expect(RideMapType.allCases.map(\.rawValue) == ["standard", "satellite", "hybrid", "osm", "cyclosm", "opentopomap"])
        #expect(RideMapType.apple.allSatisfy { $0.tileSource == nil })
        #expect(RideMapType.openTopoMap.tileSource == .openTopoMap)
        #expect(RideMapType.cyclOSM.tileSource == .cyclOSM)
    }

    @Test("The palette has the Mac's colours for both appearances")
    func palette() {
        #expect(MapPalette.curve(.tight) == .init(light: 0xC81D25, dark: 0xFF5A5F))
        #expect(MapPalette.lean(.extreme).hex(dark: true) == 0xC08BFF)
        #expect(MapPalette.surface(.uneven).hex(dark: false) == 0xF59F00)
        #expect(MapPalette.newPaths == .init(light: 0xC2410C, dark: 0xFF8A4C))
        #expect(MapPalette.elevation(-3) == RouteElevation.palette.first)
        #expect(MapPalette.elevation(99) == RouteElevation.palette.last)
        #expect(hex(MapPalette.curvyRoad(veryCurvy: true).cgColor(dark: false)) == 0xD7263D)
    }

    @Test("Only one colouring at a time, in the order of the ride's map")
    func colouringOrder() {
        let lean = [RideMotion.LeanStretch(band: .slight, latitude: [50, 50.1], longitude: [8, 8.1])]
        let height = [RouteElevation.Stretch(band: 2, latitude: [50, 50.1], longitude: [8, 8.1])]
        let curves = [CurvatureAnalyzer.Piece(kind: .tight, points: [.init(latitude: 50, longitude: 8), .init(latitude: 50.1, longitude: 8.1)])]
        guard case .lean = RouteColouring.first(curves: [], lean: lean, surface: [], elevation: height) else {
            Issue.record("lean comes before height"); return
        }
        guard case .curves = RouteColouring.first(curves: curves, lean: lean, surface: [], elevation: height) else {
            Issue.record("curves come first"); return
        }
        guard case .plain = RouteColouring.first(curves: [], lean: [], surface: [], elevation: []) else {
            Issue.record("nothing is plain"); return
        }
        #expect(RouteColouring.lean(lean).key != RouteColouring.elevation(height).key)
    }

    @Test("Pieces get the palette's colours, a stretch without height the app's grey")
    func colouringPieces() {
        let height = [RouteElevation.Stretch(band: 0, latitude: [50, 50.1], longitude: [8, 8.1]),
                      RouteElevation.Stretch(band: nil, latitude: [50.1, 50.2], longitude: [8.1, 8.2])]
        let pieces = RouteColouring.elevation(height).pieces(dark: false, colors: colors)
        #expect(pieces.count == 2)
        #expect(hex(pieces[0].color) == RouteElevation.palette[0])
        #expect(pieces[1].color == colors.noHeight)
        #expect(pieces[1].coordinates.last?.latitude == 50.2)
        let lean = RouteColouring.lean([RideMotion.LeanStretch(band: .strong, latitude: [1, 2], longitude: [3, 4])])
        #expect(hex(lean.pieces(dark: true, colors: colors)[0].color) == 0xFF5A5F)
        #expect(RouteColouring.plain.pieces(dark: false, colors: colors).isEmpty)
    }

    @Test("A tick lies across the direction of travel")
    func tickAcross() {
        let north = JoinTick(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 8), heading: 0).across
        #expect(abs(north.dx - 1) < 1e-9 && abs(north.dy) < 1e-9)
        let east = JoinTick(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 8), heading: 90).across
        #expect(abs(east.dx) < 1e-9 && abs(east.dy - 1) < 1e-9)
    }

    @Test("Start and finish within 100 m make a loop")
    func loop() {
        let start = CLLocationCoordinate2D(latitude: 50, longitude: 8)
        #expect(RideMarker.isLoop([start, CLLocationCoordinate2D(latitude: 50.0005, longitude: 8)]))
        #expect(!RideMarker.isLoop([start, CLLocationCoordinate2D(latitude: 50.01, longitude: 8)]))
        #expect(!RideMarker.isLoop([]))
    }

    @Test("A rectangle covers its points and widens to the image's shape")
    func rectangles() {
        let rect = MKMapRect(covering: [MKMapPoint(x: 10, y: 20), MKMapPoint(x: 30, y: 60)])
        #expect(rect.minX == 10 && rect.minY == 20 && rect.width == 20 && rect.height == 40)
        #expect(MKMapRect(covering: [MKMapPoint]()).isNull)
        let wide = rect.fitted(to: CGSize(width: 200, height: 100))
        #expect(wide.height == 40 && wide.width == 80 && wide.midX == rect.midX)
        let tall = rect.fitted(to: CGSize(width: 100, height: 400))
        #expect(tall.width == 20 && tall.height == 80 && tall.midY == rect.midY)
    }

    @Test("A visible area becomes the same geographic rectangle")
    func geoBounds() {
        let rect = MKMapRect(covering: [MKMapPoint(CLLocationCoordinate2D(latitude: 49.8, longitude: 8.6)),
                                        MKMapPoint(CLLocationCoordinate2D(latitude: 50.1, longitude: 9.0))])
        let bounds = GeoBounds(rect)
        #expect(abs(bounds.minLatitude - 49.8) < 1e-6 && abs(bounds.maxLatitude - 50.1) < 1e-6)
        #expect(abs(bounds.minLongitude - 8.6) < 1e-6 && abs(bounds.maxLongitude - 9.0) < 1e-6)
    }

    /// A 4 × 4 image with a red top left quarter and blue elsewhere.
    private func quarters() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        // The context counts y from the bottom: the top left quarter.
        context.fill(CGRect(x: 0, y: 2, width: 2, height: 2))
        return context.makeImage()!
    }

    /// The colour in the middle of an image, as 0xRRGGBB.
    private func centre(_ image: CGImage) -> UInt32 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2 + 0.5, y: -CGFloat(image.height) / 2 + 0.5,
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return UInt32(pixel[0]) << 16 | UInt32(pixel[1]) << 8 | UInt32(pixel[2])
    }

    @Test("A deeper tile is the enlarged quarter of its parent, also after PNG and back")
    func enlargeTile() throws {
        let png = try #require(TileImage.png(quarters()))
        let parent = try #require(TileImage.decode(png))
        // One zoom deeper, tile (0, 0) is the top left quarter: red; tile (1, 1) the bottom right: blue.
        let topLeft = try #require(TileImage.enlarge(parent, steps: 1, x: 0, y: 0, size: 8))
        #expect(topLeft.width == 8)
        #expect(centre(topLeft) == 0xFF0000)
        let bottomRight = try #require(TileImage.enlarge(parent, steps: 1, x: 1, y: 1, size: 8))
        #expect(centre(bottomRight) == 0x0000FF)
    }

    @Test("The cursor is white in the middle; a marker has the given colour")
    func markerImages() throws {
        let cursor = try #require(RouteMarkerImage.cursor(scale: 2))
        #expect(cursor.width == 36)
        #expect(centre(cursor) == 0xFFFFFF)
        let marker = try #require(RouteMarkerImage.marker(color: CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1), scale: 2))
        #expect(marker.width == 44)
        #expect(centre(marker) == 0x00FF00)
    }

    @Test("The map of all rides colours highlighted and selected rides and fades the rest for a focus")
    func ridesStyle() throws {
        let route = OverviewRoute(segments: [[RoutePoint(latitude: 50, longitude: 8), RoutePoint(latitude: 50.01, longitude: 8.01)]])
        let figures = RideFigures(startDate: Date(timeIntervalSince1970: 0), distance: 1000, timerTime: 300)
        let a = try #require(MapRide(id: UUID(), name: "A", figures: figures, route: route))
        let b = try #require(MapRide(id: UUID(), name: "B", figures: figures, route: route))
        let c = try #require(MapRide(id: UUID(), name: "C", figures: figures, route: route))
        let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let style = RidesMapStyle(rides: [a, b, c], highlighted: [a.id], selected: [b.id], focused: nil, dark: false,
                                  highlightColor: { _ in red }, highlightDash: { _ in [2, 3] }, accent: colors.accent)
        #expect(style.lines[0].highlight?.color == red)
        #expect(style.lines[0].highlight?.dash == [2, 3])
        #expect(style.lines[1].highlight?.color == colors.accent)
        #expect(style.lines[2].highlight == nil)
        #expect(style.heatRides.map { $0.id } == [c.id])
        #expect(style.fade == 1)
        let focused = RidesMapStyle(rides: [a, b, c], highlighted: [], focused: c.id, dark: true,
                                    highlightColor: { _ in red }, highlightDash: { _ in [] }, accent: colors.accent)
        #expect(focused.fade < 1)
        #expect(focused.lines[2].highlight?.color == colors.accent)
        #expect(!style.boundingRect.isNull)
    }
}
