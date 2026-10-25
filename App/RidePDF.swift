import MapKit
import SwiftUI
import WattspurKit

/// One ride as a PDF (P-20, pulled into v1.2): page 1 with the map, key figures and
/// details, then the four charts.
@MainActor
struct RideReport {
    let ride: Ride
    let route: [RoutePoint]
    let points: [ChartPoint]
    let mapType: RideMapType
    /// The x axis `points` were made for, as chosen in the ride detail (B-065).
    var axis: ChartAxis = .distance
    /// Where the parts of a merged ride meet (B-131).
    var joins: [RideMerge.Join] = []
    /// How calories are estimated, as in the ride detail (B-067).
    var calories: CalorieModel = .fromWork

    var fileName: String { PDFExport.fileName(ride.name) }

    func pdfData() async -> Data {
        let line = PDFExport.MapLine(
            coordinates: route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
            color: NSColor.controlAccentColor, showsEndpoints: true, joinTicks: JoinTick.ticks(of: joins))
        let map = await PDFExport.mapImage([line], mapType: mapType, size: CGSize(width: PDFExport.contentWidth, height: 380))
        let firstPage = VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.name).font(.largeTitle.bold())
                Text(RideFormat.longDate(ride.startDate, timeZone: ride.timeZone))
                    .foregroundStyle(.secondary)
                if let bike = ride.bike, let name = bike.name.nonEmpty {
                    HStack(spacing: 6) {
                        BikeChip(kind: bike.kind, color: bike.color, size: 18)
                        Text(verbatim: [String(localized: "Bike: \(name)"), bike.driveUnit.nonEmpty].compactMap { $0 }.joined(separator: " · "))
                            .font(.callout)
                    }
                    .padding(.top, 2)
                }
                if ride.isSample {
                    Text("Sample ride: the route is moved and shortened by 500 m at the start and end; power, cadence and totals are real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if ride.isMerged {
                    Text("Merged from \(ride.parts?.count ?? 0) rides")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let map {
                Image(nsImage: map)
                    .resizable()
                    .frame(width: PDFExport.contentWidth, height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            KeyFiguresGrid(ride: ride, calories: calories)
            DetailsGrid(ride: ride)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        let charts = VStack(alignment: .leading, spacing: 16) {
            RideChartsView(ride: ride, points: points, axis: axis, joins: joins)
            PDFExport.createdNote
        }
        return PDFExport.document([AnyView(firstPage), AnyView(charts)])
    }
}
