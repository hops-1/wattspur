import SwiftUI
import WattspurCore
import WattspurKit

/// The trash on the iPhone (B-217), with the same rules as on the Mac: a ride stays 30 days and can be
/// restored, then it is deleted at the next start. Swipe right to restore, left to delete for good.
struct TrashView: View {
    @Environment(PhoneLibrary.self) private var library
    @State private var confirmingEmpty = false
    /// Beside the list of “More” in landscape (B-298): no navigation bar, so “Empty” is in the list.
    var embedded = false

    /// Nothing in the trash, neither rides nor planned tours (B-373).
    private var isEmpty: Bool { library.trash.isEmpty && library.trashedTours.isEmpty }

    var body: some View {
        List {
            Section {
                rides
            } header: {
                if !library.trashedTours.isEmpty && !library.trash.isEmpty { Text("Rides") }
            }
            // Planned tours (B-373), with the same 30 days.
            if !library.trashedTours.isEmpty {
                Section("Planned Tours") {
                    ForEach(library.trashedTours) { trashed in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                PlannedTourPreview(points: trashed.tour.preview)
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trashed.tour.name).font(.headline).lineLimit(2)
                                    Text(PlannedTourFormat.figures(trashed.tour))
                                        .font(.subheadline)
                                        .monospacedDigit()
                                }
                            }
                            Text("Deleted for good in \(trashed.daysLeft(days: PhoneDatabase.trashDays)) days")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .swipeActions(edge: .leading) {
                            Button("Restore", systemImage: "arrow.uturn.backward") { library.restore(trashed.tour) }
                                .tint(.track)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) { library.deletePermanently(trashed.tour) }
                                .tint(.red)
                        }
                    }
                }
            }
        }
        .overlay {
            if isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash",
                                       description: Text("Deleted rides stay here for 30 days."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if embedded && !isEmpty {
                Button("Empty Trash", role: .destructive) { confirmingEmpty = true }
                    .buttonStyle(.glass)
                    .tint(.red)
                    .padding(.bottom, LandscapeTabBar.height + 12)
            }
        }
        .toolbar {
            if !embedded && !isEmpty {
                Button("Empty") { confirmingEmpty = true }
            }
        }
        .confirmationDialog("Delete everything in the trash for good?", isPresented: $confirmingEmpty,
                            titleVisibility: .visible) {
            Button(emptyLabel, role: .destructive) {
                for trashed in library.trash { library.deletePermanently(trashed.ride) }
                for trashed in library.trashedTours { library.deletePermanently(trashed.tour) }
            }
        }
        .navigationTitle("Trash")
    }

    private var emptyLabel: String {
        let rides = library.trash.count, tours = library.trashedTours.count
        if tours == 0 { return String(localized: "Delete \(rides) Rides") }
        if rides == 0 { return String(localized: "Delete \(tours) Tours") }
        return String(localized: "Delete \(rides) Rides and \(tours) Tours")
    }

    @ViewBuilder private var rides: some View {
        ForEach(library.trash) { trashed in
            VStack(alignment: .leading, spacing: 4) {
                RideRow(ride: trashed.ride, bike: library.state?.bike(withID: trashed.ride.bikeID))
                Text("Deleted for good in \(trashed.daysLeft()) days")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .swipeActions(edge: .leading) {
                Button("Restore", systemImage: "arrow.uturn.backward") { library.restore(trashed.ride) }
                    .tint(.track)
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) { library.deletePermanently(trashed.ride) }
                    .tint(.red)
            }
        }
    }
}
