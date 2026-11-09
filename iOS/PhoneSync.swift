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
    /// The notice that the folder exchange ends with 0.6 was shown once (B-263, part 1).
    private(set) var folderEndNoticeShown: Bool

    private let defaults: UserDefaults
    static let enabledKey = PhoneSettingsKey.iCloudSyncEnabled
    static let offerShownKey = PhoneSettingsKey.iCloudSyncOfferShown

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
        folderEndNoticeShown = defaults.bool(forKey: PhoneSettingsKey.folderEndNoticeShown)
    }

    /// Who still uses the folder hears once that it ends with 0.6 (B-263); not on top of the offer above.
    var folderEndNoticePending: Bool {
        mode == .folder && !folderEndNoticeShown && !offerPending
    }

    func folderEndNoticeDone() {
        folderEndNoticeShown = true
        defaults.set(true, forKey: PhoneSettingsKey.folderEndNoticeShown)
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
    /// Why the store did not open (B-264, R-41); the app then shows `LibraryErrorView` instead of the tabs.
    private(set) var libraryFailure: String?
    /// The file that did not open, for “Start with an Empty Library”.
    private(set) var failedStoreURL: URL?

    /// The library for `mode`, with the store opened when needed.
    func makeLibrary(folder: ImportFolder) -> PhoneLibrary {
        let mode = self.mode
        guard var configuration = mode.configuration else { return PhoneLibrary(folder: folder) }
        #if DEBUG
        if Self.isBrokenLibraryTest { configuration = Self.prepareBrokenLibraryTest() }
        #endif
        if Self.openStore == nil {
            do {
                let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: configuration)
                let database = PhoneDatabase(container: container, defaultBikeName: String(localized: "My eBike"))
                database.purgeTrash()
                Self.openStore = database
                Self.openStoreMode = mode
                libraryFailure = nil
                failedStoreURL = nil
            } catch {
                // Before, the app stopped here at every start (R-41). Now it shows the way out; the
                // library stays on disk as it is.
                libraryFailure = String(describing: error)
                failedStoreURL = configuration.url
                return PhoneLibrary(folder: folder)
            }
        }
        // Until the next start the store stays as it was opened, with or without iCloud.
        return PhoneLibrary(folder: folder, database: Self.openStore, mode: Self.openStoreMode ?? mode)
    }

    #if DEBUG
    /// `-WattspurBrokenLibraryTest YES` (debug builds only): a library in a temporary folder that starts
    /// out damaged, to try the view for a library that does not open (B-264) without touching the real one.
    static var isBrokenLibraryTest: Bool { UserDefaults.standard.bool(forKey: "WattspurBrokenLibraryTest") }

    /// Writes a damaged file the first time (nothing there and nothing set aside yet) and returns the
    /// configuration for the test library, without iCloud.
    private static func prepareBrokenLibraryTest() -> ModelConfiguration {
        let url = FileManager.default.temporaryDirectory.appending(path: "WattspurBrokenLibraryTest/default.store")
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path), LibraryBackup.keptFolders(storeURL: url).isEmpty {
            try? Data(repeating: 7, count: 8192).write(to: url)
        }
        return LibrarySync.configuration(requested: false, available: false, url: url)
    }
    #endif
}
