import UIKit
import WattspurCore

/// The app's `WriteHold` (B-366): background time from iOS while the library writes, so the app is
/// not suspended with a lock on the store in the App Group's container (0xdead10cc).
@MainActor
enum LibraryWriteHold {
    static let shared = WriteHold(
        begin: { expired in
            let id = UIApplication.shared.beginBackgroundTask(withName: "Finish library writes") {
                MainActor.assumeIsolated { expired() }
            }
            return id == .invalid ? nil : id.rawValue
        },
        end: { UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: $0)) }
    )

    /// How long the app stays awake after a write or after going to the background: the change is
    /// saved, but iCloud writes its export of it into the store right after.
    static let lingerSeconds = 10.0

    /// Holds for `seconds` from now.
    static func linger(_ seconds: Double = lingerSeconds) {
        shared.hold()
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            shared.release()
        }
    }

    /// Runs a write while held, and a little longer.
    @discardableResult
    static func writing<T>(_ body: () throws -> T) rethrows -> T {
        defer { linger() }
        return try shared.during(body)
    }
}
