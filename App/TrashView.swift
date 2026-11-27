import SwiftData
import SwiftUI
import WattspurKit

/// Rides and planned tours in the trash, restorable for 30 days (LIST-08, B-385).
struct TrashView: View {
    @Environment(RideLibrary.self) private var sharedLibrary
    @Environment(\.undoManager) private var undoManager
    @Query(filter: #Predicate<Ride> { $0.deletedAt != nil }, sort: \Ride.startDate, order: .reverse)
    private var rides: [Ride]
    @Query(filter: #Predicate<PlannedRoute> { $0.deletedAt != nil }, sort: \PlannedRoute.deletedAt, order: .reverse)
    private var tours: [PlannedRoute]
    private var isEmpty: Bool { rides.isEmpty && tours.isEmpty }
    @State private var confirmingEmpty = false

    var body: some View {
        // Header and list stacked (not a safe-area inset, see RideListView).
        VStack(spacing: 0) {
            // "Empty Trash" sits in the header, not in the title bar: there it reached into the
            // sidebar's grey area (B-161).
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trash").font(.title2.bold())
                    Text(tours.isEmpty ? LocalizedStringKey("Rides are deleted for good after 30 days.") : "Rides and tours are deleted for good after 30 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Empty Trash…", role: .destructive) { confirmingEmpty = true }
                    .disabled(isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            list
        }
    }

    private var list: some View {
        List {
            if tours.isEmpty {
                rideRows
            } else {
                if !rides.isEmpty {
                    Section("Rides") { rideRows }
                }
                Section("Planned Tours") {
                    ForEach(tours) { route in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: route.name).lineLimit(1)
                                Text(verbatim: PlannedTourText.figures(of: route))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Spacer(minLength: 8)
                            Button { restore(route) } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                            .help(Text("Restore"))
                        }
                        .contextMenu {
                            Button("Restore") { restore(route) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Trash")
        .overlay {
            if isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash")
            }
        }
        .confirmationDialog(tours.isEmpty ? LocalizedStringKey("Delete all rides in the trash for good?") : "Delete all rides and tours in the trash for good?",
                            isPresented: $confirmingEmpty) {
            Button("Empty Trash", role: .destructive) {
                sharedLibrary.purgeTrash(olderThan: 0)
            }
        } message: {
            Text("This also deletes the original files and cannot be undone.")
        }
    }

    @ViewBuilder
    private var rideRows: some View {
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

    private func restore(_ ride: Ride) {
        sharedLibrary.using(undoManager).restore(ride)
    }

    private func restore(_ route: PlannedRoute) {
        sharedLibrary.using(undoManager).restore([route])
    }
}
