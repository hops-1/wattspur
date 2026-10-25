import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Figures

struct TotalsGrid: View {
    let model: AnalysisModel

    var body: some View {
        let c = model.current
        let caption = model.comparisonCaption
        VStack(alignment: .leading, spacing: 12) {
            Text("Totals").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 20) {
                GridRow {
                    StatTile("Rides", value: c.rideCount.formatted(),
                             change: model.change { Double($0.rideCount) }, caption: caption)
                    StatTile("Distance", value: RideFormat.distanceValue(c.distance), unit: "km",
                             change: model.change { $0.distance }, caption: caption)
                    StatTile("Ride time", value: AnalysisFormat.hoursMinutes(c.timerTime),
                             change: model.change { $0.timerTime }, caption: caption)
                    StatTile("Ascent", value: AnalysisFormat.whole(c.ascentIfKnown), unit: "m",
                             coverage: c.ascentCoverage, change: model.change { $0.ascentIfKnown }, caption: caption)
                }
                GridRow {
                    StatTile("Work", value: AnalysisFormat.whole(c.workKilojoulesIfKnown), unit: "kJ",
                             coverage: c.powerCoverage, change: model.change { $0.workKilojoulesIfKnown }, caption: caption)
                    StatTile("Calories", value: AnalysisFormat.whole(c.kilocaloriesIfKnown), unit: "kcal",
                             estimated: !c.powerCoverage.isNone, note: model.calories.note, coverage: c.powerCoverage,
                             change: model.change { $0.kilocaloriesIfKnown }, caption: caption)
                    StatTile("CO₂ saved", value: c.co2SavedKilograms.formatted(.number.precision(.fractionLength(1))), unit: "kg",
                             estimated: true, change: model.change { $0.co2SavedKilograms }, caption: caption)
                    StatTile("Avg per ride", value: RideFormat.distanceValue(c.distancePerRide ?? 0), unit: "km",
                             change: model.change { $0.distancePerRide }, caption: caption)
                }
            }
        }
    }
}

struct AveragesCard: View {
    let model: AnalysisModel

    var body: some View {
        let c = model.current
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Averages").font(.subheadline.weight(.semibold))
                Text("Speed, power and cadence weighted by ride time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                GridRow {
                    StatTile("Avg speed", value: RideFormat.speedValue(c.averageSpeed), unit: "km/h", dot: .metricSpeed,
                             compact: true, change: model.change { $0.averageSpeed })
                    StatTile("Avg power", value: AnalysisFormat.whole(c.averagePower), unit: "W", dot: .metricPower,
                             compact: true, coverage: c.powerCoverage, change: model.change { $0.averagePower })
                    StatTile("Avg cadence", value: AnalysisFormat.whole(c.averageCadence), unit: String(localized: "rpm"),
                             dot: .metricCadence, compact: true, coverage: c.cadenceCoverage, change: model.change { $0.averageCadence })
                    StatTile("Avg ride time", value: AnalysisFormat.hoursMinutes(c.timerTimePerRide ?? 0),
                             compact: true, change: model.change { $0.timerTimePerRide })
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A key figure with an optional change to the previous period.
private struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    var unit = ""
    var dot: Color?
    var estimated = false
    /// The text of the info next to an estimate.
    var note = String(localized: "Estimated from your pedal power")
    var compact = false
    /// For how many of the rides the value exists; "9 of 12 rides" under it when not for all (B-146).
    var coverage: ValueCoverage?
    var change: Double?
    var caption: String?

    init(_ label: LocalizedStringKey, value: String, unit: String = "", dot: Color? = nil, estimated: Bool = false,
         note: String? = nil, compact: Bool = false, coverage: ValueCoverage? = nil, change: Double? = nil, caption: String? = nil) {
        if let note { self.note = note }
        self.label = label
        self.value = value
        self.unit = unit
        self.dot = dot
        self.estimated = estimated
        self.compact = compact
        self.coverage = coverage
        self.change = change
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let dot {
                    Circle().fill(dot).frame(width: 8, height: 8).accessibilityHidden(true)
                }
                Text(label)
                if estimated {
                    Image(systemName: "info.circle")
                        .help(Text(verbatim: note))
                        .accessibilityLabel(Text(verbatim: note))
                }
            }
            .font(compact ? .caption : .subheadline)
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value).font(.system(size: compact ? 22 : 28, weight: .semibold))
                if !unit.isEmpty {
                    Text(verbatim: unit).foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            if let coverage { CoverageNote(coverage: coverage) }
            ChangeLabel(change: change, caption: caption)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "▲ +12 % vs September". Arrow and sign carry the direction, colour only supports it (NFR-16).
/// Only the arrow is tinted: accent-coloured small text stays below 4.5 : 1 on white.
struct ChangeLabel: View {
    let change: Double?
    var caption: String?

    private var isIncrease: Bool { (change ?? 0) * 100 >= 0.5 }

    var body: some View {
        HStack(spacing: 4) {
            if let change {
                let rounded = (change * 100).rounded()
                if rounded != 0 {
                    Image(systemName: rounded > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isIncrease ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        .accessibilityHidden(true)
                }
                Text(verbatim: AnalysisFormat.percent(change))
                if let caption { Text(verbatim: caption) }
            } else if caption != nil {
                Text("no comparison")
            }
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(isIncrease ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .frame(minHeight: 16, alignment: .leading)
    }
}
