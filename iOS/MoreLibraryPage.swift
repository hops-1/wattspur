import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurSymbols
import WattspurKit
import WattspurMap

// MARK: - iCloud & Library

/// iCloud on or off, where the rides are and the state of the sync.
struct LibraryPage: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneImport.self) private var phoneImport
    @Environment(PhoneSync.self) private var sync
    @Environment(\.switchSync) private var switchSync
    @State private var confirmingOff = false

    var body: some View {
        Form {
            if sync.canChoose {
                Section {
                    Toggle("Sync with iCloud", isOn: Binding(
                        get: { sync.isOn },
                        set: { if $0 { switchSync(true) } else { confirmingOff = true } }))
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if sync.isOn {
                            DeviceText.text("One library on this iPhone and your Mac, in your own iCloud account.", pad: "One library on this iPad and your Mac, in your own iCloud account.")
                        } else {
                            DeviceText.text("Without iCloud, the rides stay on this iPhone. They reach the Mac with “Share GPX”, e.g. by AirDrop.", pad: "Without iCloud, the rides stay on this iPad. They reach the Mac with “Share GPX”, e.g. by AirDrop.")
                        }
                        if sync.needsRestart {
                            Text("Takes effect the next time Wattspur opens: close it in the app switcher.")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .confirmationDialog("Stop syncing with iCloud?", isPresented: $confirmingOff, titleVisibility: .visible) {
                    Button("Turn Off") { switchSync(false) }
                } message: {
                    DeviceText.text("The rides stay in iCloud, on your Mac and on this iPhone. New rides then stay on this iPhone.", pad: "The rides stay in iCloud, on your Mac and on this iPad. New rides then stay on this iPad.")
                }
            }
            if let monitor = library.syncMonitor {
                SyncSection(monitor: monitor)
            }
            Section {
                Button {
                    phoneImport.choosingFiles = true
                } label: {
                    Label("Import Files …", systemImage: "square.and.arrow.down")
                }
            } footer: {
                DeviceText.text("FIT and GPX files, several at once, also from iCloud Drive. Files you put into “On My iPhone › Wattspur › Import” in the Files app are imported when Wattspur opens; then they move to “Importiert”, or to “Fehler” if they cannot be read.", pad: "FIT and GPX files, several at once, also from iCloud Drive. Files you put into “On My iPad › Wattspur › Import” in the Files app are imported when Wattspur opens; then they move to “Importiert”, or to “Fehler” if they cannot be read.")
            }
            BackupSection()
            Section {
                LabeledContent("Rides") { Text((library.state?.rides.count ?? 0).formatted()) }
            } header: {
                Text("Library")
            } footer: {
                if library.mode == .iCloud {
                    DeviceText.text("Your rides are on this iPhone and in your own iCloud account, the same as on your Mac.", pad: "Your rides are on this iPad and in your own iCloud account, the same as on your Mac.")
                } else {
                    DeviceText.text("Your rides are on this iPhone. Sync with the Mac comes with iCloud.", pad: "Your rides are on this iPad. Sync with the Mac comes with iCloud.")
                }
            }
        }
    }
}

/// Back up the library into a folder of the rider's choice and bring a backup back (B-302), in the
/// format of the Mac.
private struct BackupSection: View {
    enum Picking { case destination, backup }

    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneSync.self) private var sync
    @Environment(PhoneBackup.self) private var backup
    @Environment(Recorder.self) private var recorder
    @AppStorage(PhoneSettingsKey.autoBackup) private var automatic = false
    /// What the folder picker is for. Kept until the picker's result is handled: SwiftUI sets
    /// `choosingFolder` back to false before it calls the result, so the purpose must not hang on it.
    @State private var picking: Picking?
    @State private var choosingFolder = false

    /// With sync on, the restore reaches the other devices too (B-265); the confirmation says so.
    private var syncs: Bool { sync.isOn || library.mode == .iCloud }

    var body: some View {
        @Bindable var backup = backup
        Section {
            Button {
                picking = .destination
                choosingFolder = true
            } label: {
                Label("Back Up Library …", systemImage: "externaldrive.badge.plus")
            }
            .disabled(backup.isWorking || backup.state == .restoreStaged)
            Button {
                picking = .backup
                choosingFolder = true
            } label: {
                Label("Restore Backup …", systemImage: "arrow.counterclockwise")
            }
            .disabled(backup.isWorking || backup.state == .restoreStaged || recorder.isRecording)
            Toggle("Back Up Automatically", isOn: $automatic)
            status
        } header: {
            Text("Backup")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                DeviceText.text("A backup is a folder with all your rides, bikes, goals and notes, the same as on the Mac. Choose iCloud Drive, On My iPhone or a USB stick. A backup from this iPhone restores on the Mac, and the other way round.", pad: "A backup is a folder with all your rides, bikes, goals and notes, the same as on the Mac. Choose iCloud Drive, On My iPad or a USB stick. A backup from this iPad restores on the Mac, and the other way round.")
                if automatic {
                    if backup.automaticFolderMissing {
                        Text("The folder for the automatic backup is no longer there. Back up once by hand to choose a new one.")
                            .foregroundStyle(.orange)
                    } else if !backup.hasFolder {
                        Text("Back up once by hand to choose the folder. After that Wattspur backs up there when it opens and the last backup is older than a week, and keeps the newest three automatic backups.")
                    } else {
                        Text("When Wattspur opens and the last backup is older than a week, it backs up into the folder you chose last. It keeps the newest three automatic backups there and deletes only its own.")
                    }
                }
                if let last = backup.lastBackup {
                    Text("Last backup: \(last.formatted(date: .abbreviated, time: .shortened))")
                }
            }
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            let purpose = picking
            picking = nil
            guard case .success(let folder) = result else { return }
            switch purpose {
            case .destination: backup.backUp(to: folder, rideCount: library.state?.rides.count)
            case .backup: backup.choose(folder)
            case nil: break
            }
        }
        .alert("Restore This Backup?", isPresented: Binding(get: { backup.candidate != nil },
                                                            set: { if !$0 { backup.candidate = nil } }),
               presenting: backup.candidate) { candidate in
            Button("Restore", role: .destructive) { backup.restore(candidate) }
            Button("Cancel", role: .cancel) { backup.candidate = nil }
        } message: { candidate in
            Text(confirmation(for: candidate.manifest))
        }
    }

    @ViewBuilder private var status: some View {
        switch backup.state {
        case .idle:
            EmptyView()
        case .working(let text):
            HStack(spacing: 8) {
                ProgressView()
                Text(text)
            }
        case .saved(let name, let place):
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Backed Up")
                    Text("“\(name)” in “\(place)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        case .restoreStaged:
            VStack(alignment: .leading, spacing: 8) {
                Label("Ready to Restore", systemImage: "arrow.triangle.2.circlepath")
                Text("Close Wattspur in the app switcher and open it again. It then replaces the library with the backup.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Cancel Restore", role: .destructive) { backup.cancelRestore() }
            }
        case .failed(let text):
            Label {
                Text(text)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }

    private func confirmation(for manifest: LibraryBackup.Manifest) -> String {
        var text = String(localized: "The backup is from \(manifest.createdAt.formatted(date: .long, time: .shortened)) (Wattspur \(manifest.appVersion)).")
        if let count = manifest.rideCount {
            text += " " + String(localized: "It holds \(count) rides.")
        }
        text += "\n\n" + DeviceText.string("The library on this iPhone is replaced with the backup the next time Wattspur opens. Rides and changes since the backup are not in it. The current library is kept in a folder beside it.", pad: "The library on this iPad is replaced with the backup the next time Wattspur opens. Rides and changes since the backup are not in it. The current library is kept in a folder beside it.")
        if syncs {
            text += "\n\n" + String(localized: "Sync with iCloud is on: the rides in iCloud and on all your devices are then replaced with the backup too.")
        }
        if manifest.build.compare(AppInfo.build, options: .numeric) == .orderedDescending {
            text += "\n\n" + String(localized: "This backup was made by a newer version of Wattspur. Update Wattspur before you restore it.")
        }
        return text
    }
}

/// "Last synced …" and what keeps the sync from working (B-220). Short delays get no message.
private struct SyncSection: View {
    let monitor: SyncMonitor

    var body: some View {
        Section {
            // The problem depends on how long a failure has lasted, so the rows look again now and then.
            TimelineView(.periodic(from: .now, by: 15)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    if let problem = monitor.problem(now: context.date) {
                        Label(text(for: problem), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        if monitor.hasPendingChanges {
                            DeviceText.text("Some changes from this iPhone are not in iCloud yet. Keep iCloud on for Wattspur until they are, or they may be lost.", pad: "Some changes from this iPad are not in iCloud yet. Keep iCloud on for Wattspur until they are, or they may be lost.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Last synced") {
                        if monitor.isSyncing {
                            HStack(spacing: 6) {
                                ProgressView()
                                Text("Syncing …")
                            }
                        } else if let lastSync = monitor.lastSync {
                            Text(lastSync, format: .relative(presentation: .named))
                        } else {
                            Text("Not yet")
                        }
                    }
                }
            }
        } header: {
            Text("iCloud")
        }
    }

    private func text(for problem: SyncProblem) -> String {
        switch problem {
        case .noAccount:
            DeviceText.string("This iPhone is not signed in to iCloud, or iCloud is off for Wattspur. New rides stay only on this iPhone.", pad: "This iPad is not signed in to iCloud, or iCloud is off for Wattspur. New rides stay only on this iPad.")
        case .restricted:
            DeviceText.string("iCloud is restricted on this iPhone. New rides stay only on this iPhone.", pad: "iCloud is restricted on this iPad. New rides stay only on this iPad.")
        case .quotaExceeded:
            DeviceText.string("Your iCloud storage is full. New rides stay on this iPhone until there is room again.", pad: "Your iCloud storage is full. New rides stay on this iPad until there is room again.")
        case .offline:
            String(localized: "No connection to iCloud. Wattspur syncs as soon as there is one again.")
        case .other(let reason):
            String(localized: "Sync is not working at the moment: \(reason)")
        }
    }
}
