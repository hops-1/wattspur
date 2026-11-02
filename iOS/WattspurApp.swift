import SwiftData
import SwiftUI
import WattspurKit

/// The iPhone app (iOS 0.x, B-204 ff.), design C: the overview with the totals and the last ride,
/// the rides from the Mac, “More” with the folder shared with the Mac, and the GPS recording
/// (docs/BACKLOG.md).
@main
struct WattspurApp: App {
    enum Tab: Hashable { case overview, rides, more }

    @Environment(\.scenePhase) private var scenePhase
    @State private var folder: ImportFolder
    @State private var library: PhoneLibrary
    @State private var recorder = Recorder()
    @State private var recordings = PhoneRecordings()
    @State private var tab = Tab.overview

    init() {
        let folder = ImportFolder()
        _folder = State(initialValue: folder)
        // The iPhone's own store (B-216) only when the build asks for it (`WattspurDatabase` in the
        // Info.plist, from Config/iOS.xcconfig or Local.xcconfig); else the folder of iOS 0.2.
        let mode = PhoneDatabase.Mode(infoValue: Bundle.main.object(forInfoDictionaryKey: "WattspurDatabase") as? String)
        var database: PhoneDatabase?
        if let configuration = mode.configuration {
            do {
                let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: configuration)
                database = PhoneDatabase(container: container, defaultBikeName: String(localized: "My eBike"))
                database?.purgeTrash()
            } catch {
                fatalError("Could not open the Wattspur library: \(error)")
            }
        }
        _library = State(initialValue: PhoneLibrary(folder: folder, database: database, mode: mode))
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                SwiftUI.Tab("Overview", systemImage: "square.grid.2x2", value: Tab.overview) {
                    NavigationStack {
                        OverviewView { tab = .rides }
                    }
                }
                SwiftUI.Tab("Rides", systemImage: "list.bullet", value: Tab.rides) {
                    NavigationStack {
                        RidesView()
                    }
                }
                SwiftUI.Tab("More", systemImage: "ellipsis", value: Tab.more) {
                    NavigationStack {
                        MoreView()
                    }
                }
            }
            .tint(.track)
            .environment(folder)
            .environment(library)
            .environment(recorder)
            .environment(recordings)
            // The recording covers everything while it runs (B-211).
            .fullScreenCover(isPresented: Binding(get: { recorder.isRecording }, set: { _ in })) {
                RecordingView()
                    .environment(folder)
                    .environment(library)
                    .environment(recorder)
                    .environment(recordings)
            }
            // A recording the app could not finish (crash, killed): go on or end it.
            .alert("Unfinished Ride", isPresented: Binding(get: { recorder.unfinished != nil && !recorder.isRecording },
                                                           set: { _ in })) {
                // The default answer; it also takes the place of the Cancel button iOS would add.
                Button("Continue Recording", role: .cancel) { recorder.continueUnfinished() }
                Button("End and Save") {
                    if let recording = recorder.unfinished, !recording.isTooShort {
                        let bikes = (library.state?.bikes ?? []).filter { !$0.isArchived }
                        let id = SaveRecordingSheet.defaultBike(among: bikes, last: recordings.lastBikeID,
                                                                lastRide: library.state?.lastRide)
                        try? SaveRecordingSheet.store(recording, name: RecordingView.defaultName(for: recording.startDate),
                                                      bike: bikes.first { $0.id == id }, library: library,
                                                      recordings: recordings, folder: folder)
                    }
                    _ = recorder.stop()
                }
                Button("Discard", role: .destructive) { _ = recorder.stop() }
            } message: {
                Text("Wattspur was closed while recording. Continue the ride, or end it and save what was recorded?")
            }
            // The Mac may have written a new state while the app was in the background.
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    Task {
                        await library.refresh()
                        await recordings.refreshStatuses(state: library.state, folder: folder)
                    }
                }
            }
        }
    }
}
