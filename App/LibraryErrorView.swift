import AppKit
import SwiftUI
import WattspurKit

/// Shown instead of the app when the library does not open (B-264, R-41): a damaged file, a failed
/// migration or a bad backup. Before, the app stopped at every start and the only way out was to delete
/// files by hand. Nothing here deletes anything: an empty library starts only after the old one is moved
/// into a folder beside it.
struct LibraryErrorView: View {
    /// Why the library did not open, as the error said.
    let error: String
    @Environment(LibraryBackupCenter.self) private var backup
    @State private var exporting = false
    @State private var confirmingEmpty = false
    @State private var problem: String?

    private var storeURL: URL { LibraryLocation.storeURL }

    private var report: DiagnosticReport {
        DiagnosticReport(appVersion: AppInfo.version, build: AppInfo.build, commit: AppInfo.commit,
                         rideCount: 0, trashedRideCount: 0, ridesByParserVersion: [:], importLog: [],
                         libraryError: error)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("The Library Could Not Be Opened", systemImage: "exclamationmark.triangle.fill")
                .font(.title2.bold())
                .symbolRenderingMode(.multicolor)
            Text("Wattspur could not open your library. The file may be damaged, or an update or a restore went wrong. Nothing has been deleted: the library stays where it is until you choose what to do.")
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: DiagnosticReport.withoutHome(error))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 14) {
                choice(title: "Show Backups",
                       text: "Backups before iCloud and earlier libraries Wattspur kept. To bring a backup back, choose it with “Restore Backup…”; it replaces the library at the next start.") {
                    Button("Show Backups") { showBackups() }
                    Button("Restore Backup…") { backup.restore() }
                        .disabled(backup.isWorking || backup.state == .restoreStaged)
                }
                choice(title: "Create Diagnostics",
                       text: "Saves a report with versions and the error, without rides or positions. Send it yourself if you want help.") {
                    Button("Create Diagnostics…") { exporting = true }
                }
                choice(title: "Start with an Empty Library",
                       text: "Moves the library into a folder “Damaged Library” beside it and opens Wattspur with an empty one. With iCloud, the synced rides come back.") {
                    Button("Start with an Empty Library…") { confirmingEmpty = true }
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

            if backup.state == .restoreStaged {
                Text("The backup is ready. Wattspur restores it when it opens again.")
                    .foregroundStyle(.secondary)
            }
            if case .failed(let message) = backup.state {
                Text(message).foregroundStyle(.red)
            }
            if let problem {
                Text(problem).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                if backup.state == .restoreStaged {
                    Button("Open Again") { Self.relaunch() }
                        .keyboardShortcut(.defaultAction)
                }
                Button("Quit Wattspur") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(28)
        .frame(width: 620)
        .fixedSize()
        .fileExporter(isPresented: $exporting, document: DiagnosticsDocument(text: report.text, files: [:]),
                      contentType: .plainText,
                      defaultFilename: "Wattspur-Diagnostics-\(Date.now.formatted(.iso8601.year().month().day()))") { _ in }
        .confirmationDialog("Start with an empty library?", isPresented: $confirmingEmpty) {
            Button("Start with an Empty Library") { startEmpty() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The library is moved into a folder “Damaged Library” beside it, not deleted. Wattspur then opens again with an empty library.")
        }
    }

    private func choice<Buttons: View>(title: LocalizedStringKey, text: LocalizedStringKey,
                                       @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack { buttons() }
        }
    }

    /// The kept folders in the Finder; without any, the folder of the library.
    private func showBackups() {
        let kept = LibraryBackup.keptFolders(storeURL: storeURL)
        NSWorkspace.shared.activateFileViewerSelecting(kept.isEmpty ? [storeURL] : kept)
    }

    private func startEmpty() {
        do {
            try LibraryBackup.setAsideDamaged(storeURL: storeURL)
            Self.relaunch()
        } catch {
            problem = String(localized: "The library could not be moved aside: \(error.localizedDescription)")
        }
    }

    /// Opens a new Wattspur with the same arguments and quits this one: the container opens only at the start.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApplication.shared.terminate(nil) }
        }
    }
}

/// Settings and the import window while the library is not open: nothing may be imported into the
/// empty stand-in library, its rides would be lost (B-264).
struct LibraryClosedNote: View {
    var body: some View {
        ContentUnavailableView("The Library Could Not Be Opened", systemImage: "exclamationmark.triangle",
                               description: Text("Choose what to do in the main window of Wattspur."))
            .frame(width: 420, height: 220)
    }
}
