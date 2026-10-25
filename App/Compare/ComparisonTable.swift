import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

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
