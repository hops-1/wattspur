import Charts
import SwiftUI
import WattspurCore
import WattspurKit

/// "Highlights" on the iPad (B-295) and the iPhone (B-228), like the Mac's section (v1.3): the
/// year in review, records and goals. On the iPhone the same parts stack in one column and the
/// page is pushed from the tile in the overview. Year and records are of the sport in the sidebar and follow the device filter; the
/// goals count every bike (as on the Mac). The numbers come from the Kit (`HighlightsSummary`,
/// `YearReview`, `GoalProgress`); only the texts and the layout are here.
struct HighlightsView: View {
    /// Opens a ride beside the list of rides (iPad); `nil` pushes it onto this page (iPhone).
    var onOpenRide: ((UUID) -> Void)?

    @Environment(PhoneLibrary.self) private var library
    @ShownSport private var sport
    @AppStorage(PhoneSettingsKey.padHighlightsTab) private var tab: PadHighlightsTab = .year
    @AppStorage(PhoneSettingsKey.padHighlightsDevice) private var deviceFilter: BikeFilter = .all
    /// `nil` = the current year.
    @State private var year: Int?
    @State private var goalEditor: PadGoalEditor.Target?
    /// The ride pushed on the iPhone.
    @State private var openedID: UUID?
    @Environment(\.isPadLayout) private var isPadLayout

    private var calendar: Calendar { GoalPeriod.calendar() }
    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var shownYear: Int { year ?? currentYear }
    private var devices: [RideExchange.Bike] { library.state?.devices(of: sport) ?? [] }

