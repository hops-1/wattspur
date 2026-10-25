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

    @Query(filter: #Predicate<Ride> { $0.deletedAt == nil && $0.mergedInto == nil }) private var rides: [Ride]
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

// MARK: - Ride identity: colour, dash and shape (NFR-16)

/// Each column has a colour, a dash pattern and a marker shape, so rides stay apart
/// for colour-blind readers and in black and white. Colours have at least 4.5:1
/// against the window background in both modes.
enum ComparisonStyle {
    static let colors: [Color] = [
        .adaptive(light: 0x0B6BCB, dark: 0x4DA3FF),
        .adaptive(light: 0xC2410C, dark: 0xFF8A4C),
        .adaptive(light: 0x0E7C6B, dark: 0x3CC7A6),
        .adaptive(light: 0x8E44AD, dark: 0xC38BEF),
    ]
    static let dashes: [[CGFloat]] = [[], [7, 4], [2, 3], [9, 3, 2, 3]]
    static let markers = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill"]

    static func color(_ index: Int) -> Color { colors[index % colors.count] }
    static func dash(_ index: Int) -> [CGFloat] { dashes[index % dashes.count] }
    static func marker(_ index: Int) -> String { markers[index % markers.count] }
}

/// Marker and dash of a ride, as in the legend.
struct ComparisonLegendMark: View {
    let index: Int

    var body: some View {
        HStack(spacing: 2) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 5))
                p.addLine(to: CGPoint(x: 24, y: 5))
            }
            .stroke(ComparisonStyle.color(index),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: ComparisonStyle.dash(index)))
            .frame(width: 24, height: 10)
            Image(systemName: ComparisonStyle.marker(index))
                .font(.system(size: 9))
                .foregroundStyle(ComparisonStyle.color(index))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Map of all compared routes

/// The routes on one map, each in its column's colour and dash, with its marker at the start.
private struct ComparisonMap: View {
    let rides: [Ride]
    let routes: [UUID: [RoutePoint]]
    @Binding var mapType: RideMapType

