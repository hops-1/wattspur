#if DEBUG
import Foundation
import SwiftData
import WattspurKit

/// A test library for the CloudKit spike (V-15), only in debug builds: `-WattspurSpikeLibrary YES`
/// (with `-WattspurSpikeSync YES` to turn sync on).
///
/// A debug build shares the sandbox container, and so the library and the settings, with the installed
/// release. Turning sync on there would make the release sync too. With this switch the debug build opens
/// its own file in `Spike/`, seeded once with a copy of the real library, and keeps its iCloud setting in
/// its own defaults. The real library and the release stay untouched.
enum SpikeLibrary {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "WattspurSpikeLibrary") }

    /// `Spike/default.store` beside the real library.
    static var storeURL: URL {
        ModelConfiguration().url.deletingLastPathComponent().appending(path: "Spike/default.store")
    }

    /// Settings of the spike (sync on/off, date of the backup), apart from the release's.
    static var defaults: UserDefaults { UserDefaults(suiteName: "io.github.hops-1.wattspur.spike") ?? .standard }

    /// Copies the real library into the spike folder at the first start. `-WattspurSpikeSync YES|NO`
    /// sets the iCloud setting of the spike without the dialog (there is a copy, so no backup is needed).
    static func prepare() {
        // A launch argument arrives as the text "YES" or "NO"; `bool(forKey:)` reads both.
        if UserDefaults.standard.object(forKey: "WattspurSpikeSync") != nil {
            defaults.set(UserDefaults.standard.bool(forKey: "WattspurSpikeSync"), forKey: SettingsKey.iCloudSyncEnabled)
        }
        guard !FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            try LibraryBackup.copyLibrary(from: ModelConfiguration().url, to: storeURL)
        } catch LibraryBackup.Failure.noLibrary {
            // No library yet: the spike starts empty.
        } catch {
            fatalError("Could not copy the library for the spike: \(error)")
        }
    }
}
#endif
