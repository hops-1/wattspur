import AppKit
import Observation
import SwiftData
import SwiftUI
import WattspurKit

/// Where the library file lives. The same place the container opens (the default store).
enum LibraryLocation {
    static var storeURL: URL {
        #if DEBUG
        if isBrokenLibraryTest { return brokenLibraryTestURL }
        #endif
        return ModelConfiguration().url
    }

    #if DEBUG
    /// `-WattspurBrokenLibraryTest YES` (debug builds only): opens a library in a temporary folder that
    /// starts out damaged, to try the view for a library that does not open (B-264) without touching the
    /// real one. “Start with an Empty Library” then opens an empty one there.
    static var isBrokenLibraryTest: Bool { UserDefaults.standard.bool(forKey: "WattspurBrokenLibraryTest") }

    static var brokenLibraryTestURL: URL {
        FileManager.default.temporaryDirectory.appending(path: "WattspurBrokenLibraryTest/default.store")
    }

    /// Writes a damaged file the first time (nothing there and nothing set aside yet) and returns the
    /// configuration for the test library, without iCloud.
    static func prepareBrokenLibraryTest() -> ModelConfiguration {
        let url = brokenLibraryTestURL
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path), LibraryBackup.keptFolders(storeURL: url).isEmpty {
            try? Data(repeating: 7, count: 8192).write(to: url)
        }
        return LibrarySync.configuration(requested: false, available: false, url: url)
    }
    #endif
}

/// "Library Backup…" (P-22): saves the whole library as a folder and brings it back.
@MainActor
@Observable
final class LibraryBackupCenter {
    enum State: Equatable {
        case idle
        case working(String)
        case saved(URL)
        /// A restore is staged; it takes effect when the app starts again.
        case restoreStaged
        case failed(String)
    }

    private(set) var state: State = .idle

    var isWorking: Bool {
        if case .working = state { return true }
        return false
    }

    func backUp(rideCount: Int) {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose where to save the backup. Wattspur creates a folder there.")
        panel.prompt = String(localized: "Back Up Here")
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        state = .working(String(localized: "Backing up the library …"))
        let storeURL = LibraryLocation.storeURL
        let version = AppInfo.version, build = AppInfo.build
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
                let scoped = destination.startAccessingSecurityScopedResource()
                defer { if scoped { destination.stopAccessingSecurityScopedResource() } }
                return Result {
                    try LibraryBackup.create(storeURL: storeURL, in: destination, appVersion: version, build: build, rideCount: rideCount)
                }
            }.value
            switch result {
            case .success(let folder): state = .saved(folder)
            case .failure(let error): state = .failed(Self.message(for: error))
            }
        }
    }

    func restore() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose the backup folder to restore.")
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let storeURL = LibraryLocation.storeURL
        let manifest: LibraryBackup.Manifest
        do {
            manifest = try LibraryBackup.inspect(folder, storeName: storeURL.lastPathComponent)
        } catch {
            state = .failed(Self.message(for: error))
            return
        }
        guard confirmRestore(manifest) else { return }

        state = .working(String(localized: "Preparing the restore …"))
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

    func quit() { NSApplication.shared.terminate(nil) }

    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    private func confirmRestore(_ manifest: LibraryBackup.Manifest) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Restore this backup?")
        var text = String(localized: "The backup is from \(manifest.createdAt.formatted(date: .long, time: .shortened)) (Wattspur \(manifest.appVersion)).")
        if let count = manifest.rideCount {
            text += " " + String(localized: "It holds \(count) rides.")
        }
        text += "\n\n" + String(localized: "Wattspur quits and replaces the library with the backup the next time you open it. Rides and changes since the backup are not in it. The current library is kept in a folder beside it.")
        // With sync, the restore reaches iCloud and every other device too (B-265).
        if UserDefaults.standard.bool(forKey: SettingsKey.iCloudSyncEnabled) {
            text += "\n\n" + String(localized: "Sync with iCloud is on: the rides in iCloud and on all your devices are then replaced with the backup too.")
        }
        if manifest.build.compare(AppInfo.build, options: .numeric) == .orderedDescending {
            text += "\n\n" + String(localized: "This backup was made by a newer version of Wattspur. Update Wattspur before you restore it.")
        }
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Restore"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func message(for error: Error) -> String {
        switch error as? LibraryBackup.Failure {
        case .noLibrary: String(localized: "There is no library to back up yet.")
        case .notABackup: String(localized: "This folder is not a Wattspur backup.")
        case .unsupportedFormat: String(localized: "This backup was made by a newer version of Wattspur. Update Wattspur to restore it.")
        case .database(_, let detail): String(localized: "The library file could not be read: \(detail)")
        case .restoreFailed(let kept, true, let detail):
            String(localized: "The backup could not be restored: \(detail). Your library is as it was before, and a copy of it is in the folder “\(kept.lastPathComponent)” beside it. Choose the backup again to try once more.")
        case .restoreFailed(let kept, false, let detail):
            String(localized: "The backup could not be restored: \(detail). Your library as it was before is in the folder “\(kept.lastPathComponent)” beside it. Quit Wattspur, and put the files from that folder back in place of the library.")
        case nil: error.localizedDescription
        }
    }
}

