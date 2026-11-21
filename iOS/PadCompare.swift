import Charts
import MapKit
import SwiftUI
import WattspurCore
import WattspurKit
import WattspurMap

/// 2 to 4 rides side by side on the iPad (B-296), like the Mac's comparison (CMP-01 … CMP-04):
/// the routes on one map, a chart over the distance and a table of all figures with the best
/// value of each row and your average. "Merge…" makes one ride of them, as on the Mac.
struct PadCompareView: View {
    let rideIDs: Set<UUID>
    /// Opens one ride beside the list.
    let onOpen: (UUID) -> Void
    /// After merging: the new ride.
    let onMerged: (UUID) -> Void

    @Environment(PhoneLibrary.self) private var library
    @State private var rides: [PhoneDatabase.ComparedRide] = []
    @State private var metric: PadCompareChart.Metric = .speed
    @State private var merging = false
    /// Each value's difference from "Your average" (B-334), off by default as on the Mac.
    @AppStorage(PhoneSettingsKey.padCompareShowsDeviation) private var showsDeviation = false

    var body: some View {
        let baseline = library.comparisonBaseline(for: rideIDs)
        let canCompare = RideComparison.canCompare(count: rideIDs.count)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !canCompare {
                    ContentUnavailableView("Up to 4 Rides", systemImage: "square.stack.3d.up",
                                           description: Text("A comparison shows 2 to 4 rides. You can still merge them."))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if rides.count == rideIDs.count {
                    let comparison = RideComparison(rides: rides.map(\.figures), baseline: baseline)
                    PadCompareMap(rides: rides)
                    PadCompareChart(rides: rides, metric: $metric)
                    // The switch sits by the table it changes, not among the actions.
                    Toggle("Difference from Average", isOn: $showsDeviation)
                        .toggleStyle(.switch)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    PadCompareTable(rides: rides, comparison: comparison, baselineCount: baseline.count,
                                    showsDeviation: showsDeviation, onOpen: onOpen)
                    Text("★ marks the best value of a row, only for figures where more or less is better. The average is per ride over your \(baseline.count) rides; averages are weighted by ride time as in the analysis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(28)
            .frame(maxWidth: 1200, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: rideIDs) {
            rides = canCompare ? library.comparedRides(rideIDs) : []
        }
        .sheet(isPresented: $merging) {
            NavigationStack {
                PadMergeSheet(rideIDs: rideIDs, onMerged: onMerged)
            }
        }
    }

    /// The title with the actions beside it, or below it when the column is narrow; the
    /// actions keep their size so they never wrap letter by letter.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    title
                    Spacer(minLength: 0)
                    actions
                }
                VStack(alignment: .leading, spacing: 12) {
                    title
                    actions
                }
            }
            Text("Tap rides in the list to add or remove them (up to 4).")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: some View {
        Text("Comparing \(rideIDs.count) rides")
            .font(.largeTitle.bold())
            .lineLimit(1)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    /// Share as a symbol, as in the ride; "Cancel" above the list ends the selection.
    private var actions: some View {
        HStack(spacing: 12) {
            // The comparison as a PDF (B-336), as shown: with or without the differences.
            if rides.count == rideIDs.count, RideComparison.canCompare(count: rides.count) {
                ShareLink(item: ComparisonPDF(rides: rides, baseline: library.comparisonBaseline(for: rideIDs),
                                              showsDeviation: showsDeviation),
                          preview: SharePreview(Text("Comparison"))) {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("Share PDF")
            }
            Button("Merge…", systemImage: "arrow.triangle.merge") { merging = true }
                .buttonStyle(.glassProminent)
        }
        .fixedSize()
    }
}

// MARK: - Look of each ride

/// Each column has a colour, a dash pattern and a marker shape, so rides stay apart for
/// colour-blind readers (NFR-16); colours as on the Mac, dashes and markers from the Kit.
enum PadCompareStyle {
    static let colors: [Color] = MapPalette.comparison.map(Color.map)

    static func color(_ index: Int) -> Color { colors[index % colors.count] }
    static func dash(_ index: Int) -> [CGFloat] { ComparisonMarks.dash(index).map { CGFloat($0) } }
    static func marker(_ index: Int) -> String { ComparisonMarks.marker(index) }
}

private struct LegendMark: View {
    let index: Int

    var body: some View {
        HStack(spacing: 2) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 5))
                p.addLine(to: CGPoint(x: 24, y: 5))
            }
            .stroke(PadCompareStyle.color(index),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: PadCompareStyle.dash(index)))
            .frame(width: 24, height: 10)
            Image(systemName: PadCompareStyle.marker(index))
                .font(.system(size: 9))
                .foregroundStyle(PadCompareStyle.color(index))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Map

private struct PadCompareMap: View {
    let rides: [PhoneDatabase.ComparedRide]

