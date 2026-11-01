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

    /// A live MapKit map cannot be drawn into a PDF; this takes the map of the same area
    /// (Apple's snapshot or the tiles of an OpenStreetMap style, B-061d) and draws the
    /// routes on top, as the map's renderer does.
    private func snapshot() async -> NSImage? {
        // Same shape as the image, so the area is not distorted.
        let rect = area.fitted(to: Self.mapSize)
        guard let backdrop = await MapBackdrop.make(mapType, rect: rect, size: Self.mapSize) else { return nil }
        let image = NSImage(size: Self.mapSize)
        image.lockFocusFlipped(true)
        backdrop.image.draw(in: CGRect(origin: .zero, size: Self.mapSize))
        if let context = NSGraphicsContext.current?.cgContext {
            style.draw(in: context, area: rect, scale: 1, mapPointsPerPoint: rect.width / Self.mapSize.width) {
                backdrop.point(for: $0.coordinate)
            }
        }
        image.unlockFocus()
        return image
    }
}
