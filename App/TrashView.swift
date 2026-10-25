import SwiftData
import SwiftUI
import WattspurKit

/// Rides in the trash, restorable for 30 days (LIST-08).
struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query(filter: #Predicate<Ride> { $0.deletedAt != nil }, sort: \Ride.startDate, order: .reverse)
    private var rides: [Ride]
    @State private var confirmingEmpty = false

    var body: some View {
        // Header and list stacked (not a safe-area inset, see RideListView).
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trash").font(.title2.bold())
                Text("Rides are deleted for good after 30 days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                HStack {
                    RideRow(ride: ride)
                    Button("Restore") { RideLibrary(context: modelContext, undoManager: undoManager).restore(ride) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Trash")
        .overlay {
            if rides.isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash")
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Empty Trash…", role: .destructive) { confirmingEmpty = true }
                    .disabled(rides.isEmpty)
            }
        }
        .confirmationDialog("Delete all rides in the trash for good?", isPresented: $confirmingEmpty) {
            Button("Empty Trash", role: .destructive) {
                RideLibrary(context: modelContext).purgeTrash(olderThan: 0)
            }
        } message: {
            Text("This also deletes the original files and cannot be undone.")
        }
    }
}
