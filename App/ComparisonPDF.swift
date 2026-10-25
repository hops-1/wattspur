import MapKit
import SwiftUI
import WattspurKit

/// The comparison as a PDF (CMP-07): page 1 with the map and the charts, then the table.
@MainActor
struct ComparisonReport {
    let rides: [Ride]
    let comparison: RideComparison
    let baselineCount: Int
    let showsDeviation: Bool
    var showsBike = false
    let points: [UUID: [ChartPoint]]
    let gradients: [UUID: Double]
    let routes: [UUID: [RoutePoint]]
    let mapType: RideMapType

    /// "Comparison – Morning loop, After-work loop.pdf"
    static func fileName(for rides: [Ride]) -> String {
        let names = rides.map(\.name).formatted(.list(type: .and))
        return PDFExport.fileName(String(localized: "Comparison – \(names)"))
    }

    func pdfData() async -> Data {
        let lines = rides.enumerated().map { index, ride in
            PDFExport.MapLine(
                coordinates: (routes[ride.id] ?? []).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                color: NSColor(ComparisonStyle.color(index)), dash: ComparisonStyle.dash(index).map { $0 * 1.6 })
        }
        let map = await PDFExport.mapImage(lines, mapType: mapType, size: CGSize(width: PDFExport.contentWidth, height: 360))
        let firstPage = VStack(alignment: .leading, spacing: 18) {
            ReportHeader(rides: rides)
            if let map {
                Image(nsImage: map)
                    .resizable()
                    .frame(width: PDFExport.contentWidth, height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            ComparisonCharts(rides: rides, points: points, gradients: gradients)
        }
        let table = VStack(alignment: .leading, spacing: 14) {
            ComparisonTable(rides: rides, comparison: comparison, baselineCount: baselineCount,
                            showsDeviation: showsDeviation, showsBike: showsBike)
            Text(CompareRidesView.footnote(baselineCount: baselineCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PDFExport.createdNote
        }
        return PDFExport.document([AnyView(firstPage), AnyView(table)])
    }
}

/// Title, the date range and one line per ride with its marker.
private struct ReportHeader: View {
    let rides: [Ride]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparing \(rides.count) rides")
                .font(.largeTitle.bold())
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                HStack(spacing: 8) {
                    ComparisonLegendMark(index: index)
                    Text(ride.name).font(.headline)
                    Text(verbatim: ride.startDate.formatted(Date.FormatStyle(date: .long, time: .shortened, timeZone: ride.timeZone)))
                        .foregroundStyle(.secondary)
                    Text(verbatim: "· \(RideFormat.distance(ride.distance)) · \(RideFormat.duration(ride.timerTime))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}