/// "Backup from 26.10.2026 restored" after the start that put the backup in place (P-22), or why it
/// failed (B-265). A failure stays until it is closed.
@MainActor
@Observable
final class LibraryRestoreNotice {
    struct Notice: Equatable {
        let id = UUID()
        let text: String
        let isFailure: Bool
    }

    private(set) var current: Notice?

    func show(backupDate: Date, synced: Bool) {
        var text = String(localized: "Backup from \(backupDate.formatted(date: .numeric, time: .omitted)) restored successfully.")
        if synced { text += " " + String(localized: "iCloud now brings your other devices to the same state.") }
        current = Notice(text: text, isFailure: false)
    }

    func showFailure(_ text: String) { current = Notice(text: text, isFailure: true) }
    func hide() { current = nil }
}

struct LibraryRestoreNoticeView: View {
    let notice: LibraryRestoreNotice.Notice
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if notice.isFailure {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            Text(verbatim: notice.text).font(.callout)
                .frame(maxWidth: 520, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onClose) { Image(systemName: "xmark").font(.caption.weight(.bold)) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.separator.opacity(0.6)))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
    }
}

struct LibraryBackupView: View {
    @Environment(LibraryBackupCenter.self) private var center
    @Query(filter: Ride.listedPredicate) private var rides: [Ride]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library Backup").font(.title2.bold())
            Text("A backup is a folder with all your rides, bikes, goals and notes. Keep it on another disk or in iCloud Drive. Your settings and the watched folder are not part of it.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Back Up…", systemImage: "externaldrive.badge.plus") {
                    center.backUp(rideCount: rides.count)
                }
                .keyboardShortcut(.defaultAction)
                Button("Restore…", systemImage: "arrow.counterclockwise") { center.restore() }
            }
            .buttonStyle(.glass)
            .disabled(center.isWorking || center.state == .restoreStaged)

            status
        }
        .padding(24)
        .frame(width: 460, alignment: .leading)
        .animation(.default, value: center.state)
    }

    @ViewBuilder private var status: some View {
        switch center.state {
        case .idle:
            EmptyView()
        case .working(let text):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(text)
            }
        case .saved(let url):
            VStack(alignment: .leading, spacing: 8) {
                Label("Backup saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Text(verbatim: url.lastPathComponent).font(.callout).textSelection(.enabled)
                Button("Show in Finder") { center.reveal(url) }
            }
        case .restoreStaged:
            VStack(alignment: .leading, spacing: 8) {
                Label("Ready to restore", systemImage: "arrow.triangle.2.circlepath")
                Text("Quit Wattspur and open it again. It then replaces the library with the backup.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Quit Wattspur") { center.quit() }
            }
        case .failed(let text):
            Label {
                Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }
}
