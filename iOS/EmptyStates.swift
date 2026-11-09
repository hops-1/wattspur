import SwiftUI

/// Shown while the iPhone's own store has no ride yet (B-216).
struct FirstRidePrompt: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        ContentUnavailableView {
            Label("No Rides Yet", systemImage: "bicycle")
        } description: {
            if library.mode == .iCloud {
                Text("Record your first ride with “Start Ride”. Rides from your Mac appear here once it syncs with iCloud too.")
            } else {
                Text("Record your first ride with “Start Ride”. It is saved on this iPhone.")
            }
        }
    }
}
