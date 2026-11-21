import Charts
import CoreTransferable
import MapKit
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurKit
import WattspurMap

/// A ride as a one-page PDF for the share menu on the iPad (B-297), like "Export as PDF…" on the
/// Mac: name, date and device, the route on a map, the key figures and the speed and elevation
/// over the distance. Made only when shared, from what the detail has already loaded.
struct RidePDF: Transferable {
    let ride: RideExchange.Ride
    let deviceName: String?
    let points: [ChartPoint]
    let route: [CLLocationCoordinate2D]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { pdf in await pdf.render() }
            .suggestedFileName { $0.fileName }
    }

    /// "Sonntagstour 2026-11-06.pdf"
    var fileName: String {
        let day = ride.startDate.formatted(.iso8601.year().month().day())
        return PDFFile.name("\(ride.name) \(day)")
    }

    /// A4 in points.
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let margin = 40.0

    @MainActor
    func render() async -> Data {
        let mapSize = CGSize(width: Self.pageSize.width - 2 * Self.margin, height: 260)
        let map = await Self.mapImage(route, size: mapSize)
        let page = RidePDFPage(ride: ride, deviceName: deviceName, points: points, map: map)
            .frame(width: Self.pageSize.width - 2 * Self.margin, alignment: .topLeading)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: Self.pageSize.width - 2 * Self.margin, height: nil)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var box = CGRect(origin: .zero, size: Self.pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        renderer.render { size, draw in
            context.beginPDFPage(nil)
            // PDF coordinates start at the bottom; the page is drawn from the top margin down.
            context.translateBy(x: Self.margin, y: Self.pageSize.height - Self.margin - size.height)
            draw(context)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    /// The route on Apple's map, drawn as a line in the track colour; `nil` without GPS.
    @MainActor
    static func mapImage(_ route: [CLLocationCoordinate2D], size: CGSize) async -> UIImage? {
        guard route.count >= 2 else { return nil }
        let points = route.map(MKMapPoint.init)
        var rect = MKMapRect(origin: points[0], size: MKMapSize(width: 0, height: 0))
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
            // No line across a gap in the track (B-309), as on the Mac.
            let path = UIBezierPath(cgPath: TrackGap.path(route) { snapshot.point(for: $0) })
            path.lineWidth = 3
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            UIColor(cgColor: MapPalette.track.cgColor(dark: false)).setStroke()
            path.stroke()
        }
    }
}

/// What the page shows.
private struct RidePDFPage: View {
    let ride: RideExchange.Ride
    let deviceName: String?
    let points: [ChartPoint]
    let map: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ride.name).font(.system(size: 22, weight: .bold))
                Text(verbatim: [RideFormat.date(ride.startDate, timeZone: ride.timeZone), deviceName]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let map {
                Image(uiImage: map)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            figures
            if points.contains(where: { $0.speedKmh != nil }) {
                chart(title: "Speed", unit: "km/h", value: \.speedKmh)
            }
            if points.contains(where: { $0.altitude != nil }) {
                chart(title: "Elevation", unit: "m", value: \.altitude)
            }
            ReportPDF.createdNote
        }
        .foregroundStyle(.black)
    }

    private var figures: some View {
        let items: [(LocalizedStringKey, String)] = [
            ("Distance", RideFormat.distance(ride.distance)),
            ("Ride time", RideFormat.duration(ride.timerTime)),
            ("Avg speed", ride.averageSpeed.map(RideFormat.speed) ?? "–"),
            ("Max speed", ride.maxSpeed.map(RideFormat.speed) ?? "–"),
            ("Ascent", ride.totalAscent.map(RideFormat.ascent) ?? "–"),
            ("Avg power", ride.averagePower.map { "\($0) W" } ?? "–"),
        ]
        return Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            ForEach(0..<2) { row in
                GridRow {
                    ForEach(0..<3) { column in
                        let item = items[row * 3 + column]
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.0).font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(verbatim: item.1).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func chart(title: LocalizedStringKey, unit: String, value: KeyPath<ChartPoint, Double?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 11, weight: .semibold))
                Text(verbatim: unit).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Chart(points) { point in
                if let v = point[keyPath: value] {
                    AreaMark(x: .value("km", point.distanceKm), y: .value(unit, v))
                        .foregroundStyle(Color.track.opacity(0.15))
                    LineMark(x: .value("km", point.distanceKm), y: .value(unit, v))
                        .foregroundStyle(Color.track)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXAxisLabel("km")
            .frame(height: 110)
        }
    }
}
