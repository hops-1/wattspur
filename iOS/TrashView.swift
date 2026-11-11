import SwiftUI
import WattspurCore

/// The trash on the iPhone (B-217), with the same rules as on the Mac: a ride stays 30 days and can be
/// restored, then it is deleted at the next start. Swipe right to restore, left to delete for good.
struct TrashView: View {
    @Environment(PhoneLibrary.self) private var library
    @State private var confirmingEmpty = false
    /// Beside the list of “More” in landscape (B-298): no navigation bar, so “Empty” is in the list.
    var embedded = false

    var body: some View {
        List {
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
        .overlay {
            if library.trash.isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash",
                                       description: Text("Deleted rides stay here for 30 days."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if embedded && !library.trash.isEmpty {
                Button("Empty Trash", role: .destructive) { confirmingEmpty = true }
                    .buttonStyle(.glass)
                    .tint(.red)
                    .padding(.bottom, LandscapeTabBar.height + 12)
            }
        }
        .toolbar {
            if !embedded && !library.trash.isEmpty {
                Button("Empty") { confirmingEmpty = true }
            }
        }
        .confirmationDialog("Delete all rides in the trash for good?", isPresented: $confirmingEmpty,
                            titleVisibility: .visible) {
            Button("Delete \(library.trash.count) Rides", role: .destructive) {
                for trashed in library.trash { library.deletePermanently(trashed.ride) }
            }
        }
        .navigationTitle("Trash")
    }
}
