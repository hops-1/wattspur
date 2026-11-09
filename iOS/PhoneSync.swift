import Foundation
import Observation
import SwiftData
import WattspurKit

/// Whether the iPhone's store syncs with the Mac over iCloud (B-218). The build says whether iCloud is
/// possible at all (`WattspurDatabase` in the Info.plist); with it, the user chooses in “More”. Without
/// iCloud the rides stay on the iPhone, and “Share GPX” takes one to the Mac.
///
/// The folder way of iOS 0.2 ended with 0.6 (B-263). Who still used it hears that once, with the way
/// to iCloud; their rides are on the Mac, which gives them back over iCloud.
@MainActor @Observable
final class PhoneSync {
    /// What the build allows.
    let buildMode: PhoneDatabase.Mode
    /// The user's choice; only matters when the build allows iCloud.
    private(set) var isOn: Bool
    /// Used the folder way until 0.6 and has not heard yet that it ended (B-263).
    private(set) var folderGoneNoticePending: Bool

    private let defaults: UserDefaults
    static let enabledKey = PhoneSettingsKey.iCloudSyncEnabled

    /// `hadFolder`: a folder was chosen before (iOS 0.2 to 0.5); `hadStore`: the iPhone's own store
    /// exists. Only who had a folder and no store used the folder way.
    init(buildMode: PhoneDatabase.Mode, hadFolder: Bool, hadStore: Bool, defaults: UserDefaults = .standard) {
        self.buildMode = buildMode
        self.defaults = defaults
        let folderUser = PhoneDatabase.Mode.wasFolderUser(hadFolder: hadFolder, hadStore: hadStore)
        if defaults.object(forKey: Self.enabledKey) == nil {
            // New users start with iCloud. A user of the folder way had chosen against it (the key
            // was set to off for them) and keeps that choice; the notice offers the switch.
            defaults.set(!folderUser, forKey: Self.enabledKey)
        }
        isOn = defaults.bool(forKey: Self.enabledKey)
        folderGoneNoticePending = folderUser && !defaults.bool(forKey: PhoneSettingsKey.folderGoneNoticeShown)
    }

    /// Whether this iPhone had chosen a folder (iOS 0.2 to 0.5), from the bookmark it kept.
    static func hadFolder(defaults: UserDefaults = .standard) -> Bool {
        defaults.data(forKey: PhoneSettingsKey.importFolderBookmark) != nil
    }

    func folderGoneNoticeDone() {
        folderGoneNoticePending = false
        defaults.set(true, forKey: PhoneSettingsKey.folderGoneNoticeShown)
    }

    var canChoose: Bool { buildMode == .iCloud }

    /// Where SwiftData keeps the store by default (`ModelConfiguration` without a URL).
    static var storeExists: Bool {
        FileManager.default.fileExists(atPath: URL.applicationSupportDirectory.appending(path: "default.store").path)
    }

    /// The way the app works now.
    var mode: PhoneDatabase.Mode {
        buildMode.effective(syncOn: isOn)
    }

    /// The store is open with or without iCloud, and the choice now wants the other: that takes a new
    /// start, as the mirror cannot be stopped or the file opened twice (R-63).
    var needsRestart: Bool {
        guard let open = Self.openStoreMode else { return false }
        return open != mode
    }

    func set(_ on: Bool) {
        isOn = on
        defaults.set(on, forKey: Self.enabledKey)
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
    func makeLibrary() -> PhoneLibrary {
        let mode = self.mode
        var configuration = mode.configuration
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
                return PhoneLibrary(database: nil, mode: mode)
            }
        }
        // Until the next start the store stays as it was opened, with or without iCloud.
        return PhoneLibrary(database: Self.openStore, mode: Self.openStoreMode ?? mode)
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
