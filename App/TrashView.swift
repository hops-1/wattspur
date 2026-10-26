import SwiftData
import SwiftUI
import WattspurKit

/// Rides in the trash, restorable for 30 days (LIST-08).
struct TrashView: View {
    @Environment(RideLibrary.self) private var sharedLibrary
    @Environment(\.undoManager) private var undoManager
    @Query(filter: #Predicate<Ride> { $0.deletedAt != nil }, sort: \Ride.startDate, order: .reverse)
    private var rides: [Ride]
    @State private var confirmingEmpty = false

    var body: some View {
        // Header and list stacked (not a safe-area inset, see RideListView).
        VStack(spacing: 0) {
            // "Empty Trash" sits in the header, not in the title bar: there it reached into the
            // sidebar's grey area (B-161).
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trash").font(.title2.bold())
                    Text("Rides are deleted for good after 30 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Empty Trash…", role: .destructive) { confirmingEmpty = true }
                    .disabled(rides.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            list
        }
    }

    private var list: some View {
        List {
            ForEach(rides) { ride in
                // Name and figures keep the whole row; "Restore" is a small symbol button at
                // the end and also in the context menu, so the text no longer wraps (B-161).
                HStack {
                    RideRow(ride: ride)
                    Button { restore(ride) } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .help(Text("Restore"))
                }
                .contextMenu {
                    Button("Restore") { restore(ride) }
                }
            }
        }
        .navigationTitle("Trash")
        .overlay {
            if rides.isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete all rides in the trash for good?", isPresented: $confirmingEmpty) {
            Button("Empty Trash", role: .destructive) {
                sharedLibrary.purgeTrash(olderThan: 0)
            }
        } message: {
            Text("This also deletes the original files and cannot be undone.")
        }
    }

    private func restore(_ ride: Ride) {
        sharedLibrary.using(undoManager).restore(ride)
    }
}
