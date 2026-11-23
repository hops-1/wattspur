import Charts
import SwiftUI
import WattspurCore
import WattspurKit

// MARK: - Year

struct PadYearReview: View {
    let review: YearReview
    let isCurrentYear: Bool
    let calendar: Calendar
    let rides: [UUID: PhoneDatabase.StatsRide]
    let sport: Sport
    /// One column on the iPhone (B-228).
    var compact = false
    /// For the PDF (B-336): the calendar without scrolling, and which parts this page shows.
    var pdf = false
    var showsOverview = true
    var showsRecords = true
    let onOpenRide: (UUID) -> Void

    private static let everest = 8_848.0

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 24) {
            if showsOverview { overview }
            if showsRecords && !showsOverview {
                card(title: Text("Records this year")) { yearRecords }
            }
        }
    }

    @ViewBuilder private var overview: some View {
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
                PadYearHeatmap(year: review.year, days: review.days, calendar: calendar, compact: compact,
                           fixedCell: pdf ? 5.5 : nil) { ids in
                    if let first = ids.first { onOpenRide(first) }
                }
            }
            if showsRecords {
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
            } else {
                card(title: Text("Kilometres per month")) { monthChart }
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
                    Text(verbatim: HighlightsFormat.title(record.kind))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
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
    /// A fixed square size without scrolling, for the PDF (B-336).
    var fixedCell: CGFloat?
    let onOpenRides: ([UUID]) -> Void

    /// Opacity of the track colour for the levels 1 to 4.
    static let shades = [0.3, 0.5, 0.75, 1.0]

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Group {
                if let fixedCell {
                    grid(cell: fixedCell)
                } else if compact {
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
    private var weeks: [[Date?]] { HeatmapCalendar.weeks(year: year, calendar: calendar) }

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
        HeatmapCalendar.monthStarting(in: week, calendar: calendar).map { calendar.shortMonthSymbols[$0 - 1] }
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
            if fixedCell != nil {
                // Printed: nothing to tap.
                HStack(spacing: 6) { scale }
            }
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
