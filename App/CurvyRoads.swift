import AppKit
import MapKit
import Observation
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

// The layer "Curvy roads" on the maps (B-183): roads from roadcurvature.com that the user has
// imported (B-182), drawn below the route in orange (from 300) and red (from 1000).

/// All imported roads in one piece, handed to the map renderers. Immutable, so any thread may read it.
final class CurvyRoadSet: @unchecked Sendable {
    /// Tells the maps whether the set has changed.
    let id = UUID()
    let roads: [CurvyRoad]

    init(roads: [CurvyRoad]) { self.roads = roads }

    /// The road nearest to a position within `metres`, for the tooltip.
    func nearest(latitude: Double, longitude: Double, within metres: Double) -> CurvyRoad? {
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
    /// "Nibelungenstraße (B 47) · Curvature 8879" for the tooltip.
    var tooltip: String {
        let title = name.isEmpty ? String(localized: "Unnamed road") : name
        return String(localized: "\(title) · Curvature \(Int(curvature.rounded()))")
    }
}

extension CurvyRoadLibrary {
    /// Next to the library's store, in the app's own folder.
    static var app: CurvyRoadLibrary {
        CurvyRoadLibrary(directory: LibraryLocation.storeURL.deletingLastPathComponent().appendingPathComponent("CurvyRoads"))
    }
}

/// The imported regions and what the maps draw (B-182, B-183); one for the whole app.
@MainActor
@Observable
final class CurvyRoadsStore {
    enum Activity: Equatable {
        case idle
        case importing(String)
        case failed(String)
    }

    private(set) var regions: [CurvyRegion.Info] = []
    private(set) var roadSet = CurvyRoadSet(roads: [])
    private(set) var activity: Activity = .idle
    private let library: CurvyRoadLibrary

    init(library: CurvyRoadLibrary = .app) {
        self.library = library
    }

    var hasData: Bool { !roadSet.roads.isEmpty }

    /// The set the maps draw: none while the layer is off or nothing is imported.
    func set(enabled: Bool) -> CurvyRoadSet? { enabled && hasData ? roadSet : nil }

    /// Reads the regions from disk, off the main actor.
    func load() async {
        let library = library
        let (infos, roads) = await Task.detached(priority: .utility) { (library.regions(), library.roads()) }.value
        regions = infos
        roadSet = CurvyRoadSet(roads: roads)
    }

    /// Imports KMZ or KML files; the layer then has them. Failures are shown, the files before stay.
    func importFiles(_ urls: [URL]) {
        if case .importing = activity { return }
        guard !urls.isEmpty else { return }
        Task {
            for url in urls {
                activity = .importing(url.lastPathComponent)
                let library = library
                let result: Result<CurvyRegion.Info, Error> = await Task.detached(priority: .userInitiated) {
                    let opened = url.startAccessingSecurityScopedResource()
                    defer { if opened { url.stopAccessingSecurityScopedResource() } }
                    return Result { try library.install(from: url) }
                }.value
                if case .failure(let error) = result {
                    activity = .failed(Self.message(for: error, file: url.lastPathComponent))
                    await load()
                    return
                }
            }
            activity = .idle
            await load()
        }
    }

    func remove(_ id: String) {
        library.remove(id: id)
        Task { await load() }
    }

    func dismissFailure() {
        if case .failed = activity { activity = .idle }
    }

    private static func message(for error: Error, file: String) -> String {
        switch error as? CurvyRoads.Failure {
        case .notCurvatureData: String(localized: "“\(file)” is not curvature data from roadcurvature.com.")
        case .tooLarge: String(localized: "“\(file)” is too large.")
        default: String(localized: "“\(file)” is damaged or cut off.")
        }
    }

    /// The dialog "Import Curvy Roads…", for the menu and the map's window.
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import Curvy Roads")
        panel.message = String(localized: "Choose the KMZ file of your state from roadcurvature.com, the one called “c_300”.")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ["kmz", "kml"].compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls)
    }
}

// MARK: - Drawing