    var body: some View {
        let all = library.statsRides.filter(\.countsInStatistics)
        let filter = deviceFilter.resolved(knownBikeIDs: Set(devices.map(\.id)))
        let rides = all.filter { $0.sport == sport && filter.admits(bikeID: $0.deviceID) }
        let summary = HighlightsSummary(rides: rides.map(\.highlight), calendar: calendar)
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let open: (UUID) -> Void = onOpenRide ?? { openedID = $0 }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                controls(summary)
                switch tab {
                case .year:
                    if rides.isEmpty {
                        noRides(anyForSport: all.contains { $0.sport == sport })
                    } else {
                        PadYearReview(review: YearReview(summary.rides, year: shownYear, calendar: calendar),
                                      isCurrentYear: shownYear == currentYear, calendar: calendar,
                                      rides: byID, sport: sport, compact: !isPadLayout, onOpenRide: open)
                    }
                case .records:
                    if rides.isEmpty {
                        noRides(anyForSport: all.contains { $0.sport == sport })
                    } else {
                        PadRecords(records: summary.records, rides: byID, sport: sport, compact: !isPadLayout, onOpenRide: open)
                    }
                case .goals:
                    // The goals are for cycling, whatever sport the sidebar shows (as on the Mac).
                    PadGoals(goals: library.goals,
                             rides: all.filter { $0.sport == .cycling }.map(\.highlight), calendar: calendar,
                             compact: !isPadLayout,
                             onAdd: library.freeGoalCombinations.isEmpty ? nil : { goalEditor = .new },
                             onEdit: { goalEditor = .edit($0) })
                }
            }
            .padding(.horizontal, isPadLayout ? 28 : 16)
            .padding(.vertical, isPadLayout ? 16 : 8)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The iPhone's landscape tab bar floats over the bottom left.
        .tabBarRoomInLandscape()
        .navigationTitle("Highlights")
        .navigationBarTitleDisplayMode(.inline)
        // The iPad's detail has its own title in the page; the iPhone needs the bar to go back.
        .toolbar(isPadLayout ? .hidden : .automatic, for: .navigationBar)
        .navigationDestination(item: $openedID) { id in
            if let ride = library.state?.rides.first(where: { $0.id == id }) {
                TourDetailView(ride: ride)
            }
        }
        .sheet(item: $goalEditor) { target in
            NavigationStack { PadGoalEditor(target: target) }
        }
        .onChange(of: sport) {
            deviceFilter = .all
            year = nil
        }
    }

    private func controls(_ summary: HighlightsSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { controlItems(summary) }
            VStack(alignment: .leading, spacing: 12) { controlItems(summary) }
        }
    }

    @ViewBuilder private func controlItems(_ summary: HighlightsSummary) -> some View {
        Picker("Highlights", selection: $tab) {
            ForEach(PadHighlightsTab.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        if tab == .year {
            let years = summary.years(including: currentYear)
            HStack(spacing: 6) {
                Button { year = years.first { $0 < shownYear } } label: { Image(systemName: "chevron.left") }
                    .disabled(!years.contains { $0 < shownYear })
                    .accessibilityLabel(Text("Previous year"))
                Button {
                    let next = years.last { $0 > shownYear }
                    year = next == currentYear ? nil : next
                } label: { Image(systemName: "chevron.right") }
                    .disabled(!years.contains { $0 > shownYear })
                    .accessibilityLabel(Text("Next year"))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        if tab == .goals {
            if devices.count >= 2 {
                Label { Text("Goals count all bikes") } icon: { Image(systemName: "lock") }
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if devices.count >= 2 {
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

    @ViewBuilder private func noRides(anyForSport: Bool) -> some View {
        if anyForSport {
            ContentUnavailableView("No Rides with This Vehicle", systemImage: "trophy",
                                   description: Text("Choose another vehicle or all vehicles."))
                .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            ContentUnavailableView("No Rides Yet", systemImage: "trophy",
                                   description: Text("Import rides to see your year, your records and how your goals are going."))
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }
}

enum PadHighlightsTab: String, CaseIterable, Identifiable {
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

// MARK: - Year

private struct PadYearReview: View {
    let review: YearReview
    let isCurrentYear: Bool
    let calendar: Calendar
    let rides: [UUID: PhoneDatabase.StatsRide]
    let sport: Sport
    /// One column on the iPhone (B-228).
    var compact = false
    let onOpenRide: (UUID) -> Void

    private static let everest = 8_848.0

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 24) {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text("Your \(String(review.year))").font(compact ? .title2.bold() : .largeTitle.bold())
                Text(verbatim: subtitle).font(compact ? .subheadline : .body).foregroundStyle(.secondary)
            }
            if review.aggregate.rideCount == 0 {
                ContentUnavailableView("No Rides in \(String(review.year))", systemImage: "calendar",
                                       description: Text("Choose another year with the arrows at the top."))
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                tiles
                card(title: Text("Riding days"), subtitle: Text("Each square is a day; the darker, the more kilometres")) {
                    PadYearHeatmap(year: review.year, days: review.days, calendar: calendar, compact: compact) { ids in
                        if let first = ids.first { onOpenRide(first) }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        card(title: Text("Kilometres per month")) { monthChart }
                            .frame(minWidth: 420, maxWidth: .infinity)
                        card(title: Text("Records this year")) { yearRecords }
                            .frame(width: 440)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        card(title: Text("Kilometres per month")) { monthChart }
                        card(title: Text("Records this year")) { yearRecords }
                    }
                }
            }
        }
    }

    private var subtitle: String {
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
        // On the iPhone three small tiles a row, so the riding days fit on the first screen (Nils).
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 100 : 170), spacing: compact ? 8 : 16, alignment: .top)],
                         spacing: compact ? 8 : 16) {
            YearTile(compact: compact, label: "Distance", value: Int((a.distance / 1000).rounded()).formatted(), unit: "km",
                     note: change ?? String(localized: "no rides the year before"))
            YearTile(compact: compact, label: "Rides", value: a.rideCount.formatted(), unit: "",
                     note: String(localized: "on \(review.ridingDayCount) days"))
            YearTile(compact: compact, label: "Ride time", value: Int(hours.rounded()).formatted(), unit: "h",
                     note: String(localized: "avg \(perRide) per ride"))
            YearTile(compact: compact, label: "Ascent", value: a.ascentIfKnown.map { Int($0.rounded()).formatted() } ?? "–", unit: "m",
                     note: a.ascentCoverage.isNone ? String(localized: "no elevation in the files")
                         : String(localized: "≈ \((a.ascent / Self.everest).formatted(.number.precision(.fractionLength(1)))) × Mount Everest"))
            if sport == .cycling {
                YearTile(compact: compact, label: "CO₂ saved", value: Int(a.co2SavedKilograms.rounded()).formatted(), unit: "kg",
                         note: String(localized: "estimate"))
            }
        }
    }

    private var monthChart: some View {
        let best = review.bestMonth
        let symbols = calendar.shortMonthSymbols
        let data = review.months.enumerated().map { (label: symbols[$0.offset], km: $0.element.distance / 1000) }
        return Chart(Array(data.enumerated()), id: \.offset) { index, month in
            BarMark(x: .value("Month", month.label), y: .value("Kilometres", month.km))
                .foregroundStyle(index == best ? Color.track : Color.track.opacity(0.45))
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
    }

    private var yearRecords: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(review.records) { record in
                HStack(spacing: 10) {
                    Image(systemName: "star").foregroundStyle(Color.track).accessibilityHidden(true)
                    Text(verbatim: HighlightTexts.title(record.kind))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text(verbatim: HighlightTexts.text(record.kind, record.value))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text(verbatim: HighlightTexts.shortDate(record.date, timeZone: calendar.timeZone))
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
            VStack(alignment: .leading, spacing: 2) {
                title.font(.title3.bold()).accessibilityAddTraits(.isHeader)
                if let subtitle { subtitle.font(.caption).foregroundStyle(.secondary) }
            }
            content()
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}

private struct YearTile: View {
    var compact = false
    let label: LocalizedStringKey
    let value: String
    let unit: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(label).font(compact ? .caption : .subheadline).foregroundStyle(.secondary).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: compact ? 2 : 4) {
                Text(verbatim: value).font(.system(size: compact ? 20 : 28, weight: .semibold))
                if !unit.isEmpty { Text(verbatim: unit).font(compact ? .caption : .body).foregroundStyle(.secondary) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .monospacedDigit()
            Text(verbatim: note).font(compact ? .caption2 : .caption).foregroundStyle(.secondary).monospacedDigit()
                .lineLimit(compact ? 2 : nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, compact ? 8 : 14)
        .padding(.horizontal, compact ? 10 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: compact ? 10 : 14))
        .accessibilityElement(children: .combine)
    }
}

/// One square per day, a column per week from Monday to Sunday; a tap opens the day's ride.
private struct PadYearHeatmap: View {
    let year: Int
    let days: [RidingDay]
    let calendar: Calendar
    /// On the iPhone the year scrolls sideways, starting at its end, and the hint goes below.
    var compact = false
    let onOpenRides: ([UUID]) -> Void

    /// Opacity of the track colour for the levels 1 to 4.
    static let shades = [0.3, 0.5, 0.75, 1.0]

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Group {
                if compact {
                    ScrollView(.horizontal) { grid(cell: 14) }
                        .defaultScrollAnchor(.trailing)
                        .scrollIndicators(.hidden)
                } else {
                    ViewThatFits(in: .horizontal) {
                        grid(cell: 15)
                        grid(cell: 12)
                        grid(cell: 10)
                        ScrollView(.horizontal) { grid(cell: 12) }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Calendar of riding days"))
            .accessibilityValue(Text(String(localized: "\(days.count) riding days")))
            legend
        }
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
                    Text(verbatim: row.isMultiple(of: 2) ? weekdays[(row + calendar.firstWeekday - 1) % 7] : "")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(height: cell)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(weeks.indices, id: \.self) { column in
                        Text(verbatim: monthLabel(weeks[column]) ?? "")
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

    private func monthLabel(_ week: [Date?]) -> String? {
        guard let first = week.compactMap({ $0 }).first(where: { calendar.component(.day, from: $0) == 1 }) else { return nil }
        return calendar.shortMonthSymbols[calendar.component(.month, from: first) - 1]
    }

    @ViewBuilder
    private func square(_ date: Date?, byDay: [Date: RidingDay], today: Date, size: CGFloat) -> some View {
        if let date {
            let day = byDay[date]
            let shape = RoundedRectangle(cornerRadius: 3)
            let fill: Color = if let day { Color.track.opacity(Self.shades[day.level - 1]) } else { Color.secondary.opacity(0.14) }
            Group {
                if date > today {
                    shape.strokeBorder(.separator)
                } else {
                    shape.fill(fill)
                }
            }
            .frame(width: size, height: size)
            .onTapGesture { if let day { onOpenRides(day.rideIDs) } }
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                scale
                Text("Tap a day to open its ride").padding(.leading, 12)
            }
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) { scale }
                Text("Tap a day to open its ride")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

extension PadYearHeatmap {
    @ViewBuilder fileprivate var scale: some View {
        Text("less")
        RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.14)).frame(width: 12, height: 12)
        ForEach(Self.shades.indices, id: \.self) { i in
            RoundedRectangle(cornerRadius: 3).fill(Color.track.opacity(Self.shades[i])).frame(width: 12, height: 12)
        }
        Text("more")
    }
}

// MARK: - Records

private struct PadRecords: View {
    let records: [RideRecord]
    let rides: [UUID: PhoneDatabase.StatsRide]
    let sport: Sport
    var compact = false
    let onOpenRide: (UUID) -> Void

    /// A record set by a ride imported in the last week is marked "New".
    private static let newForDays = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Records").font(compact ? .title.bold() : .largeTitle.bold())
                Text("Your best values across all rides · the sample ride does not count")
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: compact ? 12 : 20, alignment: .top)],
                      alignment: .leading, spacing: compact ? 12 : 20) {
                ForEach(records) { record in
                    Button { if let first = record.rideIDs.first { onOpenRide(first) } } label: { card(record) }
                        .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                if sport == .cycling {
                    Text("Records come from the Bosch totals of each ride. Average speed and power count from 5 km on. The streak counts consecutive days with at least one ride, by the local time of the start. Merged rides count as one ride.")
                    Text("Top speed, highest power and highest cadence are the maximum stored in the file. The best 1-minute power is the highest average power over 60 seconds without a break; rides without power values, like many GPX files, do not count for the power records.")
                } else {
                    Text("Records of your vehicles: distance, ride time, ascent, speed and curves. Average speed counts from 5 km on. Merged rides count as one ride.")
                }
            }
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
        let value = HighlightTexts.value(record.kind, record.value)
        let holder = record.rideIDs.first.flatMap { rides[$0] }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "star").foregroundStyle(Color.track).accessibilityHidden(true)
                Text(verbatim: HighlightTexts.title(record.kind)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if isNew(record) {
                    Text("New")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.track.opacity(0.18), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.track))
                }
            }
            .font(.subheadline)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value.number).font(.system(size: 30, weight: .semibold))
                Text(verbatim: value.unit).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            if let streak = record.streak {
                let zone = holder?.highlight.timeZone ?? .current
                Text(verbatim: "\(HighlightTexts.longDate(streak.firstDay, timeZone: zone)) – \(HighlightTexts.longDate(streak.lastDay, timeZone: zone))")
                    .font(.callout)
                let distance = record.rideIDs.compactMap { rides[$0]?.figures.distance }.reduce(0, +)
                Text(verbatim: "\(String(localized: "\(record.rideIDs.count) rides")) · \(RideFormat.distance(distance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let holder {
                Text(verbatim: holder.name).font(.callout).lineLimit(1)
                Text(verbatim: "\(HighlightTexts.longDate(holder.highlight.startDate, timeZone: holder.highlight.timeZone)) · \(detail(record.kind, holder))")
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
    private func detail(_ kind: RecordKind, _ ride: PhoneDatabase.StatsRide) -> String {
        switch kind {
        case .longestDistance: HighlightTexts.text(.longestDuration, ride.figures.timerTime)
        default: RideFormat.distance(ride.figures.distance)
        }
    }
}

// MARK: - Goals

private struct PadGoals: View {
    let goals: [PhoneDatabase.GoalValue]
    let rides: [HighlightRide]
    let calendar: Calendar
    var compact = false
    /// `nil` when every combination already has a goal.
    var onAdd: (() -> Void)?
    var onEdit: (PhoneDatabase.GoalValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goals").font(compact ? .title.bold() : .largeTitle.bold())
                    Text("For a week, month or year · kilometres, rides or ascent").foregroundStyle(.secondary)
                }
                Spacer()
                Group {
                    if compact {
                        Button { onAdd?() } label: { Image(systemName: "plus") }
                            .buttonBorderShape(.circle)
                            .accessibilityLabel(Text("Add Goal…"))
                    } else {
                        Button("Add Goal…", systemImage: "plus") { onAdd?() }
                    }
                }
                .buttonStyle(.glass)
                .disabled(onAdd == nil)
            }
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("No Goals Yet", systemImage: "target")
                } description: {
                    Text("Set a goal for kilometres, rides or ascent per week, month or year.")
                } actions: {
                    Button("Add Goal…") { onAdd?() }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: compact ? 12 : 20, alignment: .top)],
                          alignment: .leading, spacing: compact ? 12 : 20) {
                    ForEach(goals) { goal in
                        PadGoalCard(progress: GoalProgress(metric: goal.metric, period: goal.period, target: goal.target,
                                                           rides: rides, calendar: calendar),
                                    calendar: calendar) { onEdit(goal) }
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

private struct PadGoalCard: View {
    let progress: GoalProgress
    let calendar: Calendar
    let onEdit: () -> Void

    private var metric: GoalMetric { progress.metric }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: HighlightTexts.currentPeriod(progress.period, progress.current.interval, calendar: calendar))
                    .fontWeight(.semibold)
                Text(verbatim: HighlightTexts.title(metric)).foregroundStyle(.secondary)
                Spacer()
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Edit Goal…"))
            }
            .font(.callout)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: HighlightTexts.number(metric, progress.current.value))
                    .font(.system(size: 30, weight: .semibold))
                Text(verbatim: ofTarget).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            ProgressView(value: min(1, progress.current.fraction))
                .tint(Color.track)
                .accessibilityLabel(Text(verbatim: "\(HighlightTexts.title(progress.period)), \(HighlightTexts.title(metric))"))
                .accessibilityValue(Text(verbatim: "\(HighlightTexts.number(metric, progress.current.value)) \(ofTarget)"))
            HStack(spacing: 6) {
                if progress.current.isReached {
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Color.track)
                        .accessibilityHidden(true)
                }
                Text(verbatim: note).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            history
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ofTarget: String {
        let unit = HighlightTexts.unit(metric)
        let target = HighlightTexts.number(metric, progress.current.target)
        return String(localized: "of \(unit.isEmpty ? target : "\(target) \(unit)")")
    }

    private var note: String {
        if let reached = progress.reachedAt {
            return String(localized: "Reached on \(HighlightTexts.shortDate(reached, timeZone: calendar.timeZone))")
        }
        let remaining = "\(HighlightTexts.number(metric, progress.remaining)) \(HighlightTexts.unit(metric))"
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
                        .fill(result.isReached ? Color.track : Color.track.opacity(0.4))
                        .frame(height: max(3, min(1, result.fraction) * 28))
                        .frame(maxWidth: .infinity)
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
struct PadGoalEditor: View {
    enum Target: Identifiable {
        case new
        case edit(PhoneDatabase.GoalValue)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let goal): goal.id.uuidString
            }
        }
    }

    let target: Target
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var period: GoalPeriod = .week
    @State private var metric: GoalMetric = .distance
    @State private var value: Double = 100

    private var editing: PhoneDatabase.GoalValue? {
        if case .edit(let goal) = target { goal } else { nil }
    }

    /// Combinations still free, plus the one being edited.
    private func isFree(_ period: GoalPeriod, _ metric: GoalMetric) -> Bool {
        if let editing, editing.period == period, editing.metric == metric { return true }
        return library.freeGoalCombinations.contains { $0.period == period && $0.metric == metric }
    }

    var body: some View {
        Form {
            Picker("Period", selection: $period) {
                ForEach(GoalPeriod.allCases) { Text(verbatim: HighlightTexts.title($0)).tag($0) }
            }
            Picker("Metric", selection: $metric) {
                ForEach(GoalMetric.allCases) { m in
                    Text(verbatim: HighlightTexts.title(m)).tag(m).selectionDisabled(!isFree(period, m))
                }
            }
            LabeledContent("Goal") {
                HStack {
                    TextField("Goal", value: $value, format: .number.precision(.fractionLength(0...1)))
                        .labelsHidden()
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    Text(verbatim: HighlightTexts.unit(metric).isEmpty ? HighlightTexts.title(metric) : HighlightTexts.unit(metric))
                        .foregroundStyle(.secondary)
                }
            }
            if !isFree(period, metric) {
                Text("There is already a goal for this period and metric.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let editing {
                Section {
                    Button("Delete Goal", role: .destructive) {
                        library.deleteGoal(id: editing.id)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(editing == nil ? Text("Add Goal") : Text("Edit Goal"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(value <= 0 || !isFree(period, metric))
            }
        }
        .onAppear {
            if let editing {
                period = editing.period
                metric = editing.metric
                value = HighlightTexts.display(editing.metric, editing.target)
            } else if let free = library.freeGoalCombinations.first {
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

    /// A starting value in km, rides or m, as on the Mac.
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
            library.updateGoal(id: editing.id, metric: metric, period: period, target: target)
        } else {
            library.addGoal(metric: metric, period: period, target: target)
        }
        dismiss()
    }
}

// MARK: - Texts

/// The texts of the highlights on the iPad, the same words as on the Mac (rule 8: not in the Kit).
enum HighlightTexts {
    static func title(_ kind: RecordKind) -> String {
        switch kind {
        case .longestDistance: String(localized: "Longest ride")
        case .longestDuration: String(localized: "Longest ride time")
        case .mostAscent: String(localized: "Most ascent")
        case .highestAverageSpeed: String(localized: "Highest avg speed")
        case .highestAveragePower: String(localized: "Highest avg power")
        case .highestSpeed: String(localized: "Top speed")
        case .highestPower: String(localized: "Highest power")
        case .highestCadence: String(localized: "Highest cadence")
        case .bestPower1Min: String(localized: "Best 1-minute power")
        case .mostCurves: String(localized: "Curviest ride")
        case .steepestClimb: String(localized: "Steepest climb")
        case .steepestDescent: String(localized: "Steepest descent")
        case .longestStreak: String(localized: "Longest streak")
        }
    }

    /// Number and unit, e.g. ("101,6", "km") or ("5:36", "h").
    static func value(_ kind: RecordKind, _ value: Double) -> (number: String, unit: String) {
        switch kind {
        case .longestDistance: ((value / 1000).formatted(.number.precision(.fractionLength(1))), "km")
        case .longestDuration: (Duration.seconds(value.rounded()).formatted(.time(pattern: .hourMinute)), "h")
        case .mostAscent: (Int(value.rounded()).formatted(), "m")
        case .highestAverageSpeed, .highestSpeed: ((value * 3.6).formatted(.number.precision(.fractionLength(1))), "km/h")
        case .highestAveragePower, .highestPower, .bestPower1Min: (Int(value.rounded()).formatted(), "W")
        case .highestCadence: (Int(value.rounded()).formatted(), String(localized: "rpm"))
        case .mostCurves: (Int(value.rounded()).formatted(), String(localized: "per km"))
        case .steepestClimb, .steepestDescent: (value.formatted(.number.precision(.fractionLength(1))), "%")
        case .longestStreak: (Int(value).formatted(), String(localized: "days", comment: "Unit after the number of days of a streak"))
        }
    }

    /// "101,6 km", "5 days".
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

    /// "62", "1.284" – kilometres without decimals from 100 km on.
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