    private func coordinates(_ ride: Ride) -> [CLLocationCoordinate2D] {
        (routes[ride.id] ?? []).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var hasRoutes: Bool { rides.contains { (routes[$0.id]?.count ?? 0) > 1 } }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                let line = coordinates(ride)
                if line.count > 1 {
                    MapPolyline(coordinates: line)
                        .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: line)
                        .stroke(ComparisonStyle.color(index),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round,
                                                   dash: ComparisonStyle.dash(index).map { $0 * 1.6 }))
                }
                if let start = line.first {
                    Annotation(coordinate: start) {
                        Image(systemName: ComparisonStyle.marker(index))
                            .font(.system(size: 11))
                            .foregroundStyle(ComparisonStyle.color(index))
                            .padding(4)
                            .background(.white, in: Circle())
                            .shadow(radius: 1.5)
                    } label: {
                        Text(verbatim: ride.name)
                    }
                }
            }
        }
        // Fit the map again when rides are added or removed.
        .id(rides.map(\.id))
        .mapStyle(mapType.style)
        .mapControls {
            MapZoomStepper()
            MapCompass()
            MapScaleView()
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            Picker("Map type", selection: $mapType) {
                ForEach(RideMapType.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(6)
            .glassEffect(.regular, in: Capsule())
            .padding(12)
        }
        .overlay {
            if !hasRoutes && !routes.isEmpty {
                ContentUnavailableView("No GPS data", systemImage: "location.slash")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Map of the compared routes"))
    }
}

// MARK: - Table (CMP-02 … CMP-04)

struct ComparisonTable: View {
    let rides: [Ride]
    let comparison: RideComparison
    let baselineCount: Int
    let showsDeviation: Bool
    /// A row with each ride's bike (B-136).
    var showsBike = false
    /// `nil` in the PDF, which has no buttons.
    var onOpen: ((UUID) -> Void)?
    var onRemove: ((UUID) -> Void)?

    private static let labelWidth = 210.0

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .background(.quaternary.opacity(0.35))
            if showsBike { bikeRow }
            ForEach(ComparisonGroup.allCases) { group in
                Text(ComparisonFormat.title(group))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .overlay(alignment: .top) { Divider() }
                    .accessibilityAddTraits(.isHeader)
                ForEach(group.metrics) { metric in
                    metricRow(metric)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("Metric")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: Self.labelWidth, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                ComparisonColumnHeader(ride: ride, index: index, canRemove: rides.count > RideComparison.allowedCount.lowerBound,
                                       onOpen: onOpen.map { open in { open(ride.id) } },
                                       onRemove: onRemove.map { remove in { remove(ride.id) } })
                    .cell()
            }
            if showsDeviation {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your average").font(.headline)
                    Text("\(baselineCount) rides").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .cell()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Which bike each ride was on.
    private var bikeRow: some View {
        HStack(spacing: 0) {
            Text("Bike")
                .frame(width: Self.labelWidth, alignment: .leading)
                .padding(.horizontal, 14)
            ForEach(rides.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    if let bike = rides[index].bike {
                        BikeChip(kind: bike.kind, color: bike.color, size: 22)
                        Text(verbatim: bike.name).lineLimit(1)
                    } else {
                        Text(verbatim: "–").foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Bike: \(rides[index].bike?.name ?? "–"), \(rides[index].name)"))
                .cell()
            }
            if showsDeviation { Color.clear.cell() }
        }
        .font(.callout)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func metricRow(_ metric: ComparisonMetric) -> some View {
        let values = comparison.values(metric)
        let best = comparison.bestIndices(metric)
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(ComparisonFormat.title(metric))
                switch metric.direction {
                case .higherIsBetter: DirectionHint(higher: true)
                case .lowerIsBetter: DirectionHint(higher: false)
                case .neutral: EmptyView()
                }
                if metric.isEstimate {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .help(Text("Estimated from your pedal power"))
                        .accessibilityLabel(Text("Estimated from your pedal power"))
                }
            }
            .frame(width: Self.labelWidth, alignment: .leading)
            .padding(.horizontal, 14)
            ForEach(rides.indices, id: \.self) { index in
                ComparisonValueCell(
                    rideName: rides[index].name,
                    value: values[index].map { ComparisonFormat.value($0, metric) } ?? "–",
                    deviation: showsDeviation ? comparison.deviation(metric, ride: index).map { ComparisonFormat.deviation($0, metric) } : nil,
                    isBest: best.contains(index)
                )
                .cell(highlighted: best.contains(index))
            }
            if showsDeviation {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: comparison.averages[metric].map { ComparisonFormat.value($0, metric) } ?? "–")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    // The average is taken over the rides that have the value (B-146).
                    if let coverage = comparison.coverage[metric] { CoverageNote(coverage: coverage) }
                }
                .accessibilityElement(children: .combine)
                .cell()
            }
        }
        .font(.callout)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    /// A table cell: equal share of the width, a line on the left, tinted for the best value.
    func cell(highlighted: Bool = false) -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(highlighted ? Color.accentColor.opacity(0.12) : .clear)
            .overlay(alignment: .leading) { Divider().opacity(0.6) }
    }
}

/// "↑ better" or "↓ better" next to a metric that has a direction.
private struct DirectionHint: View {
    let higher: Bool

    var body: some View {
        Label("better", systemImage: higher ? "arrow.up" : "arrow.down")
            .labelStyle(.titleAndIcon)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .help(Text(higher ? "Higher is better" : "Lower is better"))
            .accessibilityLabel(Text(higher ? "Higher is better" : "Lower is better"))
    }
}

private struct ComparisonColumnHeader: View {
    let ride: Ride
    let index: Int
    let canRemove: Bool
    let onOpen: (() -> Void)?
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: ComparisonStyle.marker(index))
                    .font(.system(size: 10))
                    .foregroundStyle(ComparisonStyle.color(index))
                    .accessibilityHidden(true)
                Text(ride.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(Text(verbatim: ride.name))
            }
            Text(verbatim: ride.startDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: ride.timeZone)))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                if ride.isSample { SampleBadge() }
                if ride.isMerged { MergedBadge(count: ride.parts?.count ?? 0) }
                Spacer(minLength: 0)
                if let onOpen {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.forward")
                    }
                    .help(Text("Show Only This Ride"))
                    .accessibilityLabel(Text("Show only \(ride.name)"))
                }
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                    }
                    .disabled(!canRemove)
                    .help(Text(canRemove ? "Remove from Comparison" : "A comparison needs at least 2 rides"))
                    .accessibilityLabel(Text("Remove \(ride.name) from comparison"))
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }
}

private struct ComparisonValueCell: View {
    let rideName: String
    let value: String
    let deviation: String?
    let isBest: Bool

    private var accessibilityValue: String {
        let shown = isBest ? String(localized: "\(value), best value") : value
        return deviation.map { "\(shown), \($0)" } ?? shown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if isBest {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                Text(verbatim: value)
                    .fontWeight(isBest ? .bold : .regular)
            }
            if let deviation {
                Text(verbatim: deviation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: rideName))
        .accessibilityValue(Text(verbatim: accessibilityValue))
    }
}

