import Charts
import SwiftUI
import WattspurCore
import WattspurKit
import WattspurMap

/// "Analysis" on the iPad (B-295), like the Mac's section: a period at the top, then totals with
/// the change to the period before, time-weighted averages, a bar chart and trends. The numbers come
/// from the Kit (`AnalysisSummary`, B-294); only the texts and the layout are here.
struct PadAnalysisView: View {
    @Environment(PhoneLibrary.self) private var library
    @ShownSport private var sport
    @AppStorage(PhoneSettingsKey.padAnalysisPeriod) private var kind: AnalysisPeriodKind = .year
    @AppStorage(PhoneSettingsKey.padAnalysisBarMetric) private var barMetric: BarMetric = .distance
    @AppStorage(PhoneSettingsKey.padAnalysisDevice) private var deviceFilter: BikeFilter = .all
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

    private var devices: [RideExchange.Bike] { library.state?.devices(of: sport) ?? [] }

    var body: some View {
        let filter = deviceFilter.resolved(knownBikeIDs: Set(devices.map(\.id)))
        let rides = library.statsRides.filter { $0.sport == sport && filter.admits(bikeID: $0.deviceID) }
        let summary = AnalysisSummary(all: rides.map(\.figures), selected: nil, period: period,
                                      groupingChoice: groupingChoice, calendar: calendar,
                                      calories: .fromWork)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                controls
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: AnalysisTexts.heading(summary))
                        .font(.largeTitle.bold())
                    Text(verbatim: AnalysisTexts.subheading(summary))
                        .foregroundStyle(.secondary)
                }
                if summary.current.rideCount == 0 {
                    ContentUnavailableView("No Rides in This Period", systemImage: "chart.bar",
                                           description: Text("Choose another period or import rides."))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    PadTotals(summary: summary, sport: sport)
                    PadAverages(summary: summary, sport: sport)
                    PadBarChart(summary: summary, metric: $barMetric,
                                grouping: Binding(get: { summary.grouping }, set: { groupingChoice = $0 }))
                    trends(summary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Analysis")
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: kind) {
            offset = 0
            groupingChoice = nil
        }
        .onChange(of: sport) { deviceFilter = .all }
    }

    // MARK: Controls

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { controlItems }
            VStack(alignment: .leading, spacing: 12) { controlItems }
        }
    }

    @ViewBuilder private var controlItems: some View {
        Picker("Period", selection: $kind) {
            ForEach(AnalysisPeriodKind.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        if kind.isSteppable {
            HStack(spacing: 6) {
                Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel(Text("Previous period"))
                Button { offset = min(0, offset + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(offset >= 0)
                    .accessibilityLabel(Text("Next period"))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        if kind == .custom {
            DatePicker("From", selection: $customStart, displayedComponents: .date).fixedSize()
            DatePicker("To", selection: $customEnd, displayedComponents: .date).fixedSize()
        }
        if devices.count >= 2 {
            Picker(selection: $deviceFilter) {
                Text(sport.allDevicesTitle).tag(BikeFilter.all)
                ForEach(devices) { Text(verbatim: $0.name).tag(BikeFilter.bike($0.id)) }
            } label: {
                Text(sport.deviceFilterTitle)
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    // MARK: Trends

    @ViewBuilder private func trends(_ summary: AnalysisSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trends").font(.title2.bold())
            Text("Average of each ride, with a moving average over 5 rides")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
        if sport == .cycling {
            PadTrendCard(summary: summary, metric: .averagePower, title: "Avg power", color: .metricPower)
            PadTrendCard(summary: summary, metric: .averageCadence, title: "Avg cadence", color: .metricCadence)
        }
        PadTrendCard(summary: summary, metric: .averageSpeed, title: "Avg speed", color: .metricSpeed)
    }
}

// MARK: - Figures

/// The totals with the change to the period before, as on the Mac (AGG-01, AGG-02).
private struct PadTotals: View {
    let summary: AnalysisSummary
    let sport: Sport

    var body: some View {
        let c = summary.current
        let caption = AnalysisTexts.comparisonCaption(summary)
        VStack(alignment: .leading, spacing: 12) {
            Text("Totals").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 24, alignment: .leading)],
                      alignment: .leading, spacing: 20) {
                AnalysisFigure("Rides", value: c.rideCount.formatted(),
                       change: summary.change { Double($0.rideCount) }, caption: caption)
                AnalysisFigure("Distance", value: AnalysisTexts.number(c.distance / 1000, digits: 1), unit: "km",
                       change: summary.change { $0.distance }, caption: caption)
                AnalysisFigure("Ride time", value: AnalysisTexts.hoursMinutes(c.timerTime),
                       change: summary.change { $0.timerTime }, caption: caption)
                AnalysisFigure("Ascent", value: AnalysisTexts.whole(c.ascentIfKnown), unit: "m",
                       change: summary.change { $0.ascentIfKnown }, caption: caption)
                if sport == .cycling {
                    AnalysisFigure("Work", value: AnalysisTexts.whole(c.workKilojoulesIfKnown), unit: "kJ",
                           change: summary.change { $0.workKilojoulesIfKnown }, caption: caption)
                    AnalysisFigure("Calories", value: AnalysisTexts.whole(c.kilocaloriesIfKnown), unit: "kcal",
                           change: summary.change { $0.kilocaloriesIfKnown }, caption: caption)
                    AnalysisFigure("CO₂ saved", value: c.co2SavedKilograms.formatted(.number.precision(.fractionLength(1))),
                           unit: "kg", change: summary.change { $0.co2SavedKilograms }, caption: caption)
                }
                AnalysisFigure("Avg per ride", value: AnalysisTexts.number((c.distancePerRide ?? 0) / 1000, digits: 1), unit: "km",
                       change: summary.change { $0.distancePerRide }, caption: caption)
            }
        }
    }
}

/// Speed, power and cadence weighted by ride time (AGG-03).
private struct PadAverages: View {
    let summary: AnalysisSummary
    let sport: Sport

    var body: some View {
        let c = summary.current
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Averages").font(.subheadline.weight(.semibold))
                Text(sport == .cycling ? "Speed, power and cadence weighted by ride time" : "Speed weighted by ride time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 24, alignment: .leading)],
                      alignment: .leading, spacing: 12) {
                AnalysisFigure("Avg speed", value: AnalysisTexts.number(c.averageSpeed.map { $0 * 3.6 }, digits: 1), unit: "km/h",
                       dot: .metricSpeed, compact: true, change: summary.change { $0.averageSpeed })
                if sport == .cycling {
                    AnalysisFigure("Avg power", value: AnalysisTexts.whole(c.averagePower), unit: "W", dot: .metricPower,
                           compact: true, change: summary.change { $0.averagePower })
                    AnalysisFigure("Avg cadence", value: AnalysisTexts.whole(c.averageCadence), unit: String(localized: "rpm"),
                           dot: .metricCadence, compact: true, change: summary.change { $0.averageCadence })
                }
                AnalysisFigure("Avg ride time", value: AnalysisTexts.hoursMinutes(c.timerTimePerRide ?? 0),
                       compact: true, change: summary.change { $0.timerTimePerRide })
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A key figure with the change to the period before.
private struct AnalysisFigure: View {
    let label: LocalizedStringKey
    let value: String
    var unit: String
    var dot: Color?
    var compact: Bool
    var change: Double?
    var caption: String?

    init(_ label: LocalizedStringKey, value: String, unit: String = "", dot: Color? = nil, compact: Bool = false,
         change: Double? = nil, caption: String? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
        self.dot = dot
        self.compact = compact
        self.change = change
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 8, height: 8).accessibilityHidden(true) }
                Text(label)
            }
            .font(compact ? .caption : .subheadline)
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value).font(.system(size: compact ? 22 : 28, weight: .semibold))
                if !unit.isEmpty { Text(verbatim: unit).foregroundStyle(.secondary) }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            PadChangeLabel(change: change, caption: caption)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "▲ +12 % vs September". Arrow and sign carry the direction, colour only supports it (NFR-16).
struct PadChangeLabel: View {
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
                        .foregroundStyle(isIncrease ? AnyShapeStyle(Color.track) : AnyShapeStyle(.secondary))
                        .accessibilityHidden(true)
                }
                Text(verbatim: AnalysisTexts.percent(change))
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

// MARK: - Bar chart

/// Distance, ride time or ascent per day, week, month or year (AGG-04, TREND-02); a tap picks a bar.
private struct PadBarChart: View {
    let summary: AnalysisSummary
    @Binding var metric: BarMetric
    @Binding var grouping: AnalysisGrouping
    @State private var selectedDate: Date?

    /// The tapped bar, else the latest one that has started.
    private var pickedIndex: Int? {
        let buckets = summary.buckets
        if let selectedDate, let i = buckets.firstIndex(where: { $0.interval.contains(selectedDate) }) { return i }
        return buckets.lastIndex { $0.interval.start <= .now } ?? buckets.indices.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    title
                    Spacer()
                    pickers
                }
                VStack(alignment: .leading, spacing: 8) {
                    title
                    HStack(spacing: 12) { pickers }
                }
            }
            if let i = pickedIndex {
                picked(i)
            }
            chart
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.label).font(.title3.bold())
            Text(grouping.perLabel).font(.title3).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var pickers: some View {
        Picker("Metric", selection: $metric) {
            ForEach(BarMetric.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        Picker("Group by", selection: $grouping) {
            ForEach(AnalysisGrouping.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func picked(_ i: Int) -> some View {
        let bucket = summary.buckets[i]
        let before = i > 0 ? summary.buckets[i - 1] : nil
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: AnalysisTexts.bucketTitle(bucket.interval, grouping: grouping, calendar: summary.calendar))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(metric.formatted(bucket.aggregate)) · \(String(localized: "\(bucket.aggregate.rideCount) rides"))")
                .font(.headline)
                .monospacedDigit()
            if let before {
                PadChangeLabel(
                    change: Change.relative(from: metric.value(before.aggregate), to: metric.value(bucket.aggregate)),
                    caption: String(localized: "vs \(AnalysisTexts.bucketShort(before.interval.start, grouping: grouping, calendar: summary.calendar, multiYear: false))")
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        let picked = pickedIndex
        let calendar = summary.calendar
        let multiYear = summary.buckets.first.map { calendar.component(.year, from: $0.interval.start) }
            != summary.buckets.last.map { calendar.component(.year, from: $0.interval.start) }
        return Chart(Array(summary.buckets.enumerated()), id: \.element.id) { index, bucket in
            BarMark(
                x: .value("Period", bucket.interval.start, unit: grouping.component),
                y: .value(metric.axisUnit, metric.value(bucket.aggregate))
            )
            .foregroundStyle(index == picked ? Color.track : Color.secondary.opacity(0.45))
            .cornerRadius(3)
            .accessibilityLabel(AnalysisTexts.bucketTitle(bucket.interval, grouping: grouping, calendar: calendar))
            .accessibilityValue(metric.formatted(bucket.aggregate))
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 12)) { mark in
                AxisValueLabel {
                    if let date = mark.as(Date.self) {
                        Text(verbatim: AnalysisTexts.bucketShort(date, grouping: grouping, calendar: calendar, multiYear: multiYear))
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
        .frame(height: 220)
    }
}

// MARK: - Trends

/// Each ride's average and a moving average over five rides (TREND-01).
private struct PadTrendCard: View {
    let summary: AnalysisSummary
    let metric: TrendMetric
    let title: LocalizedStringResource
    let color: Color

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
        let points = RideAnalysis.trend(summary.figures, metric: metric, window: 5)
        let average = metric.value(of: summary.current).map { $0 * factor }
        let change = summary.change { metric.value(of: $0) }
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
                    Text("Avg in period").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: "\(AnalysisTexts.number(average, digits: digits)) \(unit)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                if let caption = AnalysisTexts.comparisonCaption(summary), change != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: caption).font(.caption).foregroundStyle(.secondary)
                        PadChangeLabel(change: change).font(.title3.weight(.semibold))
                    }
                }
            }
            chart(points)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }

    private func chart(_ points: [TrendPoint]) -> some View {
        let start = summary.chartInterval?.start ?? .now
        let end = summary.chartInterval.map { min($0.end, max(.now, points.last?.date ?? .now)) } ?? .now
        let values = points.map { $0.value * factor }
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max(1, (hi - lo) * 0.15)
        return Chart {
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
        .chartXScale(domain: start...max(start, end))
        .chartYScale(domain: (lo - pad).rounded(.down)...(hi + pad).rounded(.up))
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
    }
}

// MARK: - Texts

/// The texts of the analysis on the iPad, the same words as on the Mac (rule 8: not in the Kit).
enum AnalysisTexts {
    static func heading(_ summary: AnalysisSummary) -> String {
        guard let interval = summary.interval else { return String(localized: "All Rides") }
        let range = interval.start..<interval.end.addingTimeInterval(-1)
        switch summary.kind {
        case .week:
            let week = summary.calendar.component(.weekOfYear, from: interval.start)
            return String(localized: "Week \(week) · \(range.formatted(.interval.day().month(.abbreviated)))")
        case .month: return interval.start.formatted(.dateTime.month(.wide).year())
        case .year: return interval.start.formatted(.dateTime.year())
        case .custom, .all: return range.formatted(.interval.day().month(.abbreviated).year())
        }
    }

    static func subheading(_ summary: AnalysisSummary) -> String {
        let count = summary.current.rideCount
        if let previousInterval = summary.previousInterval {
            let name = previousName(kind: summary.kind, interval: previousInterval, calendar: summary.calendar)
            return String(localized: "\(count) rides · compared with \(name)")
        }
        return String(localized: "\(count) rides")
    }

    /// "vs September" under each figure.
    static func comparisonCaption(_ summary: AnalysisSummary) -> String? {
        summary.previousInterval.map {
            String(localized: "vs \(previousName(kind: summary.kind, interval: $0, calendar: summary.calendar))")
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

extension BarMetric {
    var label: LocalizedStringKey {
        switch self {
        case .distance: "Distance"
        case .time: "Ride time"
        case .ascent: "Ascent"
        }
    }

    func formatted(_ aggregate: RideAggregate) -> String {
        switch self {
        case .distance: RideFormat.distance(aggregate.distance)
        case .time: AnalysisTexts.hoursMinutes(aggregate.timerTime)
        case .ascent: "\(aggregate.ascent.formatted(.number.precision(.fractionLength(0)))) m"
        }
    }
}

extension Color {
    /// The colours of the Mac's charts, so a metric looks the same on both (B-295).
    static let metricSpeed = Color.map(MapPalette.Pair(light: 0x0A6ED1, dark: 0x4DA3FF))
    static let metricCadence = Color.map(MapPalette.Pair(light: 0x7A4FC9, dark: 0xA98BEF))
    static let metricPower = Color.map(MapPalette.Pair(light: 0xC2410C, dark: 0xFF8A4C))
}
