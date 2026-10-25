import MapKit
import SwiftUI
import WattspurKit

/// The map of all rides as a PDF (B-106, Requirements 10.11): the visible area in
/// the current drawing, the tiles of the visible area and the legend, A4 portrait.
@MainActor
struct MapReport {
    let style: RidesMapStyle
    /// The visible area on screen.
    let area: MKMapRect
    let mapType: RideMapType
    let subtitle: String
    let inView: [MapRide]
    let total: Int
    let isSelection: Bool
    var newPathsDistance: Double? = nil

    static let mapSize = CGSize(width: PDFExport.contentWidth, height: 860)

    func pdfData() async -> Data {
        let image = await snapshot()
        let page = VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isSelection ? "Map – selected rides" : "Map – all rides").font(.largeTitle.bold())
                Text(verbatim: subtitle).foregroundStyle(.secondary)
            }
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: Self.mapSize.width, height: Self.mapSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            AreaTiles(rides: inView, total: total, isSelection: isSelection, newPathsDistance: newPathsDistance)
            MapLegend(highlighted: style.lines.contains { $0.highlight != nil }
                      ? inView.sorted { $0.figures.startDate < $1.figures.startDate } : [], mode: style.mode)
            Text("The map shows your routes and so also where you live – think before you share it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            PDFExport.createdNote
        }
        return PDFExport.document([AnyView(page)])
    }

    /// A live MapKit map cannot be drawn into a PDF; this takes a snapshot of the
    /// same area and draws the routes on top, as the map's renderer does.
    private func snapshot() async -> NSImage? {
        let options = MKMapSnapshotter.Options()
        // Same shape as the image, so the area is not distorted.
        let aspect = Self.mapSize.width / Self.mapSize.height
        var rect = area
        if rect.width / rect.height > aspect {
            let height = rect.width / aspect
            rect = MKMapRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        } else {
            let width = rect.height * aspect
            rect = MKMapRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: rect.height)
        }
        options.mapRect = rect
        options.size = Self.mapSize
        options.appearance = NSAppearance(named: .aqua)
        switch mapType {
        case .standard:
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
        let image = NSImage(size: Self.mapSize)
        image.lockFocusFlipped(true)
        snapshot.image.draw(in: CGRect(origin: .zero, size: Self.mapSize))
        if let context = NSGraphicsContext.current?.cgContext {
            style.draw(in: context, area: rect, scale: 1, mapPointsPerPoint: rect.width / Self.mapSize.width) {
                snapshot.topDownPoint(for: $0.coordinate, height: Self.mapSize.height)
            }
        }
        image.unlockFocus()
        return image
    }
}