/// One overlay for all roads; the renderer draws the ones in the tile it is asked for.
final class CurvyRoadsOverlay: NSObject, MKOverlay {
    let set: CurvyRoadSet
    let curvyColor: CGColor
    let veryCurvyColor: CGColor
    var boundingMapRect: MKMapRect { .world }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }

    init(set: CurvyRoadSet, dark: Bool) {
        self.set = set
        var curvy = CGColor(gray: 0, alpha: 1), veryCurvy = CGColor(gray: 0, alpha: 1)
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            curvy = NSColor(Color.curvyRoad(veryCurvy: false)).cgColor
            veryCurvy = NSColor(Color.curvyRoad(veryCurvy: true)).cgColor
        }
        curvyColor = curvy
        veryCurvyColor = veryCurvy
    }
}

final class CurvyRoadsRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
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

extension Color {
    /// Orange for curvy roads (from 300), red for very curvy ones (from 1000); different from the route and the new paths.
    static func curvyRoad(veryCurvy: Bool) -> Color {
        veryCurvy ? .adaptive(light: 0xD7263D, dark: 0xFF6B7A) : .adaptive(light: 0xE08600, dark: 0xFFB020)
    }
}

// MARK: - Legend, credit and the controls in "Customize Map"

/// "Curvy road" and "Very curvy road" on a map that shows the layer.
struct CurvyRoadsLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Curvy roads").font(.caption.weight(.bold))
            row(veryCurvy: false, text: "Curvy (300 and more)")
            row(veryCurvy: true, text: "Very curvy (1000 and more)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func row(veryCurvy: Bool, text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(Color.curvyRoad(veryCurvy: veryCurvy)).frame(width: 30, height: veryCurvy ? 4 : 3)
                .accessibilityHidden(true)
            Text(text).font(.caption)
        }
    }
}

/// The credit the road data asks for, at the bottom right of the map.
private struct CurvyRoadsCredit: View {
    var body: some View {
        Link(destination: CurvyRoads.downloadPage) {
            Text(verbatim: CurvyRoads.attribution)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        .help(Text("Curvy road data: open roadcurvature.com"))
        .accessibilityLabel(Text(verbatim: CurvyRoads.attribution))
    }
}

extension View {
    /// The credits at the bottom right of a map: the tile server's and, with the layer, the road data's.
    func mapCredits(for mapType: RideMapType, curvyRoads: Bool) -> some View {
        overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 4) {
                if curvyRoads { CurvyRoadsCredit() }
                if let source = mapType.tileSource { TileAttribution(source: source) }
            }
            .frame(maxWidth: 360, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.bottom, 4)
        }
    }
}

/// The section "Layers" in "Customize Map": the switch, what is imported and how to import more.
struct CurvyRoadsSection: View {
    @AppStorage(SettingsKey.showsCurvyRoads) private var shows = false
    @Environment(CurvyRoadsStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layers").font(.headline)
            Toggle("Curvy roads", isOn: $shows)
                .disabled(!store.hasData)
            if store.regions.isEmpty {
                Text("Shows the curvy roads of roadcurvature.com on the map. Download the “c_300” file of your state there and import it; Wattspur does not load any data by itself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.regions) { region in
                    HStack {
                        Text(verbatim: "\(region.name) · \(region.roadCount.formatted()) \(String(localized: "roads"))")
                            .font(.caption)
                        Spacer()
                        Button { store.remove(region.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help(Text("Remove \(region.name)"))
                            .accessibilityLabel(Text("Remove \(region.name)"))
                    }
                }
                Text("Roads show from the size of a district on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            switch store.activity {
            case .idle: EmptyView()
            case .importing(let file): Label { Text("Importing “\(file)” …") } icon: { ProgressView().controlSize(.small) }.font(.caption)
            case .failed(let message): Text(verbatim: message).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("Import …") { store.chooseFiles() }
                Button("Download Page") { openURL(CurvyRoads.downloadPage) }
                    .buttonStyle(.link)
            }
        }
    }
}
