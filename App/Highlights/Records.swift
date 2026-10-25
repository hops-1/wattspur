import Charts
import SwiftData
import SwiftUI
import WattspurKit

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
