import Charts
import SwiftData
import SwiftUI
import WattspurKit

enum HighlightsTab: String, CaseIterable, Identifiable {
    case year, records, goals

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .year: "Year"
        case .records: "Records"
        case .goals: "Goals"
        }
    }
}

/// The "Highlights" section (v1.3): year in review, records and goals
/// (ADV-J1, ADV-R1, ADV-Z1). Each tab can be exported as PDF at the top left.
struct HighlightsView: View {
    @Binding var tab: HighlightsTab
    /// `nil` = the current year.
    @Binding var year: Int?
    /// Selects these rides in the list.
    var onOpenRides: ([UUID]) -> Void = { _ in }

    /// Rides outside the trash and merged rides instead of their parts; the sample
    /// ride is left out in `rides`.
    @Query(filter: Ride.listedPredicate, sort: \Ride.startDate)
    private var listedRides: [Ride]
    @Query private var goals: [Goal]
    /// The bike filter of the highlights: year and records follow it, goals never (B-137).
    @AppStorage("bikeFilter.highlights") private var bikeFilterChoice: BikeFilter = .all
    /// The source filter of the highlights, the same way (B-145).
    @AppStorage("sourceFilter.highlights") private var sourceFilterChoice: SourceFilter = .all
    @Query private var bikes: [Bike]
    @Environment(\.modelContext) private var modelContext
    @State private var exporting = false
    @State private var goalEditor: GoalEditor.Target?

    /// Only rides that count (Requirements 10.10), of every bike.
    private var allRides: [Ride] { listedRides.filter(\.countsInStatistics) }
    private var bikeFilter: BikeFilter { bikeFilterChoice.resolved(knownBikeIDs: Set(bikes.map(\.id))) }
    private var hasGPXRides: Bool { allRides.contains { $0.source == .gpx } }
    private var sourceFilter: SourceFilter { sourceFilterChoice.resolved(hasGPXRides: hasGPXRides) }
    /// The rides of the chosen bike and source: for the year and the records.
    private var rides: [Ride] {
        bikeFilter.isActive || sourceFilter.isActive
            ? allRides.filter { $0.isOnBike(bikeFilter) && $0.isFromSource(sourceFilter) } : allRides
    }
    /// The rides of every bike as plain values, for the goals.
    private var allRideData: HighlightsData { HighlightsData(rides: allRides, calendar: calendar) }
    private var calendar: Calendar { GoalPeriod.calendar() }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var shownYear: Int { year ?? currentYear }

