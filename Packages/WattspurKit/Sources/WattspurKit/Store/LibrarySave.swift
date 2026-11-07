import Foundation
import os
import SwiftData

/// Saving the library in one place (R-31). A failed save (disk full, a broken store) used to be
/// swallowed by `try?`, and the change was gone after the next start without a word. Now it is
/// logged and posted, so the app can tell the user.
public enum LibrarySave {
    /// Posted on the main actor when saving failed; `userInfo["message"]` holds the error's text.
    public static let failedNotification = Notification.Name("WattspurLibrarySaveFailed")

    private static let logger = Logger(subsystem: "io.github.hops-1.wattspur", category: "library")

    /// Saves `context`; on an error it logs and posts `failedNotification` and returns `false`.
    @MainActor @discardableResult
    public static func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("Saving the library failed: \(error.localizedDescription, privacy: .public)")
            NotificationCenter.default.post(name: failedNotification, object: nil,
                                            userInfo: ["message": error.localizedDescription])
            return false
        }
    }
}
