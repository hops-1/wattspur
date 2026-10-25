import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Trends (TREND-01)

struct TrendCard: View {
    let model: AnalysisModel
    let metric: TrendMetric
    let title: LocalizedStringResource
    let color: Color

    private static let window = 5

    /// Speed is stored in m/s and shown in km/h.
    private var factor: Double { metric == .averageSpeed ? 3.6 : 1 }
    private var unit: String {
        switch metric {
        case .averagePower: "W"
        case .averageCadence: String(localized: "rpm")
        case .averageSpeed: "km/h"
        }
    }
    private var digits: Int { metric == .averageSpeed ? 1 : 0 }

    var body: some View {
        let points = RideAnalysis.trend(model.figures, metric: metric, window: Self.window)
        let average = metric.value(of: model.current).map { $0 * factor }
        let change = model.change { metric.value(of: $0) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold())
                    HStack(spacing: 14) {
                        Label { Text("Per ride") } icon: { Circle().fill(color.opacity(0.45)).frame(width: 7, height: 7) }
                        Label { Text("5-ride average") } icon: { Capsule().fill(color).frame(width: 16, height: 2.5) }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.isSelection ? "Avg of selection" : "Avg in period").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: "\(AnalysisFormat.number(average, digits: digits)) \(unit)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                if let caption = model.comparisonCaption, change != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: caption).font(.caption).foregroundStyle(.secondary)
                        ChangeLabel(change: change)
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            Chart {
                ForEach(points, id: \.date) { point in
                    PointMark(x: .value("Date", point.date), y: .value(unit, point.value * factor))
                        .foregroundStyle(color.opacity(0.45))
                        .symbolSize(28)
                }
                ForEach(points, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value(unit, point.movingAverage * factor))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
            }
            .chartXScale(domain: (model.chartInterval?.start ?? .now)...(model.chartInterval.map { min($0.end, max(.now, points.last?.date ?? .now)) } ?? .now))
            .chartYScale(domain: yDomain(points))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { mark in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    AxisValueLabel {
                        if let v = mark.as(Double.self) { Text(verbatim: v.formatted(.number.precision(.fractionLength(0)))) }
                    }
                }
            }
            .frame(height: 150)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(verbatim: summary(points)))
            .accessibilityChartDescriptor(TrendChartDescriptor(
                title: String(localized: title), unit: unit, points: points, factor: factor, digits: digits
            ))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private func yDomain(_ points: [TrendPoint]) -> ClosedRange<Double> {
        let values = points.map { $0.value * factor }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max(1, (hi - lo) * 0.15)
        return (lo - pad).rounded(.down)...(hi + pad).rounded(.up)
    }

    /// VoiceOver: "12 rides, moving average from 128 to 141 W".
    private func summary(_ points: [TrendPoint]) -> String {
        guard let first = points.first, let last = points.last else { return String(localized: "No values") }
        return String(localized: "\(points.count) rides, moving average from \(AnalysisFormat.number(first.movingAverage * factor, digits: digits)) to \(AnalysisFormat.number(last.movingAverage * factor, digits: digits)) \(unit)")
    }
}
