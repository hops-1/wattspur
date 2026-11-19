import SwiftUI

/// Shown while the iPhone's own store has no ride yet (B-216).
struct FirstRidePrompt: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        ContentUnavailableView {
            Label("No Rides Yet", systemImage: "bicycle")
        } description: {
            if !RecordingAvailability.isSupported {
                // The iPad records no rides for now (B-292).
                Text("Rides recorded on your iPhone or imported on your Mac appear here once they sync with iCloud. You can also import FIT and GPX files under Rides.")
            } else if library.mode == .iCloud {
                Text("Record your first ride with “Start Ride”. Rides from your Mac appear here once it syncs with iCloud too.")
            } else {
                DeviceText.text("Record your first ride with “Start Ride”. It is saved on this iPhone.", pad: "Record your first ride with “Start Ride”. It is saved on this iPad.")
            }
        }
    }
}
