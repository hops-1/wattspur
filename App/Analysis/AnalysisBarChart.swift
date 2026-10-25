import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Bar chart (AGG-04, TREND-02)

enum BarMetric: String, CaseIterable, Identifiable {
    case distance, time, ascent

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .distance: "Distance"
        case .time: "Ride time"
        case .ascent: "Ascent"
        }
    }

    /// km, hours or metres.
    func value(_ aggregate: RideAggregate) -> Double {
        switch self {
        case .distance: aggregate.distance / 1000
        case .time: aggregate.timerTime / 3600
        case .ascent: aggregate.ascent
        }
    }

    func formatted(_ aggregate: RideAggregate) -> String {
        switch self {
        case .distance: RideFormat.distance(aggregate.distance)
        case .time: AnalysisFormat.hoursMinutes(aggregate.timerTime)
        case .ascent: "\(aggregate.ascent.formatted(.number.precision(.fractionLength(0)))) m"
        }
    }

    /// The label as a plain string, for VoiceOver's chart description.
    var title: String {
        switch self {
        case .distance: String(localized: "Distance")
        case .time: String(localized: "Ride time")
        case .ascent: String(localized: "Ascent")
        }
    }

    var axisUnit: String {
        switch self {
        case .distance: "km"
        case .time: "h"
        case .ascent: "m"
        }
    }
}

struct BarChartCard: View {
    let model: AnalysisModel
    @Binding var metric: BarMetric
    @Binding var grouping: AnalysisGrouping
    @State private var selectedDate: Date?

    /// The clicked bar, else the latest one that has started.
    private var pickedIndex: Int? {
        let buckets = model.buckets
        if let selectedDate, let i = buckets.firstIndex(where: { $0.interval.contains(selectedDate) }) { return i }
        return buckets.lastIndex { $0.interval.start <= .now } ?? buckets.indices.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(metric.label).font(.title3.bold())
                    Text(grouping.perLabel).font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(BarMetric.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Picker("Group by", selection: $grouping) {
                    ForEach(AnalysisGrouping.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            pickedSummary
            chart
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
        .onChange(of: grouping) { selectedDate = nil }
    }

    @ViewBuilder
    private var pickedSummary: some View {
        if let i = pickedIndex {
            let bucket = model.buckets[i]
            let before = i > 0 ? model.buckets[i - 1] : nil
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: AnalysisFormat.bucketTitle(bucket.interval, grouping: grouping, calendar: model.calendar))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(metric.formatted(bucket.aggregate)) · \(String(localized: "\(bucket.aggregate.rideCount) rides"))")
                    .font(.headline)
                    .monospacedDigit()
                if let before {
                    ChangeLabel(
                        change: Change.relative(from: metric.value(before.aggregate), to: metric.value(bucket.aggregate)),
                        caption: String(localized: "vs \(AnalysisFormat.bucketShort(before.interval.start, grouping: grouping, calendar: model.calendar, multiYear: false))")
                    )
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var chart: some View {
        let picked = pickedIndex
        let multiYear = model.buckets.first.map { model.calendar.component(.year, from: $0.interval.start) }
            != model.buckets.last.map { model.calendar.component(.year, from: $0.interval.start) }
        return Chart(Array(model.buckets.enumerated()), id: \.element.id) { index, bucket in
            BarMark(
                x: .value("Period", bucket.interval.start, unit: grouping.component),
                y: .value(metric.axisUnit, metric.value(bucket.aggregate))
            )
            .foregroundStyle(index == picked ? Color.accentColor : Color.chartInactive)
            .cornerRadius(3)
            .accessibilityLabel(AnalysisFormat.bucketTitle(bucket.interval, grouping: grouping, calendar: model.calendar))
            .accessibilityValue(metric.formatted(bucket.aggregate))
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 12)) { mark in
                AxisValueLabel {
                    if let date = mark.as(Date.self) {
                        Text(verbatim: AnalysisFormat.bucketShort(date, grouping: grouping, calendar: model.calendar, multiYear: multiYear))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { mark in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel {
                    if let v = mark.as(Double.self) {
                        Text(verbatim: "\(v.formatted(.number.precision(.fractionLength(0)))) \(metric.axisUnit)")
                    }
                }
            }
        }
        .frame(height: 200)
        .accessibilityChartDescriptor(BarChartDescriptor(
            title: metric.title, unit: metric.axisUnit,
            bars: model.buckets.map {
                (AnalysisFormat.bucketTitle($0.interval, grouping: grouping, calendar: model.calendar),
                 metric.value($0.aggregate), metric.formatted($0.aggregate))
            }
        ))
        // Keyboard: focus the chart with Tab, then pick a bar with the arrow keys.
        .focusable()
        .onKeyPress(.leftArrow) { pick(by: -1) }
        .onKeyPress(.rightArrow) { pick(by: 1) }
    }

    private func pick(by delta: Int) -> KeyPress.Result {
        guard let i = pickedIndex, model.buckets.indices.contains(i + delta) else { return .ignored }
        selectedDate = model.buckets[i + delta].interval.start
        return .handled
    }
}
