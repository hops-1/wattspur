import Foundation
import SwiftData

/// Sync of the library over iCloud (B-072, REQUIREMENTS 10.22): the same SwiftData store, mirrored by
/// CloudKit into the private database of the user's own iCloud account.
///
/// It takes two things: the user turns it on, and the app is signed with the iCloud entitlement for
/// `containerIdentifier` (a developer account, B-215). Without the entitlement the library stays local,
/// whatever the setting says, so an ad-hoc signed build starts as before. Both are read once at the start:
/// the container cannot switch while it is open.
public enum LibrarySync {
    public static let containerIdentifier = "iCloud.io.github.hops-1.wattspur"
    /// The folder beside the library that holds the backup before the first sync (P-22).
    public static let backupFolderName = "Backups Before iCloud"

    /// Whether the library syncs at this start.
    public static func isActive(requested: Bool, available: Bool) -> Bool {
        requested && available
    }

    /// The configuration the library opens with. Without sync it says `.none` explicitly: the default
    /// `.automatic` starts syncing on its own as soon as the app carries the iCloud entitlement.
    /// Both cases name the same file, `default.store`, so turning sync on or off keeps the library.
    public static func configuration(requested: Bool, available: Bool) -> ModelConfiguration {
        ModelConfiguration(cloudKitDatabase: isActive(requested: requested, available: available) ? .private(containerIdentifier) : .none)
    }

    /// Backs up the library before it syncs for the first time (P-22), into `backupFolderName` beside it.
    /// Returns the backup folder, or `nil` if there is no library yet and so nothing to lose.
    @discardableResult
    public static func backUpBeforeFirstSync(
        storeURL: URL, appVersion: String, build: String, rideCount: Int?, now: Date = .now
    ) throws -> URL? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }
        let folder = backupFolder(for: storeURL)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try LibraryBackup.create(storeURL: storeURL, in: folder, appVersion: appVersion, build: build,
                                        rideCount: rideCount, now: now)
    }

    public static func backupFolder(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appending(path: backupFolderName)
    }
}
