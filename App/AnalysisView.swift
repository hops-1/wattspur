import Charts
import SwiftData
import SwiftUI
import WattspurKit

/// The "Analysis" section (v0.2): period at the top, then sums, time-weighted averages,
/// a bar chart and trend charts (AGG-01 … AGG-04, TREND-01, TREND-02).
///
/// With `selection` it analyses exactly these rides instead of a period (LIST-06).
struct AnalysisView: View {
    var selection: Set<UUID>?
    var onClearSelection: () -> Void = {}
    /// "Show on Map": the map shows exactly the analysed rides (wish from Nils, v1.4).
    var onShowOnMap: (Set<UUID>) -> Void = { _ in }
    /// The analysed rides, for the list beside the analysis (B-124).
    var onAnalysedRidesChange: (Set<UUID>) -> Void = { _ in }

    @Query(filter: Ride.listedPredicate, sort: \Ride.startDate)
    private var allRides: [Ride]

    /// Rides picked by hand are analysed whatever their bike; otherwise the filter applies.
    private var rides: [Ride] {
        guard selection == nil else { return allRides }
        let filter = bikeFilterChoice.resolved(knownBikeIDs: Set(bikes.map(\.id)))
        let source = sourceFilterChoice.resolved(hasGPXRides: hasGPXRides)
        return filter.isActive || source.isActive ? allRides.filter { $0.isOnBike(filter) && $0.isFromSource(source) } : allRides
    }

    private var hasGPXRides: Bool { allRides.contains { $0.source == .gpx } }

    @AppStorage("analysisPeriod") private var kind: AnalysisPeriodKind = .year
    @AppStorage("analysisBarMetric") private var barMetric: BarMetric = .distance
    /// The bike filter of the analysis, remembered (B-137).
    @AppStorage("bikeFilter.analysis") private var bikeFilterChoice: BikeFilter = .all
    /// The source filter of the analysis, the same way (B-145).
    @AppStorage("sourceFilter.analysis") private var sourceFilterChoice: SourceFilter = .all
    @Query private var bikes: [Bike]
    /// "From pedal power" or "with profile" (SET-06, B-067).
    @AppStorage("calorieMode") private var calorieMode: CalorieMode = .fromWork
    @Query private var riders: [Rider]
    @State private var offset = 0
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd = Date.now
    /// `nil` = the grouping that fits the period.
    @State private var groupingChoice: AnalysisGrouping?

    private var calendar: Calendar { .current }

    private var period: AnalysisPeriod {
        let start = calendar.startOfDay(for: min(customStart, customEnd))
        let endDay = calendar.startOfDay(for: max(customStart, customEnd))
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return AnalysisPeriod(kind: kind, offset: offset, customInterval: DateInterval(start: start, end: end))
    }

