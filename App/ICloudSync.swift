import AppKit
import Observation
import Security
import SwiftData
import SwiftUI
import WattspurKit

/// "Sync with iCloud" (B-072). The setting takes effect at the next start, when the library opens
/// (`LibrarySync.configuration`). Without the iCloud entitlement, which only a build signed with the
/// developer account carries (B-215), the library stays local whatever the setting says.
@MainActor
@Observable
final class ICloudSync {
    enum State: Equatable {
        case idle
        case backingUp
        case failed(String)
    }

    /// The app may use Wattspur's iCloud container.
    let isAvailable: Bool
    /// The library opened with sync at this start.
    let isActive: Bool
    /// The setting; it takes effect at the next start.
    private(set) var isRequested: Bool
    private(set) var state: State = .idle
    /// When the last backup before turning sync on was made (P-22); `nil` before the first.
    private(set) var backupDate: Date?

    private let defaults: UserDefaults
    /// Last sync and problems while the library syncs (B-220); `nil` without sync.
    let monitor: SyncMonitor?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let available = Self.hasEntitlement, requested = defaults.bool(forKey: SettingsKey.iCloudSyncEnabled)
        isAvailable = available
        isRequested = requested
        isActive = LibrarySync.isActive(requested: requested, available: available)
        backupDate = defaults.object(forKey: SettingsKey.iCloudSyncBackupDate) as? Date
        monitor = isActive ? SyncMonitor.forLibrary(defaults: defaults) : nil
        monitor?.start()
    }

    /// The configuration the library opens with at this start.
    var configuration: ModelConfiguration {
        #if DEBUG
        if SpikeLibrary.isOn {
            return LibrarySync.configuration(requested: isRequested, available: isAvailable, url: SpikeLibrary.storeURL)
        }
        #endif
        return LibrarySync.configuration(requested: isRequested, available: isAvailable)
    }

    /// The setting differs from what the library opened with.
    var needsRestart: Bool {
        LibrarySync.isActive(requested: isRequested, available: isAvailable) != isActive
    }

    /// The switch in the settings can be used: with the entitlement, and in a Debug build to try the steps.
    var canChange: Bool {
        #if DEBUG
        state != .backingUp
        #else
        isAvailable && state != .backingUp
        #endif
    }

    /// Asks, backs up the library (P-22) and turns the setting on. Each time, not only the first: sync
    /// may have been off for months, and what comes from iCloud then meets a library changed since
    /// (R-39).
    func turnOn(rideCount: Int) {
        guard !isRequested, state != .backingUp, confirmTurnOn(rideCount: rideCount) else { return }
        state = .backingUp
        let storeURL = LibraryLocation.storeURL
        let version = AppInfo.version, build = AppInfo.build
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<URL?, Error> in
                Result { try LibrarySync.backUpBeforeFirstSync(storeURL: storeURL, appVersion: version, build: build, rideCount: rideCount) }
            }.value
            switch result {
            case .success:
                let now = Date.now
                defaults.set(now, forKey: SettingsKey.iCloudSyncBackupDate)
                backupDate = now
                state = .idle
                setRequested(true)
            case .failure(let error):
                state = .failed(String(localized: "The backup before the first sync failed, so sync stays off: \(error.localizedDescription)"))
            }
        }
    }

    func turnOff() {
        guard isRequested, confirmTurnOff() else { return }
        setRequested(false)
    }

    func showBackups() {
        NSWorkspace.shared.activateFileViewerSelecting([LibrarySync.backupFolder(for: LibraryLocation.storeURL)])
    }

    func quit() { NSApplication.shared.terminate(nil) }

    private func setRequested(_ value: Bool) {
        isRequested = value
        defaults.set(value, forKey: SettingsKey.iCloudSyncEnabled)
    }

    private func confirmTurnOn(rideCount: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Sync your library with iCloud?")
        var text = String(localized: "Wattspur uploads all \(rideCount) rides with their time series and routes, your bikes, profile, goals and saved routes into your own iCloud account. Only you can see them there. The first upload can take a while.")
        if backupDate == nil {
            text += "\n\n" + String(localized: "Before that, Wattspur saves a backup of the library beside it.")
        }
        text += "\n\n" + String(localized: "Sync starts the next time you open Wattspur.")
        alert.informativeText = text
        alert.addButton(withTitle: backupDate == nil ? String(localized: "Back Up and Turn On") : String(localized: "Turn On"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmTurnOff() -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Stop syncing with iCloud?")
        alert.informativeText = String(localized: "Your rides stay on this Mac, and in iCloud and on your other devices as they are. Changes on this Mac are no longer synced. This takes effect the next time you open Wattspur.")
        alert.addButton(withTitle: String(localized: "Turn Off"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Whether the signature carries Wattspur's iCloud container (`com.apple.developer.icloud-container-identifiers`).
    private static var hasEntitlement: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil)
        else { return false }
        return (value as? [String])?.contains(LibrarySync.containerIdentifier) == true
    }
}

/// The tab "iCloud" in the settings (B-072).
struct ICloudSettingsView: View {
    @Environment(ICloudSync.self) private var sync
    @Query(filter: Ride.listedPredicate) private var rides: [Ride]

    var body: some View {
        Form {
            LabeledContent("Sync:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Sync with iCloud", isOn: Binding(
                        get: { sync.isRequested },
                        set: { $0 ? sync.turnOn(rideCount: rides.count) : sync.turnOff() }))
                        .disabled(!sync.canChange)
                    Text("Your rides, bikes, profile, goals, saved routes and the trash in the private database of your own iCloud account, the same on this Mac and on your iPhone. There is no Wattspur server and no Wattspur account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    status
                }
            }
            if let backupDate = sync.backupDate {
                LabeledContent("Backup:") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last backup before turning sync on: \(backupDate.formatted(date: .long, time: .shortened)).")
                        Button("Show in Finder") { sync.showBackups() }
                    }
                }
            }
        }
        .formStyle(.columns)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var status: some View {
        switch sync.state {
        case .backingUp:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Backing up the library …").font(.caption)
            }
        case .failed(let text):
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .idle:
            if sync.needsRestart {
                HStack {
                    Group {
                        if sync.isRequested {
                            Text("Sync starts the next time you open Wattspur.")
                        } else {
                            Text("Sync stops the next time you open Wattspur.")
                        }
                    }
                    .font(.caption)
                    Button("Quit Wattspur") { sync.quit() }
                        .controlSize(.small)
                }
            } else if !sync.isAvailable {
                Text("This version of Wattspur cannot use iCloud yet. Sync comes with a version signed by the developer.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if sync.isActive, let monitor = sync.monitor {
                SyncStatusLine(monitor: monitor)
            } else {
                Text("Off. The library is only on this Mac.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// "Last synced …" and what keeps the sync from working (B-220). Short delays get no message.
struct SyncStatusLine: View {
    let monitor: SyncMonitor

    var body: some View {
        // The problem depends on how long a failure has lasted, so the line looks again now and then.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            VStack(alignment: .leading, spacing: 4) {
                if let problem = monitor.problem(now: context.date) {
                    Label(text(for: problem), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    if monitor.hasPendingChanges {
                        Text("Some changes from this Mac are not in iCloud yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if monitor.isSyncing {
                        ProgressView().controlSize(.mini)
                        Text("Syncing …")
                    } else if let lastSync = monitor.lastSync {
                        Text("On. Last synced \(lastSync, format: .relative(presentation: .named)).")
                    } else {
                        Text("On. Not synced yet.")
                    }
                }
                .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private func text(for problem: SyncProblem) -> String {
        switch problem {
        case .noAccount:
            String(localized: "This Mac is not signed in to iCloud, or iCloud is off for Wattspur. Changes stay on this Mac until iCloud is on again.")
        case .restricted:
            String(localized: "iCloud is restricted on this Mac. Changes stay on this Mac.")
        case .quotaExceeded:
            String(localized: "Your iCloud storage is full. Changes stay on this Mac until there is room again.")
        case .offline:
            String(localized: "No connection to iCloud. Wattspur syncs as soon as there is one again.")
        case .other(let reason):
            String(localized: "Sync is not working at the moment: \(reason)")
        }
    }
}

extension EnvironmentValues {
    /// The library syncs with iCloud at this start (B-072), for texts that say where the data is.
    @Entry var librarySyncs = false
}
