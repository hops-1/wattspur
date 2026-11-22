import SwiftUI
import WattspurKit

/// Tells the user when the library could not be saved (R-31), instead of losing the change silently.
struct SaveFailureAlert: ViewModifier {
    @State private var message: String?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: LibrarySave.failedNotification)) { note in
                message = note.userInfo?["message"] as? String ?? ""
            }
            .alert("Could Not Save", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text("The last change could not be saved and may be lost when Wattspur quits. Check that there is free space on this device. \(message ?? "")")
            }
    }
}

extension View {
    func reportsSaveFailures() -> some View { modifier(SaveFailureAlert()) }
}