// MARK: - Charts on top of each other (CMP-05)

struct ComparisonCharts: View {
    let rides: [Ride]
    let points: [UUID: [ChartPoint]]
    /// Steepest climb per ride over 100 m, as a fraction.
    let gradients: [UUID: Double]

    /// Ascent, descent and steepest climb: an average elevation says nothing.
    private func elevationFigure(_ ride: Ride) -> String {
        let up = ride.totalAscent.map { "\($0) m" } ?? "–"
        let down = ride.totalDescent.map { "\($0) m" } ?? "–"
        let steepest = gradients[ride.id].map { ($0 * 100).formatted(.number.precision(.fractionLength(0))) + " %" } ?? "–"
        return String(localized: "↑ \(up) · ↓ \(down) · steepest \(steepest)")
    }

    private func average(_ value: String) -> String {
        String(localized: "avg \(value)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                Text("Over the Ride").font(.title3.bold())
                ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                    HStack(spacing: 6) {
                        ComparisonLegendMark(index: index)
                        Text(ride.name).font(.callout).lineLimit(1)
                    }
                }
            }
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    OverlayChart(title: "Elevation", unit: "m", rides: rides, points: points, value: \.altitude,
                                 figures: rides.map(elevationFigure), startsAtZero: false)
                    OverlayChart(title: "Speed", unit: "km/h", rides: rides, points: points, value: \.speedKmh,
                                 figures: rides.map { average(RideFormat.speed($0.averageSpeed)) })
                }
                GridRow {
                    OverlayChart(title: "Cadence", unit: String(localized: "rpm"), rides: rides, points: points, value: \.cadence,
                                 figures: rides.map { average("\($0.averageCadence.map(String.init) ?? "–") \(String(localized: "rpm"))") })
                    OverlayChart(title: "Power", unit: "W", rides: rides, points: points, value: \.power,
                                 figures: rides.map { average("\($0.averagePower.map(String.init) ?? "–") W") })
                }
            }
            Text("x-axis: distance in km. Each ride has its own colour, dash and shape; shorter rides end earlier.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OverlayChart: View {
    let title: LocalizedStringResource
    let unit: String
    let rides: [Ride]
    let points: [UUID: [ChartPoint]]
    let value: KeyPath<ChartPoint, Double?>
    /// One line per ride under the title, e.g. "avg 24.1 km/h" (Bosch values).
    let figures: [String]
    var startsAtZero = true

    private var series: [(index: Int, name: String, points: [ChartPoint])] {
        rides.enumerated().map { ($0.offset, $0.element.name, points[$0.element.id] ?? []) }
    }

    private var yDomain: ClosedRange<Double> {
        let values = series.flatMap { $0.points.compactMap { $0[keyPath: value] } }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        if startsAtZero { return 0...max(hi * 1.05, 1) }
        let pad = max((hi - lo) * 0.1, 5)
        return (lo - pad)...(hi + pad)
    }

    private var maxDistance: Double {
        max(series.compactMap { $0.points.last?.distanceKm }.max() ?? 1, 0.1)
    }

    var body: some View {
        let domain = yDomain
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.headline)
                Text(verbatim: unit).font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(zip(rides.indices, figures)), id: \.0) { index, figure in
                    HStack(spacing: 6) {
                        Image(systemName: ComparisonStyle.marker(index))
                            .font(.system(size: 8))
                            .foregroundStyle(ComparisonStyle.color(index))
                            .accessibilityHidden(true)
                        Text(verbatim: figure)
                            .font(.callout.weight(.medium))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: "\(rides[index].name): \(figure)"))
                }
            }
            Chart {
                ForEach(series, id: \.index) { s in
                    ForEach(s.points) { point in
                        if let y = point[keyPath: value] {
                            LineMark(x: .value("Distance", point.distanceKm), y: .value(unit, y),
                                     series: .value("Ride", s.index))
                                .foregroundStyle(ComparisonStyle.color(s.index))
                                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: ComparisonStyle.dash(s.index)))
                                .interpolationMethod(.monotone)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...maxDistance)
            .chartYScale(domain: domain)
            .chartPlotStyle { $0.clipped() }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { mark in
                    AxisGridLine()
                    AxisValueLabel {
                        if let km = mark.as(Double.self) { Text(verbatim: "\(km.formatted(.number.precision(.fractionLength(0)))) km") }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { mark in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    AxisValueLabel {
                        if let v = mark.as(Double.self) { Text(verbatim: v.formatted(.number.precision(.fractionLength(0)))) }
                    }
                }
            }
            .frame(height: 160)
            .accessibilityLabel(Text(title))
            .accessibilityChartDescriptor(
                ComparisonChartDescriptor(title: String(localized: title), unit: unit,
                                          series: series.map { ($0.name, $0.points) }, value: value)
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}

// MARK: - Formatting

/// Titles and locale-aware values for the comparison (NFR-10).
enum ComparisonFormat {
    static func title(_ group: ComparisonGroup) -> LocalizedStringKey {
        switch group {
        case .ride: "Ride"
        case .speed: "Speed"
        case .elevation: "Elevation"
        case .power: "Power and cadence"
        case .estimates: "Estimates"
        case .perKilometre: "Comparable across ride lengths"
        }
    }

    static func title(_ metric: ComparisonMetric) -> LocalizedStringKey {
        switch metric {
        case .rideTime: "Ride time"
        case .totalTime: "Total time"
        case .pausedTime: "Paused"
        case .distance: "Distance"
        case .averageSpeed: "Avg speed"
        case .maxSpeed: "Max speed"
        case .ascent: "Ascent"
        case .descent: "Descent"
        case .minAltitude: "Min elevation"
        case .maxAltitude: "Max elevation"
        case .averagePower: "Avg power"
        case .maxPower: "Max power"
        case .averageCadence: "Avg cadence"
        case .maxCadence: "Max cadence"
        case .work: "Work"
        case .calories: "Calories"
        case .co2Saved: "CO₂ saved"
        case .caloriesPerKilometre: "Calories per km"
        case .ascentPerKilometre: "Ascent per km"
        case .workPerKilometre: "Work per km"
        case .coastingShare: "Coasting share"
        case .averagePowerOverRideTime: "Avg power over ride time"
        }
    }

    /// A value in its display unit, e.g. "24.1 km/h" or "00:48:36".
    static func value(_ v: Double, _ metric: ComparisonMetric) -> String {
        switch metric {
        case .rideTime, .totalTime, .pausedTime: RideFormat.duration(v)
        default: "\(number(v, metric)) \(unit(metric))"
        }
    }

    /// "+2.1 km/h · +9 %"; durations as "+0:12 h" or "−8 min"; the coasting share in percentage points.
    static func deviation(_ d: ComparisonDeviation, _ metric: ComparisonMetric) -> String {
        let sign = d.absolute > 0.0005 ? "+" : d.absolute < -0.0005 ? "−" : "±"
        let magnitude = abs(d.absolute)
        let absolute: String = switch metric {
        case .rideTime, .totalTime, .pausedTime: shortDuration(magnitude)
        case .coastingShare: "\((magnitude * 100).formatted(.number.precision(.fractionLength(0)))) \(String(localized: "pp"))"
        default: "\(number(magnitude, metric)) \(unit(metric))"
        }
        guard metric != .coastingShare, let relative = d.relative else { return sign + absolute }
        let percent = Int((relative * 100).rounded())
        let pSign = percent > 0 ? "+" : percent < 0 ? "−" : "±"
        return "\(sign)\(absolute) · \(pSign)\(abs(percent)) %"
    }

    private static func number(_ v: Double, _ metric: ComparisonMetric) -> String {
        switch metric {
        case .distance: (v / 1000).formatted(.number.precision(.fractionLength(1)))
        case .averageSpeed, .maxSpeed: (v * 3.6).formatted(.number.precision(.fractionLength(1)))
        case .co2Saved, .caloriesPerKilometre, .ascentPerKilometre, .workPerKilometre:
            v.formatted(.number.precision(.fractionLength(1)))
        case .coastingShare: (v * 100).formatted(.number.precision(.fractionLength(0)))
        default: v.formatted(.number.precision(.fractionLength(0)))
        }
    }

    private static func unit(_ metric: ComparisonMetric) -> String {
        switch metric {
        case .rideTime, .totalTime, .pausedTime: ""
        case .distance: "km"
        case .averageSpeed, .maxSpeed: "km/h"
        case .ascent, .descent, .minAltitude, .maxAltitude: "m"
        case .averagePower, .maxPower, .averagePowerOverRideTime: "W"
        case .averageCadence, .maxCadence: String(localized: "rpm")
        case .work: "kJ"
        case .calories: "kcal"
        case .co2Saved: "kg"
        case .caloriesPerKilometre: "kcal/km"
        case .ascentPerKilometre: "m/km"
        case .workPerKilometre: "kJ/km"
        case .coastingShare: "%"
        }
    }

    /// "12 min" or "1:05 h".
    private static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = total % 3600 / 60
        return hours > 0 ? String(format: "%d:%02d h", hours, minutes) : "\(minutes) min"
    }
}
