import Foundation
import Observation
import SwiftData
import WattspurKit

/// Which way the rides take between iPhone and Mac (B-218): over iCloud, or without it over a folder
/// the Mac watches and “Share” (iOS 0.2). The build says whether iCloud is possible at all
/// (`WattspurDatabase` in the Info.plist); with it, the user chooses in “More”.
///
/// Without iCloud the user may not want it or have no room for it, so the folder way stays.
@MainActor @Observable
final class PhoneSync {
    /// What the build allows.
    let buildMode: PhoneDatabase.Mode
    /// The user's choice; only matters when the build allows iCloud.
    private(set) var isOn: Bool
    /// A user of the folder way gets the offer to switch once.
    private(set) var offerPending: Bool
    /// Knows only the folder way of iOS 0.2: without iCloud the folder stays (B-263, R-38).
    let folderUser: Bool

    private let defaults: UserDefaults
    static let enabledKey = "iCloudSyncEnabled"
    static let offerShownKey = "iCloudSyncOfferShown"

    /// `hadFolder`: a folder was chosen before; `hadStore`: the iPhone's own store exists (a build
    /// with the store ran before). Only who had a folder and no store knows just the folder way.
    init(buildMode: PhoneDatabase.Mode, hadFolder: Bool, hadStore: Bool, defaults: UserDefaults = .standard) {
        self.buildMode = buildMode
        self.defaults = defaults
        let folderUser = !PhoneDatabase.Mode.syncOnAtFirstStart(hadFolder: hadFolder, hadStore: hadStore)
        self.folderUser = folderUser
        if defaults.object(forKey: Self.enabledKey) == nil {
            // New users start with iCloud; users of the folder way keep it until they switch.
            defaults.set(!folderUser, forKey: Self.enabledKey)
        }
        let on = defaults.bool(forKey: Self.enabledKey)
        isOn = on
        offerPending = buildMode == .iCloud && !on && folderUser && !defaults.bool(forKey: Self.offerShownKey)
    }

    var canChoose: Bool { buildMode == .iCloud }

    /// Where SwiftData keeps the store by default (`ModelConfiguration` without a URL).
    static var storeExists: Bool {
        FileManager.default.fileExists(atPath: URL.applicationSupportDirectory.appending(path: "default.store").path)
    }

    /// The way the app works now.
    var mode: PhoneDatabase.Mode {
        buildMode.effective(syncOn: isOn, folderUser: folderUser)
    }

    /// The store is open with or without iCloud, and the choice now wants the other: that takes a new
    /// start, as the mirror cannot be stopped or the file opened twice (R-63).
    var needsRestart: Bool {
        guard let open = Self.openStoreMode, mode.usesStore else { return false }
        return open != mode
    }

    func set(_ on: Bool) {
        isOn = on
        defaults.set(on, forKey: Self.enabledKey)
        offerDone()
    }

    func offerDone() {
        offerPending = false
        defaults.set(true, forKey: Self.offerShownKey)
    }

    // MARK: - Store

    /// The store opens once per launch: CloudKit's mirror cannot open the same file twice. Switching
    /// back and forth keeps it; it ends with the app.
    private static var openStore: PhoneDatabase?
    /// The mode the store was opened with.
    private static var openStoreMode: PhoneDatabase.Mode?

    /// The library for `mode`, with the store opened when needed.
    func makeLibrary(folder: ImportFolder) -> PhoneLibrary {
        let mode = self.mode
        guard let configuration = mode.configuration else { return PhoneLibrary(folder: folder) }
        if Self.openStore == nil {
            do {
                let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: configuration)
                let database = PhoneDatabase(container: container, defaultBikeName: String(localized: "My eBike"))
                database.purgeTrash()
                Self.openStore = database
                Self.openStoreMode = mode
            } catch {
                fatalError("Could not open the Wattspur library: \(error)")
            }
        }
        // Until the next start the store stays as it was opened, with or without iCloud.
        return PhoneLibrary(folder: folder, database: Self.openStore, mode: Self.openStoreMode ?? mode)
    }
}
