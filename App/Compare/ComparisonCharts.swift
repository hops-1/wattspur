import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

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
