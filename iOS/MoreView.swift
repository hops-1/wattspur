import SwiftUI
import WattspurKit

/// The tab “More” (design C): the folder shared with the Mac, or with the iPhone's own store the
/// trash (B-217), and the version.
struct MoreView: View {
    @Environment(ImportFolder.self) private var folder
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        Form {
            if library.usesDatabase {
                Section {
                    NavigationLink {
                        TrashView()
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

            Section {
                VersionFooter()
            }
        }
        .navigationTitle("More")
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
            Text("Choose the folder “Wattspur Import” in iCloud Drive that the Mac watches.")
        }
    }
}

/// "Last synced …" and what keeps the sync from working (B-220). Short delays get no message.
private struct SyncSection: View {
    let monitor: SyncMonitor

    var body: some View {
        // The problem depends on how long a failure has lasted, so the section looks again now and then.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            Section {
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
            } header: {
                Text("iCloud")
            }
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
