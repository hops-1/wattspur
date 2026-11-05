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
    /// The state for the iPhone in the import folder (B-208).
    @State private var phoneState: PhoneState
    /// Housekeeping that waits for the first window (see `LibraryMaintenance`).
    @State private var maintenance = LibraryMaintenance()
    /// "New paths" of every ride, for the ride detail and the map (B-115).
    @State private var newPaths = NewPathsStore()
    /// Imported curvy roads for the layer on the maps (B-182, B-183).
    @State private var curvyRoads = CurvyRoadsStore()
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
    /// "Sync with iCloud" (B-072), read once: the library opens with or without sync.
    @State private var iCloudSync: ICloudSync
    /// The note after a restore, shown by the first window (P-22).
    @State private var restoreNotice = LibraryRestoreNotice()
    /// Merges what the iPhone and the Mac made twice, while the library syncs (B-216); `nil` without sync.
    @State private var syncMerge: SyncMergeWatcher?
    @Environment(\.openWindow) private var openWindow

    init() {
        // A restore from a backup is swapped in here, before the library opens (P-22). If it fails, the library stays as it was.
        #if DEBUG
        // `-WattspurInitCloudKitSchema YES`: complete the schema in Development before the deploy, then quit (B-219).
        if UserDefaults.standard.bool(forKey: "WattspurInitCloudKitSchema") {
            let folder = FileManager.default.temporaryDirectory.appending(path: "WattspurSchema")
            do {
                try LibrarySync.initializeCloudKitSchema(scratchFolder: folder)
                print("Wattspur: CloudKit schema initialized in Development")
                exit(0)
            } catch {
                print("Wattspur: CloudKit schema failed: \(error)")
                exit(1)
            }
        }
        // `-WattspurMeasureCloudKit YES`: list what the mirror keeps in iCloud per record type, then quit.
        if UserDefaults.standard.bool(forKey: "WattspurMeasureCloudKit") {
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    let zones = try await LibrarySync.measureCloudKitUsage { print("Wattspur: \($0)") }
                    for (zone, types) in zones.sorted(by: { $0.key < $1.key }) {
                        print("ZONE \(zone)")
                        for (type, usage) in types.sorted(by: { $0.key < $1.key }) {
                            let assets = usage.assetBytes.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                            print("TYPE \(type) records=\(usage.records) fieldBytes=\(usage.fieldBytes) assets=\(usage.assetCount) assetBytes=\(usage.totalAssetBytes) \(assets)")
                        }
                    }
                    exit(0)
                } catch {
                    print("Wattspur: CloudKit measuring failed: \(error)")
                    exit(1)
                }
            }
            done.wait()
        }
        let usesDemo = DemoMode.isOn
        if SpikeLibrary.isOn && !usesDemo { SpikeLibrary.prepare() }
        #else
        let usesDemo = false
        #endif
        let notice = LibraryRestoreNotice()
        if !usesDemo {
            let storeURL = LibraryLocation.storeURL
            let manifest = LibraryBackup.pendingManifest(storeURL: storeURL)
            if let restored = try? LibraryBackup.applyPendingRestore(storeURL: storeURL), restored != nil, let manifest {
                notice.show(backupDate: manifest.createdAt)
            }
        }
        _restoreNotice = State(initialValue: notice)
        #if DEBUG
        let sync = SpikeLibrary.isOn ? ICloudSync(defaults: SpikeLibrary.defaults) : ICloudSync()
        #else
        let sync = ICloudSync()
        #endif
        _iCloudSync = State(initialValue: sync)
        do {
            #if DEBUG
            container = DemoMode.isOn ? try DemoMode.makeContainer() : try ModelContainer(for: Schema(WattspurSchema.models), configurations: sync.configuration)
            #else
            container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: sync.configuration)
            #endif
        } catch {
            fatalError("Could not open the Wattspur library: \(error)")
        }
        // The name of the first bike and of bikes without a name (REQUIREMENTS.md 10.16).
        let library = RideLibrary(context: container.mainContext, defaultBikeName: String(localized: "My eBike"))
        _library = State(initialValue: library)
        let watcher = FolderWatcher(library: library)
        _watcher = State(initialValue: watcher)
        _phoneState = State(initialValue: PhoneState(context: container.mainContext, watcher: watcher))
        // Earlier versions created one bike per ride from the export's serial number; they become one.
        library.mergeBikes()
        // One bike named "Mein eBike" for the rider, active, all rides on it (B-074).
        library.prepareBikes()
        // With iCloud, each device makes its own rider and "My eBike"; after the sync they become one (B-216).
        if sync.isActive && !usesDemo {
            let syncMerge = SyncMergeWatcher(library: library)
            syncMerge.start()
            _syncMerge = State(initialValue: syncMerge)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(importLog)
                .environment(watcher)
                .environment(newPaths)
                .environment(curvyRoads)
                .environment(routeSimilarity)
                .environment(mergeSuggestions)
                .environment(assignmentNotice)
                .environment(updates)
                .environment(restoreNotice)
                .environment(\.librarySyncs, iCloudSync.isActive)
                .task { await maintenance.run(library: library) }
                .task { await curvyRoads.load() }
        }
        .modelContainer(container)
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Wattspur") { openWindow(id: "about") }
                Button("Check for Updates…") { Task { await updates.checkManually() } }
                    .disabled(updates.isChecking)
            }
            CommandGroup(replacing: .help) {
                Link("Wattspur Handbook", destination: HelpLinks.url(.handbook))
                    .keyboardShortcut("?", modifiers: .command)
                Link("Importing Rides", destination: HelpLinks.url(.importing))
                Link("Questions and Troubleshooting", destination: HelpLinks.url(.faq))
                Link("Release Notes", destination: HelpLinks.releases)
                Divider()
                Button("Create Diagnostics…") { openWindow(id: "diagnostics") }
            }
            CommandGroup(after: .importExport) {
                Button("Import Curvy Roads…") { curvyRoads.chooseFiles() }
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
                .environment(phoneState)
                .environment(curvyRoads)
                .environment(iCloudSync)
                .environment(\.librarySyncs, iCloudSync.isActive)
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
