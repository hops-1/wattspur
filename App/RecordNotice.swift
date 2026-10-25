import SwiftData
import SwiftUI
import WattspurKit

/// "New record" after an import (ADV-R2): a notice at the top of the window that
/// names the record and the value it beat. Several records from one import share
/// one notice.
struct RecordNotice: Identifiable, Equatable {
    let id = UUID()
    let breaks: [RecordBreak]

    var title: String {
        breaks.count == 1 ? String(localized: "New record") : String(localized: "\(breaks.count) new records")
    }

    /// "Highest avg speed: 27.3 km/h (previously 26.1 km/h)" for each record.
    var lines: [String] {
        breaks.map { b in
            String(localized: "\(HighlightsFormat.title(b.kind)): \(HighlightsFormat.text(b.kind, b.value)) (previously \(HighlightsFormat.text(b.kind, b.previousValue)))")
        }
    }

    /// The ride to show: the one that set the first record.
    var rideID: UUID? { breaks.first?.rideID }
}

struct RecordNoticeView: View {
    let notice: RecordNotice
    let onShow: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: notice.title).font(.headline)
                ForEach(notice.lines.prefix(3), id: \.self) { line in
                    Text(verbatim: line).font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
                if notice.lines.count > 3 {
                    Text("and \(notice.lines.count - 3) more").font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button("Show Ride", action: onShow)
                .buttonStyle(.glass)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(Text("Close"))
            .accessibilityLabel(Text("Close"))
            .keyboardShortcut(.cancelAction)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(width: 560)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// Checks for broken records whenever a ride was imported, from any source.
@MainActor
enum RecordCheck {
    /// Import log dates up to here were checked. The first launch with this feature
    /// starts from now, so older imports do not show up as new records.
    private static var checkedUntil: Double {
        get { UserDefaults.standard.double(forKey: SettingsKey.recordsCheckedUntil) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKey.recordsCheckedUntil) }
    }

    static func prepare() {
        if checkedUntil == 0 { checkedUntil = Date.now.timeIntervalSinceReferenceDate }
    }

    /// The notice for imports since the last check, or `nil`.
    static func run(using library: RideLibrary) -> RecordNotice? {
        let since = Date(timeIntervalSinceReferenceDate: checkedUntil)
        guard let latest = library.latestImportDate(), latest > since else { return nil }
        let breaks = library.newRecords(importedAfter: since, calendar: GoalPeriod.calendar())
        checkedUntil = latest.timeIntervalSinceReferenceDate
        return breaks.isEmpty ? nil : RecordNotice(breaks: breaks)
    }
}

/// "Your 2026" above the ride list (LIST-04): kilometres and rides of the current
/// year with a small bar per month. A click opens the year in review.
struct YearTileView: View {
    let rides: [Ride]
    let onOpen: () -> Void

    private var calendar: Calendar { GoalPeriod.calendar() }

    var body: some View {
        let year = calendar.component(.year, from: .now)
        let review = YearReview(rides.filter(\.countsInStatistics).map(\.highlightRide), year: year, calendar: calendar)
        let month = calendar.component(.month, from: .now) - 1
        let maxKm = max(1, review.months.map(\.distance).max() ?? 1)
        let km = Int((review.aggregate.distance / 1000).rounded()).formatted()
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Your \(String(year))")
                    Image(systemName: "chevron.right").font(.caption2.bold())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(km) km").font(.title2.bold())
                    Text("· \(review.aggregate.rideCount) rides").font(.callout).foregroundStyle(.secondary)
                }
                .monospacedDigit()
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(review.months.indices, id: \.self) { i in
                        let distance = review.months[i].distance
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i == month ? Color.accentColor
                                  : distance > 0 ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.2))
                            .frame(height: max(2, distance / maxKm * 22))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 22, alignment: .bottom)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help(Text("Open the year in review"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Your \(String(year))"))
        .accessibilityValue(Text(verbatim: "\(km) km, \(String(localized: "\(review.aggregate.rideCount) rides"))"))
        .accessibilityHint(Text("Open the year in review"))
        .accessibilityAddTraits(.isButton)
    }
}
