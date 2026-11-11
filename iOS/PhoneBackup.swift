import Foundation
import Observation
import WattspurKit

/// The backup on the iPhone (B-302), in the same format as “File › Back Up Library…” on the Mac (P-22):
/// a folder “Wattspur Backup …” with the database, its larger blobs and `manifest.json`. A backup made
/// here restores on the Mac and the other way round (`LibraryBackup` in the Kit).
///
/// Restoring only works with iCloud sync off: with sync on, iCloud would play back what changed since
/// the backup (R-29; the way with sync on is B-265). The backup is staged now and swapped in at the next
/// start, before the store opens (`applyAtLaunch`).
@MainActor @Observable
final class PhoneBackup {
    enum State: Equatable {
        case idle
        case working(String)
        /// Saved: the folder of the backup and where it is.
        case saved(name: String, place: String)
        /// A restore is staged; it takes effect when the app opens again.
        case restoreStaged
        case failed(String)
    }

    /// A backup the rider chose to restore, waiting for the confirmation.
    struct Candidate: Identifiable, Equatable {
        let id = UUID()
        let folder: URL
        let manifest: LibraryBackup.Manifest
    }

    /// What happened to a staged restore at the start.
    enum LaunchResult: Equatable {
        case restored(backupDate: Date)
        /// Sync was switched on in between: the library stays as it is, the staged backup is dropped.
        case skippedSyncOn
    }

