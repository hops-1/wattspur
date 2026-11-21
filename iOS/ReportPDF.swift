import MapKit
import SwiftUI
import UIKit
import WattspurCore
import WattspurMap

/// A4 pages from SwiftUI views for the share menu (B-336): the highlights and the comparison, the
/// way `RidePDF` makes one page of a ride. Each view is laid out at the width of the page; a view
/// taller than the page is scaled down to fit, so nothing is cut off.
enum ReportPDF {
    static let pageSize = RidePDF.pageSize
    static let margin = RidePDF.margin
    static var contentWidth: CGFloat { pageSize.width - 2 * margin }
    static var contentHeight: CGFloat { pageSize.height - 2 * margin }

    /// One PDF page per view, light and black on white like printed paper.
    @MainActor
    static func document(_ pages: [AnyView]) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var box = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        for page in pages {
            let content = page
                .frame(width: contentWidth, alignment: .topLeading)
                .foregroundStyle(.black)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
            renderer.render { size, draw in
                let scale = min(1, contentHeight / max(size.height, 1))
                context.beginPDFPage(nil)
                // PDF coordinates start at the bottom; the page is drawn from the top margin down.
                context.translateBy(x: margin, y: pageSize.height - margin - size.height * scale)
                context.scaleBy(x: scale, y: scale)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return data as Data
    }

    /// The last line of every report.
    static var createdNote: some View {
        Text("Created with Wattspur on \(Date.now.formatted(date: .long, time: .omitted))")
            .font(.system(size: 8))
            .foregroundStyle(.secondary)
    }

    /// A line on the map: its points, colour and dash pattern (empty for a solid line).
    struct MapLine {
        var coordinates: [CLLocationCoordinate2D]
        var color: UIColor
        var dash: [CGFloat] = []
    }

    /// The routes on Apple's map, each in its own colour and dash; `nil` without GPS.
    @MainActor
    static func mapImage(_ lines: [MapLine], size: CGSize) async -> UIImage? {
        let points = lines.flatMap(\.coordinates).map(MKMapPoint.init)
        guard let first = points.first, points.count >= 2 else { return nil }
        var rect = MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        for point in points.dropFirst() { rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0))) }
        let pad = max(rect.width, rect.height) * 0.1 + 300
        let options = MKMapSnapshotter.Options()
        options.mapRect = rect.insetBy(dx: -pad, dy: -pad)
        options.size = size
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        options.pointOfInterestFilter = .excludingAll
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return UIGraphicsImageRenderer(size: size).image { _ in
            snapshot.image.draw(at: .zero)
            for line in lines where line.coordinates.count >= 2 {
                // No line across a gap in the track (B-309), as on the Mac.
                let path = UIBezierPath(cgPath: TrackGap.path(line.coordinates) { snapshot.point(for: $0) })
                path.lineWidth = 3
                path.lineJoinStyle = .round
                path.lineCapStyle = .round
                if !line.dash.isEmpty { path.setLineDash(line.dash, count: line.dash.count, phase: 0) }
                line.color.setStroke()
                path.stroke()
            }
        }
    }
}