    var body: some View {
        let data = HighlightsData(rides: rides, calendar: calendar)
        VStack(spacing: 0) {
            controls(data)
                .padding(.horizontal, 28)
                .frame(height: 52)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PDFExportButton(isExporting: exporting, isDisabled: rides.isEmpty && tab != .goals) { target in
                        exportPDF(data, to: target)
                    }
                    content(data)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(item: $goalEditor) { target in
            GoalEditor(target: target, goals: goals)
        }
    }

    private func controls(_ data: HighlightsData) -> some View {
        HStack(spacing: 12) {
            Picker("Highlights", selection: $tab) {
                ForEach(HighlightsTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if tab == .year {
                let years = data.years(including: currentYear)
                HStack(spacing: 4) {
                    Button { year = years.first { $0 < shownYear } } label: { Image(systemName: "chevron.left") }
                        .disabled(!years.contains { $0 < shownYear })
                        .help(Text("Previous year"))
                        .accessibilityLabel(Text("Previous year"))
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button {
                        let next = years.last { $0 > shownYear }
                        year = next == currentYear ? nil : next
                    } label: { Image(systemName: "chevron.right") }
                        .disabled(!years.contains { $0 > shownYear })
                        .help(Text("Next year"))
                        .accessibilityLabel(Text("Next year"))
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            if tab == .goals {
                // Goals count every bike and every source, so the filters have no say here.
                if bikes.count >= 2 || hasGPXRides {
                    Label { Text(goalsNote) } icon: { Image(systemName: "lock") }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                BikeFilterMenu(filter: $bikeFilterChoice)
                SourceFilterMenu(filter: $sourceFilterChoice, hasGPXRides: hasGPXRides)
            }
            Spacer()
        }
    }

    /// What the lock beside the goals says: which filters do not apply to them.
    private var goalsNote: LocalizedStringKey {
        if bikes.count < 2 { "Goals count all sources" } else if hasGPXRides { "Goals count all bikes and sources" } else { "Goals count all bikes" }
    }

    @ViewBuilder
    private func content(_ data: HighlightsData) -> some View {
        switch tab {
        case .year:
            if rides.isEmpty {
                noRides
            } else {
                YearReviewContent(review: YearReview(data.highlightRides, year: shownYear, calendar: calendar),
                                  isCurrentYear: shownYear == currentYear, calendar: calendar,
                                  rideNames: data.names, onOpenRides: onOpenRides)
            }
        case .records:
            if rides.isEmpty {
                noRides
            } else {
                RecordsContent(records: data.records, rides: data.byID, onOpenRides: onOpenRides)
            }
        case .goals:
            GoalsContent(goals: Goal.sorted(goals), rides: allRideData.highlightRides, calendar: calendar,
                         onAdd: Goal.freeCombinations(besides: goals).isEmpty ? nil : { goalEditor = .new },
                         onEdit: { goalEditor = .edit($0) })
        }
    }

    @ViewBuilder
    private var noRides: some View {
        if bikeFilter.isActive && sourceFilter.isActive && !allRides.isEmpty {
            ContentUnavailableView("No Matching Rides", systemImage: "trophy",
                                   description: Text("Change or reset the filters."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else if sourceFilter.isActive && !allRides.isEmpty {
            ContentUnavailableView("No Rides From This Source", systemImage: "trophy",
                                   description: Text("Choose another source or all sources."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else if bikeFilter.isActive && !allRides.isEmpty {
            ContentUnavailableView("No Rides on This Bike", systemImage: "trophy",
                                   description: Text("Choose another bike or all bikes."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            ContentUnavailableView("No Rides Yet", systemImage: "trophy",
                                   description: Text("Import rides to see your year, your records and how your goals are going."))
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func exportPDF(_ data: HighlightsData, to target: PDFExport.Target) {
        exporting = true
        defer { exporting = false }
        let page: AnyView
        let title: String
        switch tab {
        case .year:
            let review = YearReview(data.highlightRides, year: shownYear, calendar: calendar)
            title = String(localized: "Wattspur \(String(shownYear))")
            page = AnyView(VStack(alignment: .leading, spacing: 22) {
                YearReviewContent(review: review, isCurrentYear: shownYear == currentYear, calendar: calendar,
                                  rideNames: data.names, isPrinting: true)
                PDFExport.createdNote
            })
        case .records:
            title = String(localized: "Wattspur Records")
            page = AnyView(VStack(alignment: .leading, spacing: 22) {
                RecordsContent(records: data.records, rides: data.byID, isPrinting: true)
                PDFExport.createdNote
            })
        case .goals:
            title = String(localized: "Wattspur Goals")
            page = AnyView(VStack(alignment: .leading, spacing: 22) {
                GoalsContent(goals: Goal.sorted(goals), rides: allRideData.highlightRides, calendar: calendar, isPrinting: true)
                PDFExport.createdNote
            })
        }
        PDFExport.deliver(PDFExport.document([page]), fileName: PDFExport.fileName(title), to: target)
    }
}

/// The rides as plain values, computed once per redraw.
@MainActor
struct HighlightsData {
    let highlightRides: [HighlightRide]
    let byID: [UUID: Ride]
    let records: [RideRecord]
    let calendar: Calendar

    init(rides: [Ride], calendar: Calendar) {
        highlightRides = rides.map(\.highlightRide)
        byID = Dictionary(rides.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        records = RideRecords.records(highlightRides, calendar: calendar)
        self.calendar = calendar
    }

    var names: [UUID: String] { byID.mapValues(\.name) }

    /// Years with rides plus the current one, newest first.
    func years(including current: Int) -> [Int] {
        Array(Set(YearReview.years(of: highlightRides, calendar: calendar) + [current])).sorted(by: >)
    }
}

// MARK: - Formatting

enum HighlightsFormat {
    static func title(_ kind: RecordKind) -> String {
        switch kind {
        case .longestDistance: String(localized: "Longest ride")
        case .longestDuration: String(localized: "Longest ride time")
        case .mostAscent: String(localized: "Most ascent")
        case .highestAverageSpeed: String(localized: "Highest avg speed")
        case .highestAveragePower: String(localized: "Highest avg power")
        case .longestStreak: String(localized: "Longest streak")
        }
    }

    /// Number and unit, e.g. ("101.6", "km") or ("5:36", "h").
    static func value(_ kind: RecordKind, _ value: Double) -> (number: String, unit: String) {
        switch kind {
        case .longestDistance: (RideFormat.distanceValue(value), "km")
        case .longestDuration:
            (Duration.seconds(value.rounded()).formatted(.time(pattern: .hourMinute)), "h")
        case .mostAscent: (Int(value.rounded()).formatted(), "m")
        case .highestAverageSpeed: (RideFormat.speedValue(value), "km/h")
        case .highestAveragePower: (Int(value.rounded()).formatted(), "W")
        case .longestStreak: (Int(value).formatted(), String(localized: "days", comment: "Unit after the number of days of a streak"))
        }
    }

    /// "101.6 km", "5 days".
    static func text(_ kind: RecordKind, _ value: Double) -> String {
        if kind == .longestStreak { return String(localized: "\(Int(value)) days") }
        let v = Self.value(kind, value)
        return "\(v.number) \(v.unit)"
    }

    static func title(_ metric: GoalMetric) -> String {
        switch metric {
        case .distance: String(localized: "Kilometres")
        case .rides: String(localized: "Rides")
        case .ascent: String(localized: "Ascent")
        }
    }

    static func title(_ period: GoalPeriod) -> String {
        switch period {
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .year: String(localized: "Year")
        }
    }

    /// The value in the unit the user types: km, rides or m.
    static func display(_ metric: GoalMetric, _ value: Double) -> Double {
        metric == .distance ? value / 1000 : value
    }

    static func unit(_ metric: GoalMetric) -> String {
        switch metric {
        case .distance: "km"
        case .rides: ""
        case .ascent: "m"
        }
    }

    /// "62", "1,284" – kilometres without decimals from 100 km on.
    static func number(_ metric: GoalMetric, _ value: Double) -> String {
        let shown = display(metric, value)
        if metric == .distance && shown < 100 && shown.rounded() != shown {
            return shown.formatted(.number.precision(.fractionLength(1)))
        }
        return Int(shown.rounded()).formatted()
    }

    /// "This week", "October", "2026".
    static func currentPeriod(_ period: GoalPeriod, _ interval: DateInterval, calendar: Calendar) -> String {
        switch period {
        case .week: String(localized: "This week")
        case .month: interval.start.formatted(Date.FormatStyle(timeZone: calendar.timeZone).month(.wide))
        case .year: String(calendar.component(.year, from: interval.start))
        }
    }

    static func shortDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).day().month(.abbreviated))
    }

    static func longDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).day().month(.abbreviated).year())
    }
}

// MARK: - Year

struct YearReviewContent: View {
    let review: YearReview
    let isCurrentYear: Bool
    let calendar: Calendar
    let rideNames: [UUID: String]
    var isPrinting = false
    var onOpenRides: ([UUID]) -> Void = { _ in }

    private static let everest = 8_848.0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your \(String(review.year))").font(.largeTitle.bold())
                Text(verbatim: subtitle).foregroundStyle(.secondary)
            }
            if review.aggregate.rideCount == 0 {
                ContentUnavailableView("No Rides in \(String(review.year))", systemImage: "calendar",
                                       description: Text("Choose another year with the arrows at the top."))
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                tiles
                card(title: Text("Riding days"), subtitle: Text("Each square is a day; the darker, the more kilometres")) {
                    YearHeatmap(year: review.year, days: review.days, calendar: calendar, onOpenRides: onOpenRides)
                }
                HStack(alignment: .top, spacing: 20) {
                    card(title: Text("Kilometres per month")) { monthChart }
                        .frame(maxWidth: .infinity)
                    card(title: Text("Records this year")) { yearRecords }
                        .frame(width: 360)
                }
            }
        }
    }

    private var subtitle: String {
        // Two plurals, so two strings: "8 rides on 8 days".
        let counts = "\(String(localized: "\(review.aggregate.rideCount) rides")) \(String(localized: "on \(review.ridingDayCount) days"))"
        guard isCurrentYear else { return counts }
        let today = Date.now.formatted(Date.FormatStyle(timeZone: calendar.timeZone).day().month(.wide))
        return String(localized: "As of \(today) · \(counts)")
    }

    private var tiles: some View {
        let a = review.aggregate
        let hours = a.timerTime / 3600
        let perRide = a.timerTimePerRide.map { Duration.seconds($0.rounded()).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)) } ?? "–"
        let change = review.distanceChange.map { change in
            let percent = change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))
            return String(localized: "\(change >= 0 ? "▲" : "▼") \(percent) vs \(String(review.year - 1))")
        }
        return HStack(alignment: .top, spacing: 16) {
            YearTile(label: "Distance", value: Int((a.distance / 1000).rounded()).formatted(), unit: "km",
                     note: change ?? String(localized: "no rides the year before"))
            YearTile(label: "Rides", value: a.rideCount.formatted(), unit: "",
                     note: String(localized: "on \(review.ridingDayCount) days"))
            YearTile(label: "Ride time", value: Int(hours.rounded()).formatted(), unit: "h",
                     note: String(localized: "avg \(perRide) per ride"))
            YearTile(label: "Ascent", value: a.ascentIfKnown.map { Int($0.rounded()).formatted() } ?? "–", unit: "m",
                     note: a.ascentCoverage.isNone ? String(localized: "no elevation in the files")
                         : String(localized: "≈ \((a.ascent / Self.everest).formatted(.number.precision(.fractionLength(1)))) × Mount Everest"),
                     coverage: a.ascentCoverage)
            YearTile(label: "CO₂ saved", value: Int(a.co2SavedKilograms.rounded()).formatted(), unit: "kg",
                     note: String(localized: "estimate"))
        }
    }

    private var months: [(label: String, km: Double)] {
        let symbols = calendar.shortMonthSymbols
        return review.months.enumerated().map { (symbols[$0.offset], $0.element.distance / 1000) }
    }

    private var monthChart: some View {
        let best = review.bestMonth
        let data = months
        return Chart(Array(data.enumerated()), id: \.offset) { index, month in
            BarMark(x: .value("Month", month.label), y: .value("Kilometres", month.km))
                .foregroundStyle(index == best ? Color.accentColor : Color.accentColor.opacity(0.45))
                .cornerRadius(4)
                .annotation(position: .top, spacing: 2) {
                    if month.km > 0 {
                        Text(verbatim: Int(month.km.rounded()).formatted())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .chartXScale(domain: data.map(\.label))
        .chartYAxis(.hidden)
        .frame(height: 190)
        .accessibilityChartDescriptor(BarChartDescriptor(
            title: String(localized: "Kilometres per month"), unit: "km",
            bars: data.map { ($0.label, $0.km, "\(Int($0.km.rounded()).formatted()) km") }))
    }

    private var yearRecords: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(review.records) { record in
                HStack(spacing: 10) {
                    Image(systemName: "star")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(verbatim: HighlightsFormat.title(record.kind))
                    Spacer()
                    Text(verbatim: HighlightsFormat.text(record.kind, record.value))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text(verbatim: HighlightsFormat.shortDate(record.date, timeZone: calendar.timeZone))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
                .font(.callout)
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Divider() }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func card<Content: View>(title: Text, subtitle: Text? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                title.font(.title3.bold()).accessibilityAddTraits(.isHeader)
                if let subtitle { subtitle.font(.caption).foregroundStyle(.secondary) }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}

private struct YearTile: View {
    let label: LocalizedStringKey
    let value: String
    let unit: String
    let note: String
    /// "9 of 12 rides" under the note when the figure is not there for all rides (B-146).
    var coverage: ValueCoverage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value).font(.system(size: 28, weight: .semibold))
                if !unit.isEmpty { Text(verbatim: unit).foregroundStyle(.secondary) }
            }
            .monospacedDigit()
            Text(verbatim: note).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            if let coverage, coverage.isPartial { CoverageNote(coverage: coverage) }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Calendar heatmap: one square per day, a column per week from Monday to Sunday.
struct YearHeatmap: View {
    let year: Int
    let days: [RidingDay]
    let calendar: Calendar
    var onOpenRides: ([UUID]) -> Void = { _ in }

    /// Opacity of the accent colour for the levels 1 to 4; the level is also in the tooltip.
    static let shades = [0.3, 0.5, 0.75, 1.0]

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                grid(cell: 15)
                grid(cell: 14)
                grid(cell: 11)
                ScrollView(.horizontal) { grid(cell: 11) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Calendar of riding days"))
            .accessibilityValue(Text(summary))
            legend
        }
    }

    private var summary: String {
        let best = days.max { $0.distance < $1.distance }
        let count = String(localized: "\(days.count) riding days")
        guard let best else { return count }
        return "\(count). " + String(localized: "Most on \(HighlightsFormat.shortDate(best.date, timeZone: calendar.timeZone)) with \(RideFormat.distance(best.distance))")
    }

    /// The first Monday on or before 1 January, then whole weeks to 31 December.
    private var weeks: [[Date?]] {
        guard let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let next = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.dateComponents([.day], from: first, to: next).day ?? 365
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<dayCount { cells.append(calendar.date(byAdding: .day, value: offset, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private func grid(cell: CGFloat) -> some View {
        let byDay = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let weeks = weeks
        let today = calendar.startOfDay(for: .now)
        let weekdays = calendar.shortStandaloneWeekdaySymbols
        return HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: " ").font(.system(size: 10)).frame(height: cell)
                ForEach(0..<7, id: \.self) { row in
                    // Label every other row: Monday, Wednesday, Friday, Sunday.
                    Text(verbatim: row.isMultiple(of: 2) ? weekdays[(row + calendar.firstWeekday - 1) % 7] : "")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(height: cell)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(weeks.indices, id: \.self) { column in
                        let label = monthLabel(weeks[column])
                        Text(verbatim: label ?? "")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .frame(width: cell, height: cell, alignment: .leading)
                    }
                }
                HStack(spacing: 3) {
                    ForEach(weeks.indices, id: \.self) { column in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                square(weeks[column][row], byDay: byDay, today: today, size: cell)
                            }
                        }
                    }
                }
            }
        }
    }

    /// The month's short name in the column that holds its first day.
    private func monthLabel(_ week: [Date?]) -> String? {
        guard let first = week.compactMap({ $0 }).first(where: { calendar.component(.day, from: $0) == 1 }) else { return nil }
        return calendar.shortMonthSymbols[calendar.component(.month, from: first) - 1]
    }

    @ViewBuilder
    private func square(_ date: Date?, byDay: [Date: RidingDay], today: Date, size: CGFloat) -> some View {
        if let date {
            let day = byDay[date]
            let shape = RoundedRectangle(cornerRadius: 3)
            let fill: Color = if let day { Color.accentColor.opacity(Self.shades[day.level - 1]) } else { Color.secondary.opacity(0.14) }
            Group {
                if date > today {
                    shape.strokeBorder(.separator)
                } else {
                    shape.fill(fill)
                }
            }
            .frame(width: size, height: size)
            .help(Text(verbatim: tooltip(date, day)))
            .onTapGesture { if let day { onOpenRides(day.rideIDs) } }
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func tooltip(_ date: Date, _ day: RidingDay?) -> String {
        let label = HighlightsFormat.longDate(date, timeZone: calendar.timeZone)
        guard let day else { return label }
        return "\(label) · \(RideFormat.distance(day.distance)) · \(String(localized: "\(day.rideIDs.count) rides"))"
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("less")
            RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.14)).frame(width: 12, height: 12)
                .help(Text(verbatim: "0 km"))
            ForEach(Self.shades.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(Self.shades[i]))
                    .frame(width: 12, height: 12)
                    .help(Text(verbatim: legendRange(i + 1)))
            }
            Text("more")
            Text("Click a day to open its rides").padding(.leading, 12)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func legendRange(_ level: Int) -> String {
        let t = HeatLevel.thresholds.map { Int($0) }
        switch level {
        case 1: return "< \(t[0]) km"
        case 2: return "\(t[0])–\(t[1]) km"
        case 3: return "\(t[1])–\(t[2]) km"
        default: return "≥ \(t[2]) km"
        }
    }
}

// MARK: - Records

struct RecordsContent: View {
    let records: [RideRecord]
    let rides: [UUID: Ride]
    var isPrinting = false
    var onOpenRides: ([UUID]) -> Void = { _ in }

    /// A record set by a ride imported in the last week is marked "New".
    private static let newForDays = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Records").font(.largeTitle.bold())
                Text("Your best values across all rides · the sample ride does not count")
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .top), count: 3),
                      alignment: .leading, spacing: 20) {
                ForEach(records) { record in
                    if isPrinting {
                        card(record)
                    } else {
                        Button { onOpenRides(record.rideIDs) } label: { card(record) }
                            .buttonStyle(.plain)
                            .help(Text(record.kind == .longestStreak ? "Show the rides of this streak" : "Open this ride"))
                    }
                }
            }
            Text("Records come from the Bosch totals of each ride. Average speed and power count from 5 km on. The streak counts consecutive days with at least one ride, by the local time of the start. Merged rides count as one ride.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private func isNew(_ record: RideRecord) -> Bool {
        let since = Date.now.addingTimeInterval(-Self.newForDays * 86_400)
        return record.rideIDs.contains { (rides[$0]?.importedAt ?? .distantPast) > since }
    }

    private func card(_ record: RideRecord) -> some View {
        let value = HighlightsFormat.value(record.kind, record.value)
        let holder = record.rideIDs.first.flatMap { rides[$0] }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "star").foregroundStyle(Color.accentColor).accessibilityHidden(true)
                Text(verbatim: HighlightsFormat.title(record.kind)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if isNew(record) { NewBadge() }
            }
            .font(.subheadline)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value.number).font(.system(size: 30, weight: .semibold))
                Text(verbatim: value.unit).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            if let streak = record.streak {
                Text(verbatim: streakRange(streak, holder: holder)).font(.callout)
                Text(verbatim: streakDetail(record)).font(.caption).foregroundStyle(.secondary)
            } else if let holder {
                Text(verbatim: holder.name).font(.callout).lineLimit(1)
                Text(verbatim: "\(HighlightsFormat.longDate(holder.startDate, timeZone: holder.timeZone)) · \(detail(record.kind, holder))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    /// The other main value of the ride: time for distance records, distance otherwise.
    private func detail(_ kind: RecordKind, _ ride: Ride) -> String {
        switch kind {
        case .longestDistance: HighlightsFormat.text(.longestDuration, ride.timerTime)
        default: RideFormat.distance(ride.distance)
        }
    }

    private func streakRange(_ streak: DayStreak, holder: Ride?) -> String {
        let zone = holder?.timeZone ?? .current
        return "\(HighlightsFormat.longDate(streak.firstDay, timeZone: zone)) – \(HighlightsFormat.longDate(streak.lastDay, timeZone: zone))"
    }

    private func streakDetail(_ record: RideRecord) -> String {
        let distance = record.rideIDs.compactMap { rides[$0]?.distance }.reduce(0, +)
        return "\(String(localized: "\(record.rideIDs.count) rides")) · \(RideFormat.distance(distance))"
    }
}

private struct NewBadge: View {
    var body: some View {
        Text("New")
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.accentColor))
    }
}

// MARK: - Goals

struct GoalsContent: View {
    let goals: [Goal]
    let rides: [HighlightRide]
    let calendar: Calendar
    var isPrinting = false
    /// `nil` when every combination already has a goal.
    var onAdd: (() -> Void)?
    var onEdit: (Goal) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goals").font(.largeTitle.bold())
                    Text("For a week, month or year · kilometres, rides or ascent").foregroundStyle(.secondary)
                }
                Spacer()
                if !isPrinting {
                    Button("Add Goal…", systemImage: "plus") { onAdd?() }
                        .buttonStyle(.glass)
                        .disabled(onAdd == nil)
                        .help(onAdd == nil ? Text("Every period already has a goal for each metric.") : Text("Add Goal…"))
                }
            }
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("No Goals Yet", systemImage: "target")
                } description: {
                    Text("Set a goal for kilometres, rides or ascent per week, month or year.")
                } actions: {
                    if !isPrinting { Button("Add Goal…") { onAdd?() } }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .top), count: 3),
                          alignment: .leading, spacing: 20) {
                    ForEach(goals) { goal in
                        GoalCard(progress: GoalProgress(metric: goal.metric, period: goal.period, target: goal.target,
                                                        rides: rides, calendar: calendar),
                                 calendar: calendar, isPrinting: isPrinting) { onEdit(goal) }
                    }
                }
            }
            Text("Goals are optional and stay in your library. The small bars show the last periods; a full bar means reached. The sample ride does not count.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

private struct GoalCard: View {
    let progress: GoalProgress
    let calendar: Calendar
    var isPrinting = false
    let onEdit: () -> Void

    private var metric: GoalMetric { progress.metric }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: HighlightsFormat.currentPeriod(progress.period, progress.current.interval, calendar: calendar))
                    .fontWeight(.semibold)
                Text(verbatim: HighlightsFormat.title(metric)).foregroundStyle(.secondary)
                Spacer()
                if !isPrinting {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                        .help(Text("Edit Goal…"))
                        .accessibilityLabel(Text("Edit Goal…"))
                }
            }
            .font(.callout)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: HighlightsFormat.number(metric, progress.current.value))
                    .font(.system(size: 30, weight: .semibold))
                Text(verbatim: ofTarget).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            ProgressView(value: min(1, progress.current.fraction))
                .tint(Color.accentColor)
                .accessibilityLabel(Text(verbatim: "\(HighlightsFormat.title(progress.period)), \(HighlightsFormat.title(metric))"))
                .accessibilityValue(Text(verbatim: "\(HighlightsFormat.number(metric, progress.current.value)) \(ofTarget)"))
            HStack(spacing: 6) {
                if progress.current.isReached {
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
                Text(verbatim: note).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            // Rides without elevation add nothing to an ascent goal (B-146).
            if metric == .ascent { CoverageNote(coverage: progress.ascentCoverage) }
            history
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ofTarget: String {
        let unit = HighlightsFormat.unit(metric)
        let target = HighlightsFormat.number(metric, progress.current.target)
        return String(localized: "of \(unit.isEmpty ? target : "\(target) \(unit)")")
    }

    private var note: String {
        if let reached = progress.reachedAt {
            return String(localized: "Reached on \(HighlightsFormat.shortDate(reached, timeZone: calendar.timeZone))")
        }
        let remaining = "\(HighlightsFormat.number(metric, progress.remaining)) \(HighlightsFormat.unit(metric))"
            .trimmingCharacters(in: .whitespaces)
        let left = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: progress.current.interval.end).day ?? 0
        let track = progress.isOnTrack ? String(localized: "on track") : String(localized: "behind")
        return String(localized: "\(remaining) to go · \(left) days left · \(track)")
    }

    private var history: some View {
        let results = progress.history
        let reached = results.filter(\.isReached).count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(results) { result in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(result.isReached ? Color.accentColor : Color.accentColor.opacity(0.4))
                        .frame(height: max(3, min(1, result.fraction) * 28))
                        .frame(maxWidth: .infinity)
                        .help(Text(verbatim: result.fraction.formatted(.percent.precision(.fractionLength(0)))))
                }
            }
            .frame(height: 28, alignment: .bottom)
            .padding(.top, 6)
            .overlay(alignment: .top) { Divider() }
            Text("Last \(results.count) periods · \(reached) reached")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Last \(results.count) periods · \(reached) reached"))
    }
}

