import SwiftUI
import WattspurCore
import WidgetKit

/// The widget “This Week” on the Home Screen (B-224): distance and rides of the week, a bar per day,
/// and in the medium size the last ride. The numbers come from the app (`WidgetShare`); the week
/// itself is counted here, so a new week starts at zero on Monday even before the app runs.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShare.weekWidgetKind, provider: WeekProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("This Week")
        .description("Distance and rides of this week, and your last ride.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeekEntry: TimelineEntry {
    var date: Date
    /// `nil` before the app has written anything.
    var snapshot: WeekSnapshot?
}

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry {
        WeekEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        // The gallery shows a sample week until the app has rides.
        let snapshot = WidgetShare.load()
        completion(WeekEntry(date: .now, snapshot: context.isPreview && snapshot == nil ? Self.sample : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
        let snapshot = WidgetShare.load()
        var entries = [WeekEntry(date: .now, snapshot: snapshot)]
        // A new week starts empty by itself; the app reloads the widget when it has new rides.
        if let next = WeekSnapshot.nextWeek() {
            entries.append(WeekEntry(date: next, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Three rides this week, for the gallery and the placeholder.
    static var sample: WeekSnapshot {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let rides = [(0, 18_400.0), (2, 9_700.0), (3, 24_100.0)].compactMap { day, distance in
            calendar.date(byAdding: .hour, value: day * 24 + 17, to: start).map { (start: $0, distance: distance) }
        }.filter { $0.start <= .now }
        return WeekSnapshot(rides: rides.isEmpty ? [(start: .now, distance: 18_400)] : rides,
                            lastRide: .init(name: String(localized: "Evening Ride"), start: rides.last?.start ?? .now,
                                            distance: rides.last?.distance ?? 18_400))
    }
}

struct WeekWidgetView: View {
    let entry: WeekEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WeekWidgetContent(entry: entry, showsLastRide: family == .systemMedium)
    }
}

/// The content without the widget environment, so the app can draw it too (for checks).
struct WeekWidgetContent: View {
    let entry: WeekEntry
    /// The medium size has room for the last ride beside the week.
    let showsLastRide: Bool

    var body: some View {
        if showsLastRide {
            HStack(alignment: .top, spacing: 16) {
                week
                Divider()
                lastRide
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            week
        }
    }

    private var totals: RidePeriodTotals {
        (entry.snapshot ?? .empty).totals(now: entry.date)
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("This Week", systemImage: "bicycle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.track)
            let parts = ActivityFormat.distanceParts(totals.weekDistance)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: parts.number)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text(verbatim: parts.unit)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text("\(totals.weekRides) rides")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            DayBars(days: (entry.snapshot ?? .empty).days(now: entry.date), today: entry.date)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var lastRide: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Ride")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let ride = entry.snapshot?.lastRide {
                Text(ride.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(Self.date(ride.start, timeZone: ride.timeZone))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(verbatim: ActivityFormat.distance(ride.distance))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            } else {
                Text("Open Wattspur to show your rides here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// “Mo., 2. Nov., 17:00”, in the time zone of the ride like in the app.
    private static func date(_ date: Date, timeZone: String?) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).hour().minute()
        style.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        return date.formatted(style)
    }
}

/// A small bar per day of the week, today's letter in the track colour.
private struct DayBars: View {
    let days: [(day: Date, distance: Double)]
    let today: Date

    var body: some View {
        let longest = max(days.map(\.distance).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days, id: \.day) { day in
                let isToday = Calendar.current.isDate(day.day, inSameDayAs: today)
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day.distance > 0 ? Color.track : Color.secondary.opacity(0.3))
                        .frame(height: day.distance > 0 ? max(4, 22 * day.distance / longest) : 3)
                    Text(day.day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.track : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 34, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
