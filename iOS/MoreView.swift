import SwiftUI
import WattspurCore
import WattspurKit

/// The tab “More” (design C): the folder shared with the Mac, or with the iPhone's own store the
/// trash (B-217), and the version.
struct MoreView: View {
    @Environment(ImportFolder.self) private var folder
    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneSync.self) private var sync
    @Environment(\.switchSync) private var switchSync
    @State private var confirmingOff = false
    @AppStorage(Recorder.vehicleKey) private var vehicle = RecordingVehicle.eBike
    @AppStorage(MotionRecorder.rawLogKey) private var recordsRawMotion = false
    @Environment(\.isLandscape) private var isLandscape

    var body: some View {
        Group {
            if isLandscape {
                // Two columns in landscape (B-243): library on the left, recording and version on the right.
                HStack(spacing: 0) {
                    Form { librarySections }
                        .tabBarRoomInLandscape()
                    Form { recordingSections }
                }
            } else {
                Form {
                    librarySections
                    recordingSections
                }
            }
        }
        .navigationTitle("More")
    }

    /// iCloud or the folder, the trash and the sync status.
    @ViewBuilder private var librarySections: some View {
        if sync.canChoose {
            Section {
                Toggle("Sync with iCloud", isOn: Binding(
                    get: { sync.isOn },
                    set: { if $0 { switchSync(true) } else { confirmingOff = true } }))
            } footer: {
                if sync.isOn {
                    Text("One library on this iPhone and your Mac, in your own iCloud account.")
                } else {
                    Text("Without iCloud, rides reach the Mac through a folder it watches, or with “Share GPX”, e.g. by AirDrop.")
                }
            }
            .confirmationDialog("Stop syncing with iCloud?", isPresented: $confirmingOff, titleVisibility: .visible) {
                Button("Turn Off") { switchSync(false) }
            } message: {
                Text("The rides stay in iCloud and on your Mac. This iPhone then shows the rides the Mac provides in the folder, and new rides go there as GPX.")
            }
        }
        if library.usesDatabase {
            Section {
                NavigationLink {
                    TrashView()
                        .hidesTabBarInLandscape()
                } label: {
                    LabeledContent {
                        Text(library.trash.count.formatted())
                    } label: {
                        Label("Trash", systemImage: "trash")
                    }
                }
            } header: {
                Text("Library")
            } footer: {
                if library.mode == .iCloud {
                    Text("Your rides are on this iPhone and in your own iCloud account, the same as on your Mac.")
                } else {
                    Text("Your rides are on this iPhone. Sync with the Mac comes with iCloud.")
                }
            }
            if let monitor = library.syncMonitor {
                SyncSection(monitor: monitor)
            }
        } else {
            folderSection
        }
    }

    /// The vehicle for the recording and the version.
    @ViewBuilder private var recordingSections: some View {
        Section {
            Picker("Vehicle", selection: $vehicle) {
                Text("E-Bike").tag(RecordingVehicle.eBike)
                Text("Motorcycle").tag(RecordingVehicle.motorcycle)
            }
        } header: {
            Text("Recording")
        } footer: {
            Text("GPS jumps look like impossible speeds and are left out. For an e-bike that is above 100 km/h, for a motorcycle above 300 km/h.")
        }

        // Spike V-16; goes again once acceleration and lean angle are part of the recording.
        Section {
            Toggle("Record Raw Motion", isOn: $recordsRawMotion)
        } header: {
            Text("Test")
        } footer: {
            Text("For a test of acceleration and lean angle: each recording also writes the motion sensors and GPS into a file. You find it in the Files app under “On My iPhone › Wattspur › Bewegung”. About 20 MB per hour.")
        }

        Section {
            VersionFooter()
        }
    }

    private var folderSection: some View {
        Section {
            if let url = folder.url {
                LabeledContent("Folder", value: url.lastPathComponent)
            } else {
                Text("No folder chosen yet.")
                    .foregroundStyle(.secondary)
            }
            ChooseFolderButton(title: folder.url == nil ? "Choose Folder…" : "Choose Another Folder…")
            if let problem = folder.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Wattspur Import")
        } footer: {
            Text("Choose the folder the Mac watches: “Wattspur Import” in iCloud Drive, or a folder in another service such as Dropbox or OneDrive. Without a folder, send recordings to the Mac with “Share GPX”, e.g. by AirDrop.")
        }
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
                            Text("Some changes from this iPhone are not in iCloud yet. Keep iCloud on for Wattspur until they are, or they may be lost.")
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
            String(localized: "This iPhone is not signed in to iCloud, or iCloud is off for Wattspur. New rides stay only on this iPhone.")
        case .restricted:
            String(localized: "iCloud is restricted on this iPhone. New rides stay only on this iPhone.")
        case .quotaExceeded:
            String(localized: "Your iCloud storage is full. New rides stay on this iPhone until there is room again.")
        case .offline:
            String(localized: "No connection to iCloud. Wattspur syncs as soon as there is one again.")
        case .other(let reason):
            String(localized: "Sync is not working at the moment: \(reason)")
        }
    }
}
