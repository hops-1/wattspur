import CoreGraphics
import MapKit
import Testing
@testable import WattspurCore
@testable import WattspurMap

/// What the renderers draw (B-360, S-32): the route of a ride, compared routes, the map of all
/// rides, curvy roads and muted tiles, each into a small image as MapKit would ask for a tile.
@Suite("Map drawing")
struct MapDrawingTests {
    private let colors = RouteColors(accent: CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
                                     noHeight: CGColor(gray: 0.5, alpha: 1))
    private let size = 128

    /// About 4 km, a point every 70 m, so no stretch counts as a gap in the track (B-309).
    private let route: [CLLocationCoordinate2D] = (0...60).map { (i: Int) -> CLLocationCoordinate2D in
        let step: Double = i < 30 ? Double(i) : Double(60 - i)
        return CLLocationCoordinate2D(latitude: 49.80 + Double(i) * 0.0005, longitude: 8.60 + step * 0.0008)
    }

    /// The pixels of the image after `renderer` drew `mapRect` into it.
    private func pixels(_ renderer: MKOverlayRenderer, _ mapRect: MKMapRect) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: size * size * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                                    bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            let zoomScale = CGFloat(size) / mapRect.width
            let area = renderer.rect(for: mapRect)
            context.scaleBy(x: zoomScale, y: zoomScale)
            context.translateBy(x: -area.minX, y: -area.minY)
            renderer.draw(mapRect, zoomScale: MKZoomScale(zoomScale), in: context)
        }
        return data
    }

    /// How many pixels got any paint.
    private func painted(_ data: [UInt8]) -> Int {
        stride(from: 3, to: data.count, by: 4).filter { data[$0] > 0 }.count
    }

    /// How many pixels are mostly `channel` (0 red, 1 green, 2 blue).
    private func mostly(_ channel: Int, _ data: [UInt8]) -> Int {
        stride(from: 0, to: data.count, by: 4).filter { i in
            data[i + channel] > 150 && (0..<3).allSatisfy { $0 == channel || data[i + $0] < 100 }
        }.count
    }

    private func isWorld(_ rect: MKMapRect) -> Bool { MKMapRectEqualToRect(rect, .world) }

    private func square(around coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        let rect = MKMapRect(covering: coordinates)
        let side = max(rect.width, rect.height) * 1.4
        return MKMapRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    }

    @Test("Every overlay of the package gets its renderer")
    func renderers() {
        let routeOverlay = RideRouteOverlay(segments: [route], colouring: .plain, dark: false, colors: colors)
        #expect(MapRenderers.renderer(for: routeOverlay) is RideRouteRenderer)
        #expect(MapRenderers.renderer(for: CachingTileOverlay(source: .cyclOSM)) is MutedTileRenderer)
        #expect(MapRenderers.renderer(for: CurvyRoadsOverlay(set: CurvyRoadSet(roads: []), dark: true)) is CurvyRoadsRenderer)
        let style = RidesMapStyle(rides: [], highlighted: [], dark: false, highlightColor: { _ in colors.accent },
                                  highlightDash: { _ in [] }, accent: colors.accent)
        #expect(MapRenderers.renderer(for: RidesMapOverlay(style: style)) is RidesMapRenderer)
        #expect(MapRenderers.renderer(for: ComparisonRoutesOverlay(lines: [])) is ComparisonRoutesRenderer)
        #expect(type(of: MapRenderers.renderer(for: MKCircle(center: route[0], radius: 10))) == MKOverlayRenderer.self)
    }

    @Test("The route is drawn in the accent colour, in pieces, with new stretches and ticks")
    func rideRoute() {
        let area = square(around: route)
        let plain = RideRouteOverlay(route: route, newStretches: [], colouring: .plain, ticks: [], dark: false, colors: colors)
        #expect(plain.boundingMapRect.contains(MKMapPoint(route[1])))
        let plainPixels = pixels(RideRouteRenderer(overlay: plain), area)
        #expect(mostly(2, plainPixels) > 50)

        let curves = [CurvatureAnalyzer.Piece(kind: .tight, points: route.map { .init(latitude: $0.latitude, longitude: $0.longitude) })]
        let coloured = RideRouteOverlay(segments: [route], colouring: .curves(curves), dark: false, colors: colors, flatEnds: true)
        let colouredPixels = pixels(RideRouteRenderer(overlay: coloured), area)
        #expect(mostly(0, colouredPixels) > 50)
        #expect(mostly(2, colouredPixels) == 0)

        let new = [route.prefix(2).map { RoutePoint(latitude: $0.latitude, longitude: $0.longitude) }]
        let ticks = [JoinTick(coordinate: route[1], heading: 45)]
        let full = RideRouteOverlay(route: route, newStretches: new, colouring: .plain, ticks: ticks, dark: true, colors: colors)
        #expect(painted(pixels(RideRouteRenderer(overlay: full), area)) >= painted(plainPixels))

        let empty = RideRouteOverlay(segments: [], colouring: .plain, dark: false, colors: colors)
        #expect(isWorld(empty.boundingMapRect))
        // A renderer handed another overlay draws nothing.
        #expect(painted(pixels(RideRouteRenderer(overlay: MKCircle(center: route[0], radius: 10)), area)) == 0)
    }

    @Test("Compared routes are drawn in their colours; one point is no line")
    func comparison() throws {
        let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let line = try #require(ComparisonRoutesOverlay.Line(coordinates: route, color: red, dash: [4, 2]))
        #expect(ComparisonRoutesOverlay.Line(coordinates: [route[0]], color: red, dash: []) == nil)
        let overlay = ComparisonRoutesOverlay(lines: [line])
        #expect(overlay.routesRect.contains(MKMapPoint(route[2])))
        #expect(mostly(0, pixels(ComparisonRoutesRenderer(overlay: overlay), square(around: route))) > 20)
        #expect(isWorld(ComparisonRoutesOverlay(lines: []).boundingMapRect))
    }

    private func mapRide(_ name: String) throws -> MapRide {
        let points = route.map { RoutePoint(latitude: $0.latitude, longitude: $0.longitude) }
        let figures = RideFigures(startDate: Date(timeIntervalSince1970: 0), distance: 5000, timerTime: 900)
        return try #require(MapRide(id: UUID(), name: name, figures: figures, route: OverviewRoute(segments: [points])))
    }

    @Test("The map of all rides draws lines, the heat map, or only the rides that stand out")
    func ridesMap() throws {
        let rides = [try mapRide("A"), try mapRide("B")]
        let green = CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
        let lines = RidesMapStyle(rides: rides, highlighted: [rides[0].id], dark: false, highlightColor: { _ in green },
                                  highlightDash: { _ in [] }, accent: colors.accent)
        let overlay = RidesMapOverlay(style: lines)
        let area = square(around: route)
        let linePixels = pixels(RidesMapRenderer(overlay: overlay), area)
        #expect(mostly(1, linePixels) > 20)

        let only = pixels(RidesMapRenderer(overlay: RidesMapOverlay(style: lines.onlyHighlights(true))), area)
        #expect(painted(only) > 0)
        #expect(painted(only) <= painted(linePixels))

        let heat = RidesMapStyle(rides: rides, highlighted: [], mode: .heat, dark: true, highlightColor: { _ in green },
                                 highlightDash: { _ in [] }, accent: colors.accent)
        #expect(painted(pixels(RidesMapRenderer(overlay: RidesMapOverlay(style: heat)), area)) > 0)
        #expect(isWorld(RidesMapOverlay(style: RidesMapStyle(rides: [], highlighted: [], dark: false, highlightColor: { _ in green },
                                                     highlightDash: { _ in [] }, accent: green)).boundingMapRect))

        let one = RidesMapStyle.legendOpacity(rides: 1)
        #expect(abs(one.thin - Double(RidesMapStyle.thinAlpha)) < 1e-9)
        #expect(RidesMapStyle.legendOpacity(rides: 5).thin > one.thin)
        #expect(RidesMapStyle.Mode.allCases.map(\.id) == [.lines, .heat])
    }

    @Test("Curvy roads are drawn near enough, very curvy ones in red, and not when zoomed out")
    func curvyRoads() {
        let curvy = CurvyRoad(name: "Kurvig", curvature: 500, length: 3000,
                              coordinates: route.flatMap { [Float($0.latitude), Float($0.longitude)] })
        let veryCurvy = CurvyRoad(name: "Sehr kurvig", curvature: 1500, length: 3000,
                                  coordinates: route.flatMap { [Float($0.latitude + 0.005), Float($0.longitude)] })
        let set = CurvyRoadSet(roads: [curvy, veryCurvy])
        #expect(set.nearest(latitude: route[30].latitude, longitude: route[30].longitude, within: 200)?.name == "Kurvig")
        #expect(set.nearest(latitude: 10, longitude: 10, within: 200) == nil)
        #expect(curvy.coordinates2D.count == route.count)

        let overlay = CurvyRoadsOverlay(set: set, dark: false)
        #expect(isWorld(overlay.boundingMapRect))
        let near = pixels(CurvyRoadsRenderer(overlay: overlay), square(around: route))
        #expect(painted(near) > 50)
        #expect(mostly(0, near) > 0)

        let far = MKMapRect(x: 0, y: 0, width: MKMapSize.world.width / 4, height: MKMapSize.world.width / 4)
        #expect(painted(pixels(CurvyRoadsRenderer(overlay: overlay), far)) == 0)
    }

    @Test("Muting takes colour out and lays a veil over it")
    func mute() {
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            MutedTileRenderer.mute(CGRect(x: 0, y: 0, width: 1, height: 1), in: context)
        }
        // Red stays the strongest, but paler and less colourful.
        #expect(pixel[0] > 150 && pixel[0] < 255)
        #expect(pixel[1] > 60 && pixel[2] > 60 && pixel[1] < pixel[0])
        let renderer = MutedTileRenderer.make(for: CachingTileOverlay(source: .openStreetMap))
        #expect(renderer.overlay is CachingTileOverlay)
    }

    @MainActor
    @Test("A map shows the tiles of an OpenStreetMap style below its own overlays, Apple's maps without")
    func showMapType() {
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let own = RideRouteOverlay(segments: [route], colouring: .plain, dark: false, colors: colors)
        map.addOverlay(own)
        #expect(map.drawnOverlayLevel == .aboveRoads)

        map.show(.cyclOSM)
        #expect(map.overlays.compactMap { $0 as? CachingTileOverlay }.map(\.source) == [.cyclOSM])
        #expect(map.drawnOverlays.count == 1)
        #expect(map.drawnOverlayLevel == .aboveLabels)
        // The same style again changes nothing.
        let tiles = map.overlays.first { $0 is CachingTileOverlay }
        map.show(.cyclOSM, muted: true)
        #expect(map.overlays.first { $0 is CachingTileOverlay } === tiles)

        map.show(.openTopoMap)
        #expect(map.overlays.compactMap { $0 as? CachingTileOverlay }.map(\.source) == [.openTopoMap])

        for type in [RideMapType.satellite, .hybrid, .standard] {
            map.show(type, muted: type == .standard)
            #expect(!map.overlays.contains { $0 is CachingTileOverlay })
            #expect(map.drawnOverlays.count == 1)
        }
        #expect(map.preferredConfiguration is MKStandardMapConfiguration)

        map.setRegion(MKCoordinateRegion(center: route[0], latitudinalMeters: 2000, longitudinalMeters: 3000), animated: false)
        let reach = map.metres(across: 30, at: CGPoint(x: 150, y: 100))
        #expect(reach.metres > 0)
    }
}
