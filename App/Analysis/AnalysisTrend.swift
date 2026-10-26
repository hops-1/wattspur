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
            TrendChart(
                points: points, title: title, unit: unit, factor: factor, digits: digits, color: color,
                xDomain: (model.chartInterval?.start ?? .now)...(model.chartInterval.map { min($0.end, max(.now, points.last?.date ?? .now)) } ?? .now)
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}
