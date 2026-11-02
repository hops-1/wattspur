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
    /// When the backup before the first sync was made (P-22); `nil` before that.
    private(set) var backupDate: Date?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let available = Self.hasEntitlement, requested = defaults.bool(forKey: SettingsKey.iCloudSyncEnabled)
        isAvailable = available
        isRequested = requested
        isActive = LibrarySync.isActive(requested: requested, available: available)
        backupDate = defaults.object(forKey: SettingsKey.iCloudSyncBackupDate) as? Date
    }

    /// The configuration the library opens with at this start.
    var configuration: ModelConfiguration {
        LibrarySync.configuration(requested: isRequested, available: isAvailable)
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

    /// Asks, backs up the library the first time (P-22) and turns the setting on.
    func turnOn(rideCount: Int) {
        guard !isRequested, state != .backingUp, confirmTurnOn(rideCount: rideCount) else { return }
        guard backupDate == nil else {
            setRequested(true)
            return
        }
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
                        Text("Saved before the first sync on \(backupDate.formatted(date: .long, time: .shortened)).")
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
            } else if sync.isActive {
                Text("On. Changes sync in the background.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Off. The library is only on this Mac.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
