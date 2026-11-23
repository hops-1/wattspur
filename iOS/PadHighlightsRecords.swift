import Charts
import SwiftUI
import WattspurCore
import WattspurKit

// MARK: - Records

struct PadRecords: View {
    let records: [RideRecord]
    let rides: [UUID: PhoneDatabase.StatsRide]
    let sport: Sport
    var compact = false
    /// Three narrow cards a row, for the PDF (B-336).
    var pdf = false
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: pdf ? 150 : 260), spacing: compact || pdf ? 12 : 20, alignment: .top)],
                      alignment: .leading, spacing: compact || pdf ? 12 : 20) {
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
        let value = HighlightsFormat.value(record.kind, record.value)
        let holder = record.rideIDs.first.flatMap { rides[$0] }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "star").foregroundStyle(Color.track).accessibilityHidden(true)
                Text(verbatim: HighlightsFormat.title(record.kind)).foregroundStyle(.secondary)
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
                Text(verbatim: value.number).font(.system(size: pdf ? 22 : 30, weight: .semibold))
                Text(verbatim: value.unit).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            if let streak = record.streak {
                let zone = holder?.highlight.timeZone ?? .current
                Text(verbatim: "\(HighlightsFormat.longDate(streak.firstDay, timeZone: zone)) – \(HighlightsFormat.longDate(streak.lastDay, timeZone: zone))")
                    .font(.callout)
                let distance = record.rideIDs.compactMap { rides[$0]?.figures.distance }.reduce(0, +)
                Text(verbatim: "\(String(localized: "\(record.rideIDs.count) rides")) · \(RideFormat.distance(distance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let holder {
                Text(verbatim: holder.name).font(.callout).lineLimit(1)
                Text(verbatim: "\(HighlightsFormat.longDate(holder.highlight.startDate, timeZone: holder.highlight.timeZone)) · \(detail(record.kind, holder))")
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
        case .longestDistance: HighlightsFormat.text(.longestDuration, ride.figures.timerTime)
        default: RideFormat.distance(ride.figures.distance)
        }
    }
}
