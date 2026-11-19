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
    let onDone: () -> Void

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

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                title
                Spacer()
                buttons
            }
            VStack(alignment: .leading, spacing: 12) {
                title
                HStack(spacing: 12) { buttons }
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Comparing \(rideIDs.count) rides")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Tap rides in the list to add or remove them (up to 4).")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var buttons: some View {
        Toggle("Difference from Average", isOn: $showsDeviation)
            .toggleStyle(.switch)
            .fixedSize()
        Button("Merge…", systemImage: "arrow.triangle.merge") { merging = true }
            .buttonStyle(.glass)
        Button("Done", action: onDone)
            .buttonStyle(.glassProminent)
    }
}

// MARK: - Look of each ride

/// Each column has a colour, a dash pattern and a marker shape, so rides stay apart for
/// colour-blind readers (NFR-16); colours as on the Mac, dashes and markers from the Kit.
enum PadCompareStyle {
    static let colors: [Color] = [
        .map(MapPalette.Pair(light: 0x0B6BCB, dark: 0x4DA3FF)),
        .map(MapPalette.Pair(light: 0xC2410C, dark: 0xFF8A4C)),
        .map(MapPalette.Pair(light: 0x0E7C6B, dark: 0x3CC7A6)),
        .map(MapPalette.Pair(light: 0x8E44AD, dark: 0xC38BEF)),
    ]

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
    let onOpen: (UUID) -> Void

    private static let labelWidth = 200.0

    var body: some View {
        VStack(spacing: 0) {
            headerRow.background(.quaternary.opacity(0.35))
            ForEach(ComparisonGroup.allCases) { group in
                let metrics = group.metrics.filter { metric in
                    comparison.values(metric).contains { $0 != nil }
                }
                if !metrics.isEmpty {
                    Text(CompareTexts.title(group))
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
                .frame(width: Self.labelWidth, alignment: .leading)
                .padding(.horizontal, 14)
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                Button { onOpen(ride.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        LegendMark(index: index)
                        Text(verbatim: ride.name).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
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
                Text("Your average").font(.headline)
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
            Text(CompareTexts.title(metric))
                .frame(width: Self.labelWidth, alignment: .leading)
                .padding(.horizontal, 14)
            ForEach(values.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(verbatim: values[index].map { CompareTexts.value($0, metric) } ?? "–")
                            .fontWeight(best.contains(index) ? .semibold : .regular)
                        if best.contains(index) {
                            Text(verbatim: "★").foregroundStyle(Color.track).accessibilityLabel(Text("Best"))
                        }
                    }
                    if showsDeviation, let deviation = comparison.deviation(metric, ride: index) {
                        Text(verbatim: CompareTexts.deviation(deviation, metric))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
            }
            Text(verbatim: comparison.averages[metric].map { CompareTexts.value($0, metric) } ?? "–")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
        }
        .font(.callout)
        .padding(.vertical, 7)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
        .accessibilityElement(children: .combine)
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
                    Label(CompareTexts.message(problem), systemImage: "exclamationmark.triangle")
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

// MARK: - Texts

/// The texts of the comparison on the iPad, the same words as on the Mac (rule 8: not in the Kit).
enum CompareTexts {
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

    /// A value in its display unit, e.g. "24,1 km/h" or "0:48:36".
    static func value(_ v: Double, _ metric: ComparisonMetric) -> String {
        switch metric {
        case .rideTime, .totalTime, .pausedTime: RideFormat.duration(v)
        default: "\(number(v, metric)) \(unit(metric))"
        }
    }

    /// "+2,1 km/h · +9 %"; durations as "+1:05 h" or "−8 min"; the coasting share in
    /// percentage points. The same text as on the Mac (`ComparisonFormat.deviation`).
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

    /// "12 min" or "1:05 h".
    private static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = total % 3600 / 60
        return hours > 0 ? String(format: "%d:%02d h", hours, minutes) : "\(minutes) min"
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

    static func message(_ problem: RideMerge.MergeError) -> LocalizedStringKey {
        switch problem {
        case .tooFewRides: "Select at least two rides to merge."
        case .overlapping: "These rides overlap in time and cannot be merged."
        case .containsSample: "The sample ride cannot be merged."
        }
    }
}
