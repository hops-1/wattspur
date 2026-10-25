import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

/// 2–4 rides side by side: a table of all figures and the charts on top of each
/// other (B-100 … B-103, CMP-01 … CMP-06). The rides selected in the list are the
/// comparison: ⌘-click adds a ride, removing one deselects it.
struct CompareRidesView: View {
    let rideIDs: Set<UUID>
    /// Shows only this ride (CMP-06).
    let onOpen: (UUID) -> Void
    /// Takes the ride out of the selection (CMP-06).
    let onRemove: (UUID) -> Void
    let onDone: () -> Void

    @Query(filter: Ride.listedPredicate) private var rides: [Ride]
    @AppStorage("compareShowsDeviation") private var showsDeviation = false
    @State private var points: [UUID: [ChartPoint]] = [:]
    @State private var routes: [UUID: [RoutePoint]] = [:]
    @State private var gradients: [UUID: Double] = [:]
    @AppStorage("mapType") private var mapType: RideMapType = .standard
    @State private var exporting = false
    @Query private var bikes: [Bike]
    /// "From pedal power" or "with profile" (SET-06, B-067).
    @AppStorage("calorieMode") private var calorieMode: CalorieMode = .fromWork
    @Query private var riders: [Rider]
    private var calories: CalorieModel { CalorieModel(mode: calorieMode, rider: riders.first) }

    /// A row "Bike" in the table, from two bikes on (B-136).
    private var showsBike: Bool { bikes.count >= 2 && compared.contains { $0.bike != nil } }

    /// Oldest first, so a ride keeps its column and colour while others are added.
    private var compared: [Ride] {
        rides.filter { rideIDs.contains($0.id) }.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        let compared = compared
        // The sample ride can be compared, but it never counts towards the average (CMP-04).
        let baseline = rides.filter(\.countsInStatistics)
        let comparison = RideComparison(rides: compared.map(\.comparisonFigures),
                                        baseline: baseline.map(\.comparisonFigures), calories: calories)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(count: compared.count)
                // Map, then the charts, then the table (order agreed with Nils, 21.10.2026).
                ComparisonMap(rides: compared, routes: routes, mapType: $mapType)
                ComparisonCharts(rides: compared, points: points, gradients: gradients)
                ComparisonTable(rides: compared, comparison: comparison, baselineCount: baseline.count,
                                showsDeviation: showsDeviation, showsBike: showsBike, onOpen: onOpen, onRemove: onRemove)
                Text(Self.footnote(baselineCount: baseline.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: 1200, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: compared.map(\.id)) {
            // Decode each ride's time series once; keep the ones already loaded.
            var loaded = points.filter { rideIDs.contains($0.key) }
            var loadedRoutes = routes.filter { rideIDs.contains($0.key) }
            var loadedGradients = gradients.filter { rideIDs.contains($0.key) }
            for ride in compared where loaded[ride.id] == nil {
                let samples = ride.samples
                loaded[ride.id] = RideSeries.chartPoints(from: samples, bins: 300)
                loadedRoutes[ride.id] = RideSeries.route(from: samples, maxPoints: 800)
                loadedGradients[ride.id] = RideSeries.steepestGradient(from: samples)
            }
            points = loaded
            routes = loadedRoutes
            gradients = loadedGradients
        }
    }

    private func header(count: Int) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                // PDF export at the top left (CMP-07, Nils 21.10.2026).
                PDFExportButton(isExporting: exporting, isDisabled: points.count < compared.count) { target in
                    Task { await exportPDF(target) }
                }
                .padding(.bottom, 8)
                Text("Comparing \(count) rides")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("To add a ride, ⌘-click it in the list (up to 4).")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Difference from Average", isOn: $showsDeviation)
                .toggleStyle(.switch)
                .controlSize(.small)
            Button("Done", action: onDone)
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
        }
    }

    /// Renders the comparison as it is shown (including the deviation switch), then opens
    /// it in Preview or asks where to save it (CMP-07).
    private func exportPDF(_ target: PDFExport.Target) async {
        exporting = true
        defer { exporting = false }
        let compared = compared
        let baseline = rides.filter(\.countsInStatistics)
        let report = ComparisonReport(
            rides: compared,
            comparison: RideComparison(rides: compared.map(\.comparisonFigures), baseline: baseline.map(\.comparisonFigures), calories: calories),
            baselineCount: baseline.count, showsDeviation: showsDeviation, showsBike: showsBike,
            points: points, gradients: gradients, routes: routes, mapType: mapType
        )
        PDFExport.deliver(await report.pdfData(), fileName: ComparisonReport.fileName(for: compared), to: target)
    }

    static func footnote(baselineCount: Int) -> String {
        String(localized: "★ marks the best value of a row, only for figures where more or less is better. The average is per ride over your \(baselineCount) rides; averages are weighted by ride time as in the analysis. The sample ride does not count, a merged ride counts as one ride. Avg power comes from Bosch and counts only seconds with pedal power; “over ride time” is work ÷ ride time.")
    }
}