    var body: some View {
        let model = AnalysisModel(rides: rides, selection: selection, period: period,
                                  groupingChoice: groupingChoice, calendar: calendar,
                                  calories: CalorieModel(mode: calorieMode, rider: riders.first))
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 28)
                .frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: model.heading).font(.largeTitle.bold())
                            Text(verbatim: model.subheading).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let ids = analysedRideIDs
                        Button("Show on Map", systemImage: "map") { onShowOnMap(ids) }
                            .buttonStyle(.link)
                            .disabled(ids.isEmpty)
                            .help(Text("Show exactly these rides on the map"))
                    }
                    if model.current.rideCount == 0 {
                        ContentUnavailableView("No Rides in This Period", systemImage: "chart.bar",
                                               description: Text("Choose another period or import rides."))
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        TotalsGrid(model: model)
                        AveragesCard(model: model)
                        BarChartCard(model: model, metric: $barMetric,
                                     grouping: Binding(get: { model.grouping }, set: { groupingChoice = $0 }))
                        trends(model)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: kind) {
            offset = 0
            groupingChoice = nil
        }
        .onChange(of: analysedRideIDs, initial: true) { onAnalysedRidesChange($1) }
    }

    /// The rides the analysis shows: the selection, or the period's rides without
    /// the sample ride, as in `AnalysisModel`.
    private var analysedRideIDs: Set<UUID> {
        if let selection { return selection }
        let interval = period.interval(calendar: calendar)
        return Set(rides.filter { !$0.isSample && (interval?.contains($0.startDate) ?? true) }.map(\.id))
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            if selection != nil {
                selectionChip
            } else {
                Picker("Period", selection: $kind) {
                    ForEach(AnalysisPeriodKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                BikeFilterMenu(filter: $bikeFilterChoice)
                SourceFilterMenu(filter: $sourceFilterChoice, hasGPXRides: hasGPXRides)
                if kind.isSteppable {
                    HStack(spacing: 4) {
                        Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                            .help(Text("Previous period"))
                            .accessibilityLabel(Text("Previous period"))
                            .keyboardShortcut(.leftArrow, modifiers: .command)
                        Button { offset = min(0, offset + 1) } label: { Image(systemName: "chevron.right") }
                            .disabled(offset >= 0)
                            .help(Text("Next period"))
                            .accessibilityLabel(Text("Next period"))
                            .keyboardShortcut(.rightArrow, modifiers: .command)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
                if kind == .custom {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                        .fixedSize()
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                        .fixedSize()
                }
            }
            Spacer()
        }
    }

    private var selectionChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.square")
            Text("\(selection?.count ?? 0) selected rides")
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help(Text("Analyze all rides instead"))
            .accessibilityLabel(Text("Analyze all rides instead"))
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
    }

    // MARK: Trends

    @ViewBuilder
    private func trends(_ model: AnalysisModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Trends").font(.title2.bold())
            Text("Average of each ride, with a moving average over 5 rides")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        TrendCard(model: model, metric: .averagePower, title: "Avg power", color: .metricPower)
        TrendCard(model: model, metric: .averageCadence, title: "Avg cadence", color: .metricCadence)
        TrendCard(model: model, metric: .averageSpeed, title: "Avg speed", color: .metricSpeed)
    }
}

// MARK: - Model

/// Everything the analysis shows, computed once per redraw from the rides and the period.
struct AnalysisModel {
    let calendar: Calendar
    /// How calories are estimated; the info next to them says so.
    let calories: CalorieModel
    let isSelection: Bool
    let kind: AnalysisPeriodKind
    /// The analysed rides, oldest first.
    let figures: [RideFigures]
    let current: RideAggregate
    /// `nil` when there is nothing to compare with ("all" or a selection).
    let previous: RideAggregate?
    let previousInterval: DateInterval?
    /// The span the charts cover.
    let chartInterval: DateInterval?
    let grouping: AnalysisGrouping
    let buckets: [RideBucket]
    let heading: String
    let subheading: String

    init(rides: [Ride], selection: Set<UUID>?, period: AnalysisPeriod, groupingChoice: AnalysisGrouping?,
         calendar: Calendar, calories: CalorieModel = .fromWork, now: Date = .now) {
        self.calendar = calendar
        self.calories = calories
        // The sample ride counts only when it was selected on purpose (ONB-02).
        let all = rides.filter { !$0.isSample }.map(\.figures)
        isSelection = selection != nil
        kind = period.kind
        let selected: [RideFigures]
        let chartSpan: DateInterval?
        if let selection {
            selected = RideAnalysis.rides(rides.filter { selection.contains($0.id) }.map(\.figures), in: nil)
            previousInterval = nil
            if let first = selected.first, let week = calendar.dateInterval(of: .weekOfYear, for: first.startDate) {
                let lastStart = selected.last?.startDate ?? first.startDate
                chartSpan = DateInterval(start: week.start, end: max(week.end, lastStart.addingTimeInterval(1)))
            } else {
                chartSpan = nil
            }
            grouping = groupingChoice ?? .week
        } else {
            let interval = period.interval(now: now, calendar: calendar)
            selected = RideAnalysis.rides(all, in: interval)
            previousInterval = period.previousInterval(now: now, calendar: calendar)
            chartSpan = interval ?? RideAnalysis.span(of: all, now: now)
            grouping = groupingChoice ?? period.kind.defaultGrouping
        }
        let groupedBy = grouping
        figures = selected
        chartInterval = chartSpan
        current = RideAggregate(selected, calories: calories)
        previous = previousInterval.map { RideAggregate(RideAnalysis.rides(all, in: $0), calories: calories) }
        buckets = chartSpan.map { RideAnalysis.buckets(selected, grouping: groupedBy, in: $0, calendar: calendar) } ?? []

        let count = current.rideCount
        if isSelection {
            heading = String(localized: "\(count) selected rides")
            subheading = String(localized: "Selected in Rides")
        } else {
            let interval = period.interval(now: now, calendar: calendar)
            heading = Self.title(kind: period.kind, interval: interval, calendar: calendar)
            if let previousInterval {
                let name = Self.previousName(kind: period.kind, interval: previousInterval, calendar: calendar)
                subheading = String(localized: "\(count) rides · compared with \(name)")
            } else {
                subheading = String(localized: "\(count) rides")
            }
        }
    }

    /// "vs September" under each figure.
    var comparisonCaption: String? {
        previousInterval.map { String(localized: "vs \(Self.previousName(kind: kind, interval: $0, calendar: calendar))") }
    }

    func change(_ value: (RideAggregate) -> Double?) -> Double? {
        guard let previous else { return nil }
        return Change.relative(from: value(previous), to: value(current))
    }

    static func title(kind: AnalysisPeriodKind, interval: DateInterval?, calendar: Calendar) -> String {
        guard let interval else { return String(localized: "All Rides") }
        let range = interval.start..<interval.end.addingTimeInterval(-1)
        switch kind {
        case .week:
            let week = calendar.component(.weekOfYear, from: interval.start)
            return String(localized: "Week \(week) · \(range.formatted(.interval.day().month(.abbreviated)))")
        case .month: return interval.start.formatted(.dateTime.month(.wide).year())
        case .year: return interval.start.formatted(.dateTime.year())
        case .custom, .all: return range.formatted(.interval.day().month(.abbreviated).year())
        }
    }

    static func previousName(kind: AnalysisPeriodKind, interval: DateInterval, calendar: Calendar) -> String {
        switch kind {
        case .week: String(localized: "week \(calendar.component(.weekOfYear, from: interval.start))")
        case .month: interval.start.formatted(.dateTime.month(.wide))
        case .year: interval.start.formatted(.dateTime.year())
        case .custom, .all: String(localized: "the same length before")
        }
    }
}

// MARK: - Figures

private struct TotalsGrid: View {
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

private struct AveragesCard: View {
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

private struct BarChartCard: View {
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

// MARK: - Trends (TREND-01)

private struct TrendCard: View {
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

// MARK: - Formatting and labels

enum AnalysisFormat {
    /// "38 h 12 min" in the user's locale.
    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        Duration.seconds((seconds / 60).rounded() * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func whole(_ value: Double?) -> String { number(value, digits: 0) }

    static func number(_ value: Double?, digits: Int) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(digits))) } ?? "–"
    }

    /// "+12 %", "−3 %", "±0 %"
    static func percent(_ change: Double) -> String {
        let rounded = (change * 100).rounded()
        let sign = rounded > 0 ? "+" : (rounded < 0 ? "−" : "±")
        return "\(sign)\(abs(change).formatted(.percent.precision(.fractionLength(0))))"
    }

    /// Axis label of a bar: "Mon", "W42", "Oct", "2026".
    static func bucketShort(_ date: Date, grouping: AnalysisGrouping, calendar: Calendar, multiYear: Bool) -> String {
        switch grouping {
        case .day: date.formatted(.dateTime.weekday(.abbreviated))
        case .week: String(localized: "W\(calendar.component(.weekOfYear, from: date))")
        case .month: multiYear ? date.formatted(.dateTime.month(.abbreviated).year(.twoDigits)) : date.formatted(.dateTime.month(.abbreviated))
        case .year: date.formatted(.dateTime.year())
        }
    }

    /// Title of the picked bar: "Monday, 19 October", "Week 42 (12–18 Oct)", "October 2026", "2026".
    static func bucketTitle(_ interval: DateInterval, grouping: AnalysisGrouping, calendar: Calendar) -> String {
        switch grouping {
        case .day: return interval.start.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .week:
            let week = calendar.component(.weekOfYear, from: interval.start)
            let range = (interval.start..<interval.end.addingTimeInterval(-1)).formatted(.interval.day().month(.abbreviated))
            return String(localized: "Week \(week) (\(range))")
        case .month: return interval.start.formatted(.dateTime.month(.wide).year())
        case .year: return interval.start.formatted(.dateTime.year())
        }
    }
}

extension AnalysisPeriodKind {
    var label: LocalizedStringKey {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .custom: "Custom"
        case .all: "All"
        }
    }
}

extension AnalysisGrouping {
    var label: LocalizedStringKey {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    var perLabel: LocalizedStringKey {
        switch self {
        case .day: "per day"
        case .week: "per week"
        case .month: "per month"
        case .year: "per year"
        }
    }
}

// MARK: - Several rides selected in the list (LIST-06)

/// Shown instead of the ride detail when several rides are selected.
struct MultiSelectionView: View {
    let rideIDs: Set<UUID>
    let onAnalyze: () -> Void
    /// Opens the comparison; only for 2–4 rides (CMP-01).
    let onCompare: () -> Void
    /// Called with the merged ride (B-095).
    let onMerged: (UUID) -> Void

    @Query(filter: Ride.listedPredicate) private var rides: [Ride]
    @State private var merging: MergeCandidates?
    @Environment(\.undoManager) private var undoManager

    private var canCompare: Bool { RideComparison.canCompare(count: rideIDs.count) }

    var body: some View {
        let aggregate = RideAggregate(rides.filter { rideIDs.contains($0.id) }.map(\.figures))
        ContentUnavailableView {
            Label("\(rideIDs.count) rides selected", systemImage: "square.stack")
        } description: {
            Text(verbatim: "\(RideFormat.distance(aggregate.distance)) · \(AnalysisFormat.hoursMinutes(aggregate.timerTime))")
                .monospacedDigit()
        } actions: {
            Button(action: onAnalyze) {
                Label("Analyze Selected Rides", systemImage: "chart.bar")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut("a", modifiers: [.command, .shift])
            Button(action: onCompare) {
                Label("Compare", systemImage: "tablecells")
            }
            .buttonStyle(.glass)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!canCompare)
            Button { merging = MergeCandidates(ids: rideIDs) } label: {
                Label("Merge…", systemImage: "arrow.triangle.merge")
            }
            .buttonStyle(.glass)
            BikeAssignMenu(rides: rides.filter { rideIDs.contains($0.id) }) {
                Label("Assign Bike", systemImage: "bicycle")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            if canCompare {
                Text("Compare: ⇧⌘C · Merge only rides that do not overlap in time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("You can compare 2 to 4 rides. Deselect some rides first.")
                    .font(.caption.weight(.semibold))
                Text("Merge only rides that do not overlap in time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $merging) { candidates in
            MergeRidesSheet(rideIDs: candidates.ids, undoManager: undoManager, onMerged: onMerged)
        }
    }
}
