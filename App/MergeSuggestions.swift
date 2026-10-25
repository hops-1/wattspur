import SwiftUI
import WattspurKit

/// Rides that probably belong together, found after an import (B-096, LIST-10).
/// Only held until the user decides; nothing is stored and nothing is merged
/// without a click on "Merge".
@MainActor
@Observable
final class MergeSuggestionCenter {
    static let gapKey = "mergeSuggestionGapMinutes"

    private(set) var pending: [RideMergeSuggestion.Group] = []

    /// The gap from the settings, in minutes; 0 switches the suggestions off.
    static var gapMinutes: Int {
        UserDefaults.standard.object(forKey: gapKey) as? Int ?? RideMergeSuggestion.defaultGapMinutes
    }

    /// Looks for groups that include one of the rides just imported.
    func suggest(involving rideIDs: [UUID], library: RideLibrary) {
        let groups = library.mergeSuggestions(involving: rideIDs, maxGapMinutes: Self.gapMinutes)
        for group in groups {
            // A newer group replaces an older one that shares a ride with it.
            pending.removeAll { old in !Set(old.rideIDs).isDisjoint(with: group.rideIDs) }
            pending.append(group)
        }
    }

    func dismiss(_ group: RideMergeSuggestion.Group) {
        pending.removeAll { $0.rideIDs == group.rideIDs }
    }
}

extension RideMergeSuggestion.Group {
    /// "2 rides from 15 Oct probably belong together".
    var message: String {
        let day = start.formatted(Date.FormatStyle(timeZone: timeZone).day().month(.abbreviated))
        return String(localized: "\(rideIDs.count) rides from \(day) probably belong together")
    }
}

/// Above the ride list after an import: "2 rides from 15 Oct probably belong together".
struct MergeSuggestionBanner: View {
    let group: RideMergeSuggestion.Group
    let onMerge: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(verbatim: group.message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "arrow.triangle.merge")
                    .foregroundStyle(Color.accentColor)
            }
            HStack {
                Spacer()
                Button("Not Now", action: onDismiss)
                Button("Merge", action: onMerge)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}
