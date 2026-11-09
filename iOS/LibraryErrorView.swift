import SwiftUI
import WattspurKit

/// Shown instead of the tabs when the library does not open (B-264, R-41): a damaged file, a failed
/// migration or a bad restore. Before, the app stopped at every start. Nothing here deletes anything:
/// an empty library starts only after the old one is moved into a folder beside it.
struct LibraryErrorView: View {
    /// Why the library did not open, as the error said.
    let error: String
    /// The file that did not open.
    let storeURL: URL?
    /// Opens the library again, after the old one was set aside.
    let reopen: () -> Void

    @State private var showsBackups = false
    @State private var confirmingEmpty = false
    @State private var problem: String?

    private var report: String {
        DiagnosticReport(appVersion: AppInfo.version, build: AppInfo.build, commit: AppInfo.commit,
                         rideCount: 0, trashedRideCount: 0, ridesByParserVersion: [:], importLog: [],
                         libraryError: error).text
    }

    private var kept: [URL] {
        storeURL.map { LibraryBackup.keptFolders(storeURL: $0) } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Wattspur could not open your library. The file may be damaged, or an update went wrong. Nothing has been deleted: the library stays where it is until you choose what to do.")
                    Text(verbatim: DiagnosticReport.withoutHome(error))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                Section {
                    Button("Show Backups", systemImage: "clock.arrow.circlepath") { showsBackups = true }
                } footer: {
                    Text("Earlier libraries Wattspur kept on this iPhone. Backups to restore are made on the Mac (File › Library Backup…).")
                }
                Section {
                    ShareLink(item: report, subject: Text("Wattspur diagnostics")) {
                        Label("Create Diagnostics", systemImage: "stethoscope")
                    }
                } footer: {
                    Text("A report with versions and the error, without rides or positions. Send it yourself if you want help.")
                }
                Section {
                    Button("Start with an Empty Library", systemImage: "tray") { confirmingEmpty = true }
                        .disabled(storeURL == nil)
                } footer: {
                    Text("Moves the library into a folder “Damaged Library” beside it and opens an empty one. With iCloud, the synced rides come back.")
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Library Not Opened")
            .sheet(isPresented: $showsBackups) { backups }
            .confirmationDialog("Start with an empty library?", isPresented: $confirmingEmpty, titleVisibility: .visible) {
                Button("Start with an Empty Library", role: .destructive) { startEmpty() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The library is moved into a folder “Damaged Library” beside it, not deleted.")
            }
        }
    }

    private var backups: some View {
        NavigationStack {
            List {
                if kept.isEmpty {
                    Text("No earlier libraries on this iPhone. With iCloud, the rides are also on the Mac and in iCloud.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(kept, id: \.self) { folder in
                        Text(verbatim: folder.lastPathComponent)
                    }
                }
            }
            .navigationTitle("Backups")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsBackups = false }
                }
            }
        }
    }

    private func startEmpty() {
        guard let storeURL else { return }
        do {
            try LibraryBackup.setAsideDamaged(storeURL: storeURL)
            problem = nil
            reopen()
        } catch {
            problem = String(localized: "The library could not be moved aside: \(error.localizedDescription)")
        }
    }
}
