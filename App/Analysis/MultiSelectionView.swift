import Charts
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Several rides selected in the list (LIST-06)

/// Shown instead of the ride detail when several rides are selected.
struct MultiSelectionView: View {
    let rideIDs: Set<UUID>
    let onAnalyze: () -> Void
    /// Opens the comparison; only for 2–4 rides (CMP-01).
    let onCompare: () -> Void
    /// Called with the merged ride (B-095).
    let onMerged: (UUID) -> Void

    @Query(filter: Ride.listedPredicate) private var rides: [Ride]
    @State private var merging: MergeCandidates?
    @Environment(\.undoManager) private var undoManager

    private var canCompare: Bool { RideComparison.canCompare(count: rideIDs.count) }

    var body: some View {
        let aggregate = RideAggregate(rides.filter { rideIDs.contains($0.id) }.map(\.figures))
        ContentUnavailableView {
            Label("\(rideIDs.count) rides selected", systemImage: "square.stack")
        } description: {
            Text(verbatim: "\(RideFormat.distance(aggregate.distance)) · \(AnalysisFormat.hoursMinutes(aggregate.timerTime))")
                .monospacedDigit()
        } actions: {
            Button(action: onAnalyze) {
                Label("Analyze Selected Rides", systemImage: "chart.bar")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut("a", modifiers: [.command, .shift])
            Button(action: onCompare) {
                Label("Compare", systemImage: "tablecells")
            }
            .buttonStyle(.glass)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!canCompare)
            Button { merging = MergeCandidates(ids: rideIDs) } label: {
                Label("Merge…", systemImage: "arrow.triangle.merge")
            }
            .buttonStyle(.glass)
            BikeAssignMenu(rides: rides.filter { rideIDs.contains($0.id) }) {
                Label("Assign Bike", systemImage: "bicycle")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            if canCompare {
                Text("Compare: ⇧⌘C · Merge only rides that do not overlap in time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("You can compare 2 to 4 rides. Deselect some rides first.")
                    .font(.caption.weight(.semibold))
                Text("Merge only rides that do not overlap in time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $merging) { candidates in
            MergeRidesSheet(rideIDs: candidates.ids, undoManager: undoManager, onMerged: onMerged)
        }
    }
}
