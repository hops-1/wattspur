import Charts
import SwiftUI
import WattspurKit

/// Points per ride and a moving average over time (TREND-01), for the trends of the analysis and
/// the history of a route (B-120). Speed is stored in m/s: `factor` turns the values into the unit.
struct TrendChart: View {
    let points: [TrendPoint]
    let title: LocalizedStringResource
    let unit: String
    var factor = 1.0
    var digits = 0
    let color: Color
    let xDomain: ClosedRange<Date>
    var height: CGFloat = 150
    /// Positions in `points` of the best and the latest ride: a star and a ring, so the colour is
    /// never the only sign.
    var bestIndex: Int?
    var lastIndex: Int?
    /// A click on the chart passes the position of the nearest point.
    var onSelect: ((Int) -> Void)?

    var body: some View {
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
            if let lastIndex, points.indices.contains(lastIndex) {
                let point = points[lastIndex]
                PointMark(x: .value("Date", point.date), y: .value(unit, point.value * factor))
                    .symbol(.circle.strokeBorder(lineWidth: 2))
                    .symbolSize(170)
                    .foregroundStyle(color)
            }
            if let bestIndex, points.indices.contains(bestIndex) {
                let point = points[bestIndex]
                PointMark(x: .value("Date", point.date), y: .value(unit, point.value * factor))
                    .symbol {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(color)
                    }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { mark in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel {
                    if let v = mark.as(Double.self) { Text(verbatim: v.formatted(.number.precision(.fractionLength(0)))) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .allowsHitTesting(onSelect != nil)
                    .onTapGesture { location in
                        guard let onSelect, let frame = proxy.plotFrame,
                              let date: Date = proxy.value(atX: location.x - geometry[frame].origin.x),
                              let nearest = points.indices.min(by: {
                                  abs(points[$0].date.timeIntervalSince(date)) < abs(points[$1].date.timeIntervalSince(date))
                              }) else { return }
                        onSelect(nearest)
                    }
            }
        }
        .frame(height: height)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: summary))
        .accessibilityChartDescriptor(TrendChartDescriptor(
            title: String(localized: title), unit: unit, points: points, factor: factor, digits: digits
        ))
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map { $0.value * factor }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max(1, (hi - lo) * 0.15)
        return (lo - pad).rounded(.down)...(hi + pad).rounded(.up)
    }

    /// VoiceOver: "12 rides, moving average from 128 to 141 W".
    private var summary: String {
        guard let first = points.first, let last = points.last else { return String(localized: "No values") }
        return String(localized: "\(points.count) rides, moving average from \(AnalysisFormat.number(first.movingAverage * factor, digits: digits)) to \(AnalysisFormat.number(last.movingAverage * factor, digits: digits)) \(unit)")
    }
}
