import SwiftData
import SwiftUI
import WattspurKit

/// Right of the list while "Similar to" is on and no ride is selected: how the rides on this route
/// develop over time (B-120, ROUTE-06, TREND-01).
struct RouteHistoryView: View {
    let filter: SimilarRidesFilter
    /// A click on a point selects that ride.
    let onSelect: (UUID) -> Void
    /// "Analyze These Rides": opens the analysis with the rides of the history.
    let onAnalyze: ([UUID]) -> Void

    @Query(filter: Ride.listedPredicate) private var rides: [Ride]
    @Environment(RouteSimilarityStore.self) private var similarity
    @State private var metric: RouteHistory.Metric = .duration

    var body: some View {
        if let hits = similarity.hits(for: filter), let reference = rides.first(where: { $0.id == filter.referenceID }) {
            let ids = Set(hits.map(\.id)).union([reference.id])
            let history = RouteHistory(rides.filter { ids.contains($0.id) }.map(\.highlightRide))
            if history.rides.count < 2 {
                ContentUnavailableView {
                    Label("No History Yet", systemImage: "chart.xyaxis.line")
                } description: {
                    Text("A history needs at least two rides on this route. Lower the similarity or include both directions.")
                }
            } else {
                content(history, name: reference.name)
            }
        } else if similarity.referenceHasRoute(for: filter) == false {
            ContentUnavailableView("This ride has no route", systemImage: "location.slash")
        } else {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(_ history: RouteHistory, name: String) -> some View {
        let series = history.series(metric)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History").font(.largeTitle.bold())
                        Text("\(name) · \(history.rides.count) rides")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button("Analyze These Rides", systemImage: "chart.bar") {
                        onAnalyze(history.rides.map(\.id))
                    }
                    .buttonStyle(.glass)
                    .help(Text("Open the analysis with the rides on this route"))
                }
                Picker("Metric", selection: $metric) {
                    ForEach(RouteHistory.Metric.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(Text("Metric"))

                if series.points.isEmpty {
                    ContentUnavailableView {
                        Label("No Values", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("None of these rides has this value.")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    card(series)
                    figures(series)
                    legend
                    if !series.isComplete {
                        Text("\(series.count) of \(series.total) rides have this value.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func card(_ series: RouteHistory.Series) -> some View {
        let first = series.points.first?.date ?? .now
        let last = series.points.last?.date ?? .now
        // A little room on both sides, so the first and the last point are not on the border.
        let margin = max(last.timeIntervalSince(first) * 0.04, 86_400)
        return VStack(alignment: .leading, spacing: 10) {
            Text(metric.title).font(.title3.bold())
            TrendChart(points: series.points, title: metric.chartTitle, unit: metric.unit, factor: metric.factor,
                       digits: metric.digits, color: .accentColor,
                       xDomain: first.addingTimeInterval(-margin)...last.addingTimeInterval(margin), height: 240,
                       bestIndex: series.bestIndex, lastIndex: series.lastIndex) { index in
                if series.rideIDs.indices.contains(index) { onSelect(series.rideIDs[index]) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private func figures(_ series: RouteHistory.Series) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let best = series.best {
                figure(metric.bestTitle, value: metric.format(best.value), date: best.date,
                       icon: "star.fill", note: nil)
            }
            if let last = series.last {
                figure("Latest", value: metric.format(last.value), date: last.date,
                       icon: "circle", note: series.changeOfLast)
            }
            if let mean = series.mean {
                figure("Average", value: metric.format(mean), date: nil, icon: nil, note: nil)
            }
        }
    }

    private func figure(_ title: LocalizedStringKey, value: String, date: Date?, icon: String?, note: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.caption).accessibilityHidden(true) }
                Text(title).font(.caption)
            }
            .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            if let date {
                Text(date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note {
                ChangeLabel(change: note, caption: String(localized: "vs average"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .accessibilityElement(children: .combine)
    }

    /// What the marks mean; the chart says it with shapes, not only with colour.
    private var legend: some View {
        HStack(spacing: 14) {
            Label { Text("Per ride") } icon: { Circle().fill(Color.accentColor.opacity(0.45)).frame(width: 7, height: 7) }
            Label { Text("5-ride average") } icon: { Capsule().fill(Color.accentColor).frame(width: 16, height: 2.5) }
            Label { Text("Best") } icon: { Image(systemName: "star.fill").font(.caption2) }
            Label { Text("Latest") } icon: { Image(systemName: "circle").font(.caption2) }
            Spacer(minLength: 0)
            Text("Click a point to open the ride.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

extension RouteHistory.Metric {
    var title: LocalizedStringKey {
        switch self {
        case .duration: "Ride time"
        case .averageSpeed: "Avg speed"
        case .averagePower: "Avg power"
        case .averageCadence: "Avg cadence"
        }
    }

    var chartTitle: LocalizedStringResource {
        switch self {
        case .duration: "Ride time"
        case .averageSpeed: "Avg speed"
        case .averagePower: "Avg power"
        case .averageCadence: "Avg cadence"
        }
    }

    /// "Best time" for the ride time, "Best" for the others.
    var bestTitle: LocalizedStringKey { self == .duration ? "Best time" : "Best" }

    /// The chart shows the ride time in minutes and the speed in km/h.
    var factor: Double {
        switch self {
        case .duration: 1.0 / 60
        case .averageSpeed: 3.6
        default: 1
        }
    }

    var unit: String {
        switch self {
        case .duration: String(localized: "min")
        case .averageSpeed: "km/h"
        case .averagePower: "W"
        case .averageCadence: String(localized: "rpm")
        }
    }

    var digits: Int { self == .averageSpeed ? 1 : 0 }

    func format(_ value: Double) -> String {
        switch self {
        case .duration: RideFormat.duration(value)
        case .averageSpeed: RideFormat.speed(value)
        case .averagePower: "\(AnalysisFormat.number(value, digits: 0)) W"
        case .averageCadence: "\(AnalysisFormat.number(value, digits: 0)) \(unit)"
        }
    }
}
