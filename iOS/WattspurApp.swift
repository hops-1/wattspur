import AppIntents
import SwiftData
import SwiftUI
import WattspurKit
import WidgetKit

/// The iPhone app (iOS 0.x, B-204 ff.), design C: the overview with the totals and the last ride,
/// the rides from the Mac, “More” with the folder shared with the Mac, and the GPS recording
/// (docs/BACKLOG.md).
@main
struct WattspurApp: App {
    enum Tab: Hashable { case overview, rides, more }

    @Environment(\.scenePhase) private var scenePhase
    @State private var folder: ImportFolder
    @State private var library: PhoneLibrary
    @State private var sync: PhoneSync
    @State private var recorder: Recorder
    /// What Siri and the shortcuts ask the app to show (B-225).
    @State private var intents: IntentRouter
    @State private var recordings = PhoneRecordings()
    @State private var tab = Tab.overview
    /// Search and filters of the ride list (B-222); the period tiles of the overview set them.
    @State private var rideFilter = RideFilter()
    /// The ride “Open last ride” shows in the list (B-225).
    @State private var openedRideID: UUID?
    /// Why “End and Save” of an unfinished ride failed; the recording and its log stay (R-51).
    @State private var unfinishedProblem: String?
    /// FIT and GPX files opened with Wattspur (B-071).
    @State private var phoneImport = PhoneImport()

    init() {
        // Siri and the shortcuts (B-225) reach the recorder and the app through these two.
        let recorder = Recorder()
        let intents = IntentRouter()
        _recorder = State(initialValue: recorder)
        _intents = State(initialValue: intents)
        AppDependencyManager.shared.add(dependency: recorder)
        AppDependencyManager.shared.add(dependency: intents)
        let folder = ImportFolder()
        _folder = State(initialValue: folder)
        // iCloud only when the build allows it (`WattspurDatabase` in the Info.plist, from
        // Config/iOS.xcconfig or Local.xcconfig) and the user wants it; else the folder of iOS 0.2 (B-218).
        let buildMode = PhoneDatabase.Mode(infoValue: Bundle.main.object(forInfoDictionaryKey: "WattspurDatabase") as? String)
        let sync = PhoneSync(buildMode: buildMode, hadFolder: folder.url != nil, hadStore: PhoneSync.storeExists)
        _sync = State(initialValue: sync)
        let library = sync.makeLibrary(folder: folder)
        #if DEBUG
        if UserDefaults.standard.bool(forKey: PhoneSettingsKey.demoRide) { library.importSampleRideForTesting() }
        #endif
        _library = State(initialValue: library)
    }

    /// Switches between iCloud and the folder at once (B-218).
    private func switchSync(to on: Bool) {
        sync.set(on)
        guard sync.mode != library.mode else { return }
        library.close()
        library = sync.makeLibrary(folder: folder)
        Task { await library.refresh() }
    }

    /// The week for the widget: the same rides as the tiles of the overview (the Mac's rides without
    /// motorcycles, plus the recordings the Mac does not have yet), and the newest ride of all.
    private var weekSnapshot: WeekSnapshot {
        let state = library.state
        let waiting = recordings.waiting
        let rides = (state?.countedRides ?? []).map { (start: $0.startDate, distance: $0.distance) }
            + waiting.filter { state?.isMotorized(bikeID: $0.bikeID) != true }.map { (start: $0.startDate, distance: $0.distance) }
        var last = state?.lastRide.map { WeekSnapshot.LastRide(name: $0.name, start: $0.startDate,
                                                                 distance: $0.distance, timeZone: $0.timeZone) }
        if let recording = waiting.first, recording.startDate > last?.start ?? .distantPast {
            last = WeekSnapshot.LastRide(name: recording.name, start: recording.startDate, distance: recording.distance)
        }
        return WeekSnapshot(rides: rides, lastRide: last)
    }

    var body: some Scene {
        WindowGroup {
            // The library did not open (B-264): the way out instead of the tabs, and nothing that imports or records.
            if let failure = sync.libraryFailure {
                LibraryErrorView(error: failure, storeURL: sync.failedStoreURL) {
                    library = sync.makeLibrary(folder: folder)
                    Task { await library.refresh() }
                }
            } else {
                mainView
            }
        }
    }