    private(set) var state: State = .idle
    var candidate: Candidate?
    /// The folder for the automatic backup is gone (deleted, stick removed): a notice, not an error.
    private(set) var automaticFolderMissing = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = LibraryBackup.hasPendingRestore(storeURL: Self.storeURL) ? .restoreStaged : .idle
    }

    /// Where SwiftData keeps the iPhone's store (`ModelConfiguration` without a URL), with or without iCloud.
    static var storeURL: URL { URL.applicationSupportDirectory.appending(path: "default.store") }

    var isWorking: Bool {
        if case .working = state { return true }
        return false
    }

    var lastBackup: Date? { defaults.object(forKey: PhoneSettingsKey.lastBackupDate) as? Date }

    var isAutomatic: Bool {
        get { defaults.bool(forKey: PhoneSettingsKey.autoBackup) }
        set { defaults.set(newValue, forKey: PhoneSettingsKey.autoBackup) }
    }

    /// Whether a folder was chosen before, so the automatic backup knows where to go.
    var hasFolder: Bool { defaults.data(forKey: PhoneSettingsKey.backupFolderBookmark) != nil }

    // MARK: Back up

    /// Backs up into `destination`, a folder from the file picker (iCloud Drive, On My iPhone, a USB stick).
    func backUp(to destination: URL, rideCount: Int?) {
        guard !isWorking else { return }
        let scoped = destination.startAccessingSecurityScopedResource()
        // Kept for the automatic backup: the folder chosen last.
        if let bookmark = try? destination.bookmarkData() {
            defaults.set(bookmark, forKey: PhoneSettingsKey.backupFolderBookmark)
            automaticFolderMissing = false
        }
        run(into: destination, scoped: scoped, rideCount: rideCount, automatic: false)
    }

    /// The automatic backup (B-302): when switched on, the last backup is a week old or more, and the
    /// folder chosen last is still there. Not while a ride is recorded; the caller checks that.
    func backUpAutomaticallyIfDue(rideCount: Int?, now: Date = .now) {
        guard isAutomatic, !isWorking, state != .restoreStaged,
              LibraryBackup.Automatic.isDue(lastBackup: lastBackup, now: now),
              FileManager.default.fileExists(atPath: Self.storeURL.path),
              let bookmark = defaults.data(forKey: PhoneSettingsKey.backupFolderBookmark)
        else { return }
        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else {
            automaticFolderMissing = true
            return
        }
        let scoped = folder.startAccessingSecurityScopedResource()
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue else {
            if scoped { folder.stopAccessingSecurityScopedResource() }
            automaticFolderMissing = true
            return
        }
        automaticFolderMissing = false
        if stale, let fresh = try? folder.bookmarkData() {
            defaults.set(fresh, forKey: PhoneSettingsKey.backupFolderBookmark)
        }
        run(into: folder, scoped: scoped, rideCount: rideCount, automatic: true)
    }

    private func run(into destination: URL, scoped: Bool, rideCount: Int?, automatic: Bool) {
        state = .working(automatic ? String(localized: "Backing up automatically …") : String(localized: "Backing up the library …"))
        let storeURL = Self.storeURL
        let version = AppInfo.version, build = AppInfo.build
        Task {
            let result = await Task.detached(priority: automatic ? .utility : .userInitiated) { () -> Result<URL, Error> in
                defer { if scoped { destination.stopAccessingSecurityScopedResource() } }
                return Result {
                    let folder = try LibraryBackup.create(storeURL: storeURL, in: destination, appVersion: version, build: build,
                                                          rideCount: rideCount, automatic: automatic)
                    if automatic { LibraryBackup.Automatic.prune(in: destination) }
                    return folder
                }
            }.value
            switch result {
            case .success(let folder):
                defaults.set(Date.now, forKey: PhoneSettingsKey.lastBackupDate)
                state = .saved(name: folder.lastPathComponent, place: destination.lastPathComponent)
            case .failure(let error):
                state = .failed(Self.message(for: error))
            }
        }
    }

    // MARK: Restore

    /// Reads the chosen backup folder and asks for the confirmation (`candidate`).
    func choose(_ folder: URL) {
        guard !isWorking else { return }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            let manifest = try LibraryBackup.inspect(folder, storeName: Self.storeURL.lastPathComponent)
            candidate = Candidate(folder: folder, manifest: manifest)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Stages the confirmed backup; it replaces the library when the app opens again.
    func restore(_ candidate: Candidate) {
        self.candidate = nil
        guard !isWorking else { return }
        state = .working(String(localized: "Preparing the restore …"))
        let storeURL = Self.storeURL
        let folder = candidate.folder
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<Void, Error> in
                let scoped = folder.startAccessingSecurityScopedResource()
                defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
                return Result { try LibraryBackup.stageRestore(from: folder, storeURL: storeURL) }
            }.value
            switch result {
            case .success: state = .restoreStaged
            case .failure(let error): state = .failed(Self.message(for: error))
            }
        }
    }

    func cancelRestore() {
        LibraryBackup.cancelPendingRestore(storeURL: Self.storeURL)
        state = .idle
    }

    /// Swaps a staged backup in. Call it at the start, before the store opens. `syncOn`: the store opens
    /// with iCloud; then the backup is not swapped in (R-29).
    static func applyAtLaunch(syncOn: Bool) -> LaunchResult? {
        let storeURL = Self.storeURL
        guard LibraryBackup.hasPendingRestore(storeURL: storeURL) else { return nil }
        if syncOn {
            LibraryBackup.cancelPendingRestore(storeURL: storeURL)
            return .skippedSyncOn
        }
        let manifest = LibraryBackup.pendingManifest(storeURL: storeURL)
        guard (try? LibraryBackup.applyPendingRestore(storeURL: storeURL)) != nil, let manifest else { return nil }
        return .restored(backupDate: manifest.createdAt)
    }

    static func message(for error: Error) -> String {
        switch error as? LibraryBackup.Failure {
        case .noLibrary: String(localized: "There is no library to back up yet.")
        case .notABackup: String(localized: "This folder is not a Wattspur backup.")
        case .unsupportedFormat: String(localized: "This backup was made by a newer version of Wattspur. Update Wattspur to restore it.")
        case .database(_, let detail): String(localized: "The library file could not be read: \(detail)")
        case nil: error.localizedDescription
        }
    }
}
