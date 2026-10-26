import SwiftData
import SwiftUI
import WattspurKit

@main
struct WattspurApp: App {
    let container: ModelContainer
    @State private var importLog = ImportLog()
    /// The one library of the app; windows get their own undo manager from it (`RideLibrary.using(_:)`).
    @State private var library: RideLibrary
    @State private var watcher: FolderWatcher
    /// Housekeeping that waits for the first window (see `LibraryMaintenance`).
    @State private var maintenance = LibraryMaintenance()
    /// "New paths" of every ride, for the ride detail and the map (B-115).
    @State private var newPaths = NewPathsStore()
    /// Rides on the route of one ride, for the list "Similar to" (B-118).
    @State private var routeSimilarity = RouteSimilarityStore()
    /// Rides that probably belong together, found after an import (B-096).
    @State private var mergeSuggestions = MergeSuggestionCenter()
    /// The note "rides assigned to a bike" with Undo (B-135).
    @State private var assignmentNotice = BikeAssignmentNotice()
    /// Whether GitHub has a newer version (B-172).
    @State private var updates = UpdateChecker()
    /// "Library Backup…" (P-22).
    @State private var backup = LibraryBackupCenter()
    @Environment(\.openWindow) private var openWindow

    init() {
        // A restore from a backup is swapped in here, before the library opens (P-22). If it fails, the library stays as it was.
        #if DEBUG
        let usesDemo = DemoMode.isOn
        #else
        let usesDemo = false
        #endif
        if !usesDemo { _ = try? LibraryBackup.applyPendingRestore(storeURL: LibraryLocation.storeURL) }
        do {
            #if DEBUG
            container = DemoMode.isOn ? try DemoMode.makeContainer() : try ModelContainer(for: Schema(WattspurSchema.models))
            #else
            container = try ModelContainer(for: Schema(WattspurSchema.models))
            #endif
        } catch {
            fatalError("Could not open the Wattspur library: \(error)")
        }
        // The name of the first bike and of bikes without a name (REQUIREMENTS.md 10.16).
        let library = RideLibrary(context: container.mainContext, defaultBikeName: String(localized: "My eBike"))
        _library = State(initialValue: library)
        _watcher = State(initialValue: FolderWatcher(library: library))
        // Earlier versions created one bike per ride from the export's serial number; they become one.
        library.mergeBikes()
        // One bike named "Mein eBike" for the rider, active, all rides on it (B-074).
        library.prepareBikes()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(importLog)
                .environment(watcher)
                .environment(newPaths)
                .environment(routeSimilarity)
                .environment(mergeSuggestions)
                .environment(assignmentNotice)
                .environment(updates)
                .task { await maintenance.run(library: library) }
        }
        .modelContainer(container)
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Wattspur") { openWindow(id: "about") }
                Button("Check for Updates…") { Task { await updates.checkManually() } }
                    .disabled(updates.isChecking)
            }
            CommandGroup(after: .help) {
                Button("Create Diagnostics…") { openWindow(id: "diagnostics") }
            }
            CommandGroup(after: .importExport) {
                Button("Library Backup…") { openWindow(id: "backup") }
                Button("Import Log") { openWindow(id: "importLog") }
                    .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }

        Window("Import", id: "importLog") {
            ImportLogView()
                .environment(library)
                .environment(importLog)
                .environment(watcher)
                .environment(mergeSuggestions)
        }
        .modelContainer(container)
        .defaultSize(width: 860, height: 700)

        Settings {
            SettingsView()
                .environment(library)
                .environment(watcher)
        }
        .modelContainer(container)

        Window("About Wattspur", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        Window("Library Backup", id: "backup") {
            LibraryBackupView()
                .environment(backup)
        }
        .modelContainer(container)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        Window("Diagnostics", id: "diagnostics") {
            DiagnosticsView()
                .environment(library)
                .environment(importLog)
        }
        .modelContainer(container)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}
