import Charts
import SwiftData
import SwiftUI
import WattspurKit

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