    var body: some View {
        Map(initialPosition: .rect(boundingRect)) {
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                MapPolyline(coordinates: ride.route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(PadCompareStyle.color(index),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round,
                                               dash: PadCompareStyle.dash(index).map { $0 * 1.6 }))
                if let start = ride.route.first {
                    Annotation(ride.name, coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude)) {
                        Image(systemName: PadCompareStyle.marker(index))
                            .font(.system(size: 12))
                            .foregroundStyle(PadCompareStyle.color(index))
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
        .accessibilityLabel(Text("Map of the compared rides"))
    }

    /// All routes with a margin around them.
    private var boundingRect: MKMapRect {
        let points = rides.flatMap(\.route).map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        guard let first = points.first else { return .world }
        var rect = MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        for point in points.dropFirst() { rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0))) }
        let pad = max(rect.width, rect.height) * 0.12 + 500
        return rect.insetBy(dx: -pad, dy: -pad)
    }
}

// MARK: - Chart

struct PadCompareChart: View {
    enum Metric: String, CaseIterable, Identifiable {
        case speed, altitude, power, cadence

        var id: Self { self }

        var label: LocalizedStringKey {
            switch self {
            case .speed: "Speed"
            case .altitude: "Elevation"
            case .power: "Power"
            case .cadence: "Cadence"
            }
        }

        var unit: String {
            switch self {
            case .speed: "km/h"
            case .altitude: "m"
            case .power: "W"
            case .cadence: String(localized: "rpm")
            }
        }

        func value(_ point: ChartPoint) -> Double? {
            switch self {
            case .speed: point.speedKmh
            case .altitude: point.altitude
            case .power: point.power
            case .cadence: point.cadence
            }
        }
    }

    let rides: [PhoneDatabase.ComparedRide]
    @Binding var metric: Metric

    /// Only the metrics that at least one ride has.
    private var metrics: [Metric] {
        Metric.allCases.filter { m in rides.contains { $0.chartPoints.contains { m.value($0) != nil } } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(metric.label).font(.title3.bold())
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(metrics) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            Chart {
                ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                    ForEach(ride.chartPoints) { point in
                        if let value = metric.value(point) {
                            LineMark(x: .value("km", point.distanceKm), y: .value(metric.unit, value),
                                     series: .value("Ride", ride.id.uuidString))
                                .foregroundStyle(PadCompareStyle.color(index))
                                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: PadCompareStyle.dash(index)))
                        }
                    }
                }
            }
            .chartXAxisLabel("km")
            .chartYAxisLabel(metric.unit)
            .frame(height: 220)
            HStack(spacing: 16) {
                ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                    HStack(spacing: 6) {
                        LegendMark(index: index)
                        Text(verbatim: ride.name).font(.caption).lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
        .onAppear { if !metrics.contains(metric), let first = metrics.first { metric = first } }
    }
}

// MARK: - Table

private struct PadCompareTable: View {
    let rides: [PhoneDatabase.ComparedRide]
    let comparison: RideComparison
    let baselineCount: Int
    /// Shows below each value its difference from the average (B-334), like the Mac.
    var showsDeviation = false
    /// Smaller type and a narrower label column, for the PDF (B-336).
    var dense = false
    let onOpen: (UUID) -> Void

    private var labelWidth: CGFloat { dense ? 120 : 200 }

