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
    /// "New paths" of every ride, for the ride detail and the map (B-115).
    @State private var newPaths = NewPathsStore()
    /// Rides that probably belong together, found after an import (B-096).
    @State private var mergeSuggestions = MergeSuggestionCenter()
    /// The note "rides assigned to a bike" with Undo (B-135).
    @State private var assignmentNotice = BikeAssignmentNotice()
    @Environment(\.openWindow) private var openWindow

    init() {
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
        // Rides in the trash for more than 30 days are deleted for good (LIST-08).
        library.purgeTrash()
        // Rides imported with an older parser are re-read from their original file (NFR-17).
        library.reparseOutdatedRides()
        // The import log is a help, not an archive (IMP-06).
        library.trimImportLog()
        _watcher = State(initialValue: FolderWatcher(library: library))
        // Earlier versions created one bike per ride from the export's serial number; they become one.
        library.mergeBikes()
        // One bike named "Mein eBike" for the rider, active, all rides on it (B-074).
        library.prepareBikes()
        // Rides imported before v1.4 get their simplified route for the map, in the background (B-104).
        Task { [container] in
            await RideLibrary(context: container.mainContext).prepareOverviewRoutes()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(importLog)
                .environment(watcher)
                .environment(newPaths)
                .environment(mergeSuggestions)
                .environment(assignmentNotice)
        }
        .modelContainer(container)
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Wattspur") { openWindow(id: "about") }
            }
            CommandGroup(after: .help) {
                Button("Create Diagnostics…") { openWindow(id: "diagnostics") }
            }
            CommandGroup(after: .importExport) {
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