    private var mainView: some View {
        TabView(selection: $tab) {
            SwiftUI.Tab("Overview", systemImage: "square.grid.2x2", value: Tab.overview) {
                NavigationStack {
                    OverviewView { period in
                        rideFilter = RideFilter(period: period)
                        tab = .rides
                    }
                        .hidesTabBarInLandscape()
                        .hidesTitleBar()
                }
            }
            SwiftUI.Tab("Rides", systemImage: "list.bullet", value: Tab.rides) {
                NavigationStack {
                    RidesView(filter: $rideFilter, openedRideID: $openedRideID)
                        .hidesTabBarInLandscape()
                        .hidesTitleBar()
                }
            }
            SwiftUI.Tab("More", systemImage: "ellipsis", value: Tab.more) {
                NavigationStack {
                    MoreView()
                        .hidesTabBarInLandscape()
                        .hidesTitleBar()
                }
            }
        }
        // In landscape the tab bar sits at the bottom left, in every tab (B-243).
        .overlay(alignment: .bottomLeading) {
            LandscapeTabBar(tab: $tab)
        }
        .tint(.track)
        // A FIT from the Flow app or a GPX from the Files app, shared to or opened with Wattspur.
        .onOpenURL { url in
            phoneImport.open(url, library: library, folder: folder)
            tab = .rides
        }
        .phoneImport(phoneImport)
        .environment(folder)
        .environment(sync)
        .environment(\.switchSync, SwitchSyncAction(switchSync))
        .reportsSaveFailures()
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
        // Users of the folder way hear once that iCloud is possible now (B-218).
        .alert("Sync with iCloud?", isPresented: Binding(get: { sync.offerPending && !recorder.isRecording },
                                                         set: { if !$0 { sync.offerDone() } })) {
            Button("Use iCloud") { switchSync(to: true) }
            Button("Keep the Folder", role: .cancel) { sync.offerDone() }
        } message: {
            Text("Wattspur on the iPhone can now share one library with the Mac over iCloud: rides recorded here reach the Mac, and you can delete rides here. The Mac must sync with iCloud too (Wattspur › Settings › iCloud). You can switch at any time under More.")
        }
        // The folder exchange ends with 0.6 (B-263, part 1): who still uses it hears it once.
        .alert("The Folder Exchange Ends", isPresented: Binding(get: { sync.folderEndNoticePending && !recorder.isRecording },
                                                                set: { if !$0 { sync.folderEndNoticeDone() } })) {
            if sync.canChoose {
                Button("Use iCloud") {
                    sync.folderEndNoticeDone()
                    switchSync(to: true)
                }
                Button("Later", role: .cancel) { sync.folderEndNoticeDone() }
            } else {
                Button("OK", role: .cancel) { sync.folderEndNoticeDone() }
            }
        } message: {
            Text("From version 0.6, Wattspur on the iPhone no longer exchanges rides with the Mac through a folder. Turn on Sync with iCloud, here under More and on the Mac under Wattspur › Settings › iCloud, to keep one library on both. “Share GPX” stays.")
        }
        // A recording the app could not finish (crash, killed): go on or end it.
        .alert("Unfinished Ride", isPresented: Binding(get: { recorder.unfinished != nil && !recorder.isRecording
                                                              && unfinishedProblem == nil },
                                                       set: { _ in })) {
            // The default answer; it also takes the place of the Cancel button iOS would add.
            Button("Continue Recording", role: .cancel) { recorder.continueUnfinished() }
            Button("End and Save") {
                if let recording = recorder.unfinished, !recording.isTooShort {
                    let bikes = (library.state?.bikes ?? []).filter { !$0.isArchived }
                    let id = SaveRecordingSheet.defaultBike(among: bikes, last: recordings.lastBikeID,
                                                            lastRide: library.state?.lastRide)
                    do {
                        try SaveRecordingSheet.store(recording, name: RecordingView.defaultName(for: recording.startDate),
                                                     bike: bikes.first { $0.id == id }, library: library,
                                                     recordings: recordings, folder: folder)
                    } catch {
                        // Ending now would delete the log and with it the whole ride.
                        unfinishedProblem = error.localizedDescription
                        return
                    }
                }
                _ = recorder.stop()
            }
            Button("Discard", role: .destructive) { _ = recorder.stop() }
        } message: {
            Text("Wattspur was closed while recording. Continue the ride, or end it and save what was recorded?")
        }
        // After it the question above comes again: nothing is lost, the rider can try once more.
        .alert("Ride Not Saved", isPresented: Binding(get: { unfinishedProblem != nil },
                                                      set: { if !$0 { unfinishedProblem = nil } })) {
            Button("OK", role: .cancel) { unfinishedProblem = nil }
        } message: {
            Text("The recording is kept. \(unfinishedProblem ?? "")")
        }
        // “Open last ride” from Siri or a shortcut (B-225): the rides, unfiltered, with the newest open.
        .onChange(of: intents.request, initial: true) { _, request in
            guard let request else { return }
            intents.request = nil
            switch request {
            case .lastRide:
                guard let last = library.state?.lastRide else { tab = .rides; return }
                rideFilter = RideFilter()
                tab = .rides
                openedRideID = last.id
            }
        }
        // The widget “This Week” shows the same week as the overview (B-224).
        .onChange(of: weekSnapshot, initial: true) { _, snapshot in
            if WidgetShare.save(snapshot) {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetShare.weekWidgetKind)
            }
        }
        // While a ride is recorded and the app is in front, the screen stays on; otherwise
        // iOS dims it and locks the phone after the auto-lock time (B-276).
        .onChange(of: recorder.isRecording && scenePhase == .active, initial: true) { _, keepOn in
            UIApplication.shared.isIdleTimerDisabled = keepOn
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

/// Switches between iCloud and the folder (B-218), for the switch in “More”.
struct SwitchSyncAction {
    private let action: (Bool) -> Void
    init(_ action: @escaping (Bool) -> Void) { self.action = action }
    func callAsFunction(_ on: Bool) { action(on) }
}

extension EnvironmentValues {
    @Entry var switchSync = SwitchSyncAction { _ in }
}