    var body: some View {
        VStack(spacing: 0) {
            headerRow.background(.quaternary.opacity(0.35))
            ForEach(ComparisonGroup.allCases) { group in
                let metrics = group.metrics.filter { metric in
                    comparison.values(metric).contains { $0 != nil }
                }
                if !metrics.isEmpty {
                    Text(ComparisonFormat.title(group))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        .overlay(alignment: .top) { Divider() }
                        .accessibilityAddTraits(.isHeader)
                    ForEach(metrics) { metricRow($0) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private var headerRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("Metric")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
                .padding(.horizontal, 14)
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                Button { onOpen(ride.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        LegendMark(index: index)
                        Text(verbatim: ride.name).font(dense ? .caption.bold() : .headline).lineLimit(2).multilineTextAlignment(.leading)
                        Text(verbatim: ride.startDate.formatted(Date.FormatStyle(timeZone: ride.timeZone).day().month(.abbreviated).year()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Your average").font(dense ? .caption.bold() : .headline)
                Text("\(baselineCount) rides").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func metricRow(_ metric: ComparisonMetric) -> some View {
        let values = comparison.values(metric)
        let best = comparison.bestIndices(metric)
        return HStack(spacing: 0) {
            Text(ComparisonFormat.title(metric))
                .frame(width: labelWidth, alignment: .leading)
                .padding(.horizontal, 14)
            ForEach(values.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(verbatim: values[index].map { ComparisonFormat.value($0, metric) } ?? "–")
                            .fontWeight(best.contains(index) ? .semibold : .regular)
                        if best.contains(index) {
                            Text(verbatim: "★").foregroundStyle(Color.track).accessibilityLabel(Text("Best"))
                        }
                    }
                    if showsDeviation, let deviation = comparison.deviation(metric, ride: index) {
                        Text(verbatim: ComparisonFormat.deviation(deviation, metric))
                            .font(dense ? .system(size: 7) : .caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
            }
            Text(verbatim: comparison.averages[metric].map { ComparisonFormat.value($0, metric) } ?? "–")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
        }
        .font(dense ? .caption2 : .callout)
        .padding(.vertical, dense ? 3 : 7)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PDF

/// The comparison as an A4 PDF for the share menu (B-336), like "Export as PDF…" on the Mac:
/// the rides and their routes on a map on the first page, the table on the second.
struct ComparisonPDF: Transferable {
    let rides: [PhoneDatabase.ComparedRide]
    let baseline: [ComparisonFigures]
    let showsDeviation: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { pdf in await pdf.render() }
            .suggestedFileName { $0.fileName }
    }

    /// "Comparison – Morning loop and After-work loop.pdf"
    var fileName: String {
        PDFFile.name(String(localized: "Comparison – \(rides.map(\.name).formatted(.list(type: .and)))"))
    }

    @MainActor
    func render() async -> Data {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let lines = rides.enumerated().map { index, ride in
            ReportPDF.MapLine(coordinates: ride.route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                              color: UIColor(PadCompareStyle.color(index)).resolvedColor(with: light),
                              dash: PadCompareStyle.dash(index).map { $0 * 1.6 })
        }
        let map = await ReportPDF.mapImage(lines, size: CGSize(width: ReportPDF.contentWidth, height: 340))
        let comparison = RideComparison(rides: rides.map(\.figures), baseline: baseline)
        let first = VStack(alignment: .leading, spacing: 16) {
            Text("Comparing \(rides.count) rides").font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                    HStack(spacing: 8) {
                        LegendMark(index: index)
                        Text(verbatim: ride.name).font(.system(size: 12, weight: .semibold))
                        Text(verbatim: "\(RideFormat.date(ride.startDate, timeZone: ride.timeZone.identifier)) · \(RideFormat.distance(ride.figures.distance))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let map {
                Image(uiImage: map)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        let table = VStack(alignment: .leading, spacing: 10) {
            PadCompareTable(rides: rides, comparison: comparison, baselineCount: baseline.count,
                            showsDeviation: showsDeviation, dense: true, onOpen: { _ in })
            Text("★ marks the best value of a row, only for figures where more or less is better. The average is per ride over your \(baseline.count) rides; averages are weighted by ride time as in the analysis.")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ReportPDF.createdNote
        }
        return ReportPDF.document([AnyView(first), AnyView(table)])
    }
}

// MARK: - Merge

/// Confirms merging the selected rides (B-095, LIST-09): name and the merged totals; the originals
/// are kept inside the new ride, as on the Mac.
private struct PadMergeSheet: View {
    let rideIDs: Set<UUID>
    let onMerged: (UUID) -> Void

    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        let preview = library.mergePreview(rideIDs)
        Form {
            Section {
                Text("The rides become one. The originals are kept inside it, so you can split them again at any time.")
                    .foregroundStyle(.secondary)
            }
            switch preview {
            case .success(let result):
                Section {
                    TextField("Name", text: $name)
                }
                Section {
                    LabeledContent("Distance", value: RideFormat.distance(result.summary.distance))
                    LabeledContent("Ride time", value: RideFormat.duration(result.summary.timerTime))
                    if let ascent = result.summary.totalAscent {
                        LabeledContent("Ascent", value: RideFormat.ascent(ascent))
                    }
                } footer: {
                    Text("Time, distance, ascent and work are added up, maximums carried over. Average power and cadence are weighted by moving time.")
                }
            case .failure(let problem):
                Section {
                    Label(problem.message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Text("Merge \(rideIDs.count) Rides"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Merge") {
                    if let id = library.merge(rideIDs, name: name) {
                        dismiss()
                        onMerged(id)
                    }
                }
                .disabled((try? preview.get()) == nil)
            }
        }
        .onAppear { if name.isEmpty { name = library.mergeName(rideIDs) } }
    }
}