/// Add or change a goal. Each period and metric exists at most once (Requirements 10.10).
struct GoalEditor: View {
    enum Target: Identifiable {
        case new
        case edit(Goal)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let goal): goal.id.uuidString
            }
        }
    }

    let target: Target
    let goals: [Goal]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var period: GoalPeriod = .week
    @State private var metric: GoalMetric = .distance
    @State private var value: Double = 100

    private var editing: Goal? {
        if case .edit(let goal) = target { goal } else { nil }
    }

    /// Combinations still free, plus the one being edited.
    private func isFree(_ period: GoalPeriod, _ metric: GoalMetric) -> Bool {
        if let editing, editing.period == period, editing.metric == metric { return true }
        return Goal.freeCombinations(besides: goals).contains { $0.period == period && $0.metric == metric }
    }

    var body: some View {
        Form {
            Picker("Period", selection: $period) {
                ForEach(GoalPeriod.allCases) { Text(verbatim: HighlightsFormat.title($0)).tag($0) }
            }
            Picker("Metric", selection: $metric) {
                ForEach(GoalMetric.allCases) { m in
                    Text(verbatim: HighlightsFormat.title(m)).tag(m).selectionDisabled(!isFree(period, m))
                }
            }
            LabeledContent("Goal") {
                HStack {
                    TextField("Goal", value: $value, format: .number.precision(.fractionLength(0...1)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(verbatim: HighlightsFormat.unit(metric).isEmpty ? HighlightsFormat.title(metric) : HighlightsFormat.unit(metric))
                        .foregroundStyle(.secondary)
                }
            }
            if !isFree(period, metric) {
                Text("There is already a goal for this period and metric.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .navigationTitle(editing == nil ? Text("Add Goal") : Text("Edit Goal"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(value <= 0 || !isFree(period, metric))
            }
            if let editing {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Goal", role: .destructive) {
                        modelContext.delete(editing)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let editing {
                period = editing.period
                metric = editing.metric
                value = HighlightsFormat.display(editing.metric, editing.target)
            } else if let free = Goal.freeCombinations(besides: goals).first {
                period = free.period
                metric = free.metric
                value = Self.suggestion(free.period, free.metric)
            }
        }
        .onChange(of: metric) { if editing == nil { value = Self.suggestion(period, metric) } }
        .onChange(of: period) {
            if !isFree(period, metric), let free = GoalMetric.allCases.first(where: { isFree(period, $0) }) { metric = free }
            if editing == nil { value = Self.suggestion(period, metric) }
        }
    }

    /// A starting value in km, rides or m, so the field is never empty.
    private static func suggestion(_ period: GoalPeriod, _ metric: GoalMetric) -> Double {
        switch (period, metric) {
        case (.week, .distance): 100
        case (.week, .rides): 3
        case (.week, .ascent): 1_000
        case (.month, .distance): 400
        case (.month, .rides): 12
        case (.month, .ascent): 4_000
        case (.year, .distance): 4_000
        case (.year, .rides): 120
        case (.year, .ascent): 40_000
        }
    }

    private func save() {
        let target = metric == .distance ? value * 1000 : value.rounded()
        if let editing {
            editing.period = period
            editing.metric = metric
            editing.target = target
        } else {
            modelContext.insert(Goal(metric: metric, period: period, target: target))
        }
        try? modelContext.save()
        dismiss()
    }
}
