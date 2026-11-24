import AppIntents
import SwiftData
import SwiftUI
import UserNotifications
import WattspurKit
import WattspurMap
import WidgetKit

/// The iPhone app (iOS 0.x, B-204 ff.), design C: the overview with the totals and the last ride,
/// the rides, “More” with iCloud and the trash, and the GPS recording (docs/BACKLOG.md).
@main
struct WattspurApp: App {
    enum Tab: Hashable { case overview, rides, map, more }

    @Environment(\.scenePhase) private var scenePhase
    @State private var library: PhoneLibrary
    @State private var sync: PhoneSync
    @State private var recorder: Recorder
    /// What Siri and the shortcuts ask the app to show (B-225).
    @State private var intents: IntentRouter
    @State private var tab = Tab.overview
    /// Search and filters of the ride list (B-222); the period tiles of the overview set them.
    @State private var rideFilter = RideFilter()
    /// The ride “Open last ride” shows in the list (B-225).
    @State private var openedRideID: UUID?
    /// Why “End and Save” of an unfinished ride failed; the recording and its log stay (R-51).
    @State private var unfinishedProblem: String?
    /// FIT and GPX files opened with Wattspur (B-071), chosen in the file picker or put into the folder “Import” (B-300).
    @State private var phoneImport = PhoneImport()
    /// Back up and restore (B-302).
    @State private var backup = PhoneBackup()
    /// What happened to a backup staged for this start (B-302).
    @State private var launchRestore: PhoneBackup.LaunchResult?
    /// Whether the recording covers the screen; until then the tabs stay, so its cover slides in
    /// over them (B-382).
    @State private var recordingCovers = false

    /// Kept here: the notification center holds its delegate weakly.
    private static var notifications: NotificationRouter?

    init() {
        // Siri and the shortcuts (B-225) reach the recorder and the app through these two.
        let recorder = Recorder()
        let intents = IntentRouter()
        _recorder = State(initialValue: recorder)
        _intents = State(initialValue: intents)
        AppDependencyManager.shared.add(dependency: recorder)
        AppDependencyManager.shared.add(dependency: intents)
        // CarPlay (B-327) drives the same recorder.
        CarPlaySceneDelegate.recorder = recorder
        // iCloud only when the build allows it (`WattspurDatabase` in the Info.plist, from
        // Config/iOS.xcconfig or Local.xcconfig) and the user wants it; else the store without sync (B-218).
        let buildMode = PhoneDatabase.Mode(infoValue: Bundle.main.object(forInfoDictionaryKey: "WattspurDatabase") as? String)
        let sync = PhoneSync(buildMode: buildMode, hadFolder: PhoneSync.hadFolder(), hadStore: PhoneSync.storeExists)
        _sync = State(initialValue: sync)
        // A backup chosen under More is swapped in now, before the store opens (B-302).
        _launchRestore = State(initialValue: PhoneBackup.applyAtLaunch(syncOn: sync.mode == .iCloud))
        let library = sync.makeLibrary()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: PhoneSettingsKey.demoRide) { library.importSampleRideForTesting() }
        library.importDemoCopiesForTesting(UserDefaults.standard.integer(forKey: "WattspurDemoRides"))
        // For the App Store screenshots (B-315, scripts/appstore-screenshots.sh): recent rides, a tab,
        // the newest ride open, or a recording running from the start.
        library.importRecentDemoRidesForTesting(UserDefaults.standard.integer(forKey: "WattspurDemoRecent"))
        if UserDefaults.standard.bool(forKey: "WattspurDemoCar") { library.addDemoCarForTesting() }
        switch UserDefaults.standard.string(forKey: "WattspurDemoTab") {
        case "rides": _tab = State(initialValue: .rides)
        case "map": _tab = State(initialValue: .map)
        case "more": _tab = State(initialValue: .more)
        default: break
        }
        if UserDefaults.standard.bool(forKey: "WattspurDemoOpenLast") { intents.request = .lastRide }
        if UserDefaults.standard.bool(forKey: "WattspurDemoRecord") {
            // `-WattspurDemoRecordKind car`: a car without a device, to see the lateral bar (B-320).
            let kind = UserDefaults.standard.string(forKey: "WattspurDemoRecordKind").flatMap(BikeKind.init(rawValue:))
            // `-WattspurDemoReady YES`: as an auto-start, waiting for the vehicle to move (B-311).
            let ready = UserDefaults.standard.bool(forKey: "WattspurDemoReady")
            Task { @MainActor in recorder.start(device: kind.map(RecordingDevice.without), ready: ready) }
        }
        // `-WattspurOfflineTiles YES`: the OpenStreetMap tiles fail as without a network (B-226).
        if UserDefaults.standard.bool(forKey: "WattspurOfflineTiles") { TileLoader.simulatesOffline = true }
        #endif
        _library = State(initialValue: library)
        // An auto-started ride that ends by itself is saved here, where the library is (B-339).
        recorder.autoSave = { recording, name in
            let bikes = (library.state?.bikes ?? []).filter { !$0.isArchived }
            let device = SaveRecordingSheet.defaultDevice(for: recording, among: bikes, lastRide: library.state?.lastRide)
            return (try? SaveRecordingSheet.store(recording, name: name, device: device, library: library)) != nil
        }
        // A tap on “Ride Saved” opens the ride (B-339).
        Self.notifications = NotificationRouter(intents: intents)
        UNUserNotificationCenter.current().delegate = Self.notifications
    }

    /// Switches iCloud on or off (B-218); before the store is open, at once.
    private func switchSync(to on: Bool) {
        sync.set(on)
        guard sync.mode != library.mode else { return }
        library.close()
        library = sync.makeLibrary()
        Task { await library.refresh() }
    }

    /// The week for the widget, per sport (B-289): the same rides as the tiles of the overview for
    /// that sport, and its newest ride. The widget shows cycling unless it is set to another sport.
    private var weekSnapshots: [Sport: WeekSnapshot] {
        Dictionary(uniqueKeysWithValues: [Sport.cycling, .vehicle].map { sport in
            let rides = library.state?.only(sport).rides ?? []
            let last = rides.max { $0.startDate < $1.startDate }
                .map { WeekSnapshot.LastRide(name: $0.name, start: $0.startDate, distance: $0.distance, timeZone: $0.timeZone) }
            return (sport, WeekSnapshot(rides: rides.map { (start: $0.startDate, distance: $0.distance) }, lastRide: last))
        })
    }

    var body: some Scene {
        WindowGroup {
            // The library did not open (B-264): the way out instead of the tabs, and nothing that imports or records.
            if let failure = sync.libraryFailure {
                LibraryErrorView(error: failure, storeURL: sync.failedStoreURL) {
                    library = sync.makeLibrary()
                    Task { await library.refresh() }
                }
            } else {
                mainView
            }
        }
    }

    /// The iPhone's four tabs; also the iPad in a narrow window.
    private var tabs: some View {
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
            // The map of all rides (B-227), as on the Mac.
            SwiftUI.Tab("Map", systemImage: "map", value: Tab.map) {
                NavigationStack {
                    RidesMapScreen()
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
    }

    private var mainView: some View {
        Group {
            // Under the recording nothing is built (B-382): every map of the tabs (overview, map,
            // an open ride) cost about 50 MB, and iOS ends the app that holds the most when the
            // camera needs memory (B-380). When the ride ends the tabs come back on the same tab,
            // without the pages that were open.
            if recorder.isRecording && recordingCovers {
                Color(.systemBackground).ignoresSafeArea()
            } else {
                // On an iPad in the regular width a sidebar instead of the tabs (B-292).
                RootLayout {
                    tabs
                } pad: {
                    PadRootView(tab: $tab, rideFilter: $rideFilter, openedRideID: $openedRideID)
                }
            }
        }
        .tint(.track)
        // A FIT from the Flow app or a GPX from the Files app, shared to or opened with Wattspur; or
        // `wattspur://import` from the share extension, whose files wait in the App Group (B-301).
        .onOpenURL { url in
            // A tap on the Live Activity (B-379): the app comes to the front, nothing else.
            if RecordingLink.isRecordingURL(url) { return }
            if SharedImports.isOpenURL(url) {
                if !recorder.isRecording { phoneImport.importWaitingFiles(library: library) }
            } else {
                phoneImport.open(url, library: library)
            }
            tab = .rides
        }
        .phoneImport(phoneImport)
        .environment(phoneImport)
        .environment(backup)
        .environment(sync)
        .environment(\.switchSync, SwitchSyncAction(switchSync))
        .reportsSaveFailures()
        .environment(library)
        .environment(recorder)
        // A start from Siri or a shortcut takes the next device of this library (B-286); again when
        // the library changes with the iCloud switch.
        .task(id: ObjectIdentifier(library)) {
            recorder.nextDevice = { [library] in library.nextRecordingDevice }
        }
        // While a ride is recorded the library is not read again; once at the end (B-380).
        .onChange(of: HoldKey(recording: recorder.isRecording, library: ObjectIdentifier(library)), initial: true) { _, key in
            library.holdReloads(key.recording)
        }
        // The recording covers everything while it runs (B-211).
        .fullScreenCover(isPresented: Binding(get: { recorder.isRecording }, set: { _ in })) {
            RecordingView()
                .environment(library)
                .environment(recorder)
                .onAppear { recordingCovers = true }
                .onDisappear { recordingCovers = false }
        }
        // The folder exchange ended with 0.6 (B-263): who still used it hears it once, with the way to iCloud.
        .alert("The Folder Exchange Has Ended", isPresented: Binding(get: { sync.folderGoneNoticePending && !recorder.isRecording },
                                                                     set: { if !$0 { sync.folderGoneNoticeDone() } })) {
            if sync.canChoose && !sync.isOn {
                Button("Use iCloud") {
                    sync.folderGoneNoticeDone()
                    switchSync(to: true)
                }
                Button("Later", role: .cancel) { sync.folderGoneNoticeDone() }
            } else {
                Button("OK", role: .cancel) { sync.folderGoneNoticeDone() }
            }
        } message: {
            DeviceText.text("Wattspur on the iPhone no longer reads rides from a folder. Your rides are on your Mac: turn on Sync with iCloud, here under More and on the Mac under Wattspur › Settings › iCloud, and they come to this iPhone. Rides recorded here stay on this iPhone until then; “Share GPX” takes one to the Mac.", pad: "Wattspur no longer reads rides from a folder. Your rides are on your Mac: turn on Sync with iCloud, here under Settings and on the Mac under Wattspur › Settings › iCloud, and they come to this iPad.")
        }
        // The start after “Restore Backup …” (B-302).
        .alert(launchRestoreTitle, isPresented: Binding(get: { launchRestore != nil && !recorder.isRecording },
                                                        set: { if !$0 { launchRestore = nil } })) {
            Button("OK", role: .cancel) { launchRestore = nil }
        } message: {
            Text(launchRestoreMessage)
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
                    let device = SaveRecordingSheet.defaultDevice(for: recording, among: bikes, lastRide: library.state?.lastRide)
                    do {
                        try SaveRecordingSheet.store(recording, name: RecordingView.defaultName(for: recording.startDate),
                                                     device: device, library: library)
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
        .onChange(of: weekSnapshots, initial: true) { _, snapshots in
            let changed = snapshots.filter { WidgetShare.save($0.value, for: $0.key) }
            if !changed.isEmpty {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetShare.weekWidgetKind)
            }
        }
        // While a ride is recorded and the app is in front, the screen stays on; otherwise
        // iOS dims it and locks the phone after the auto-lock time (B-276).
        .onChange(of: recorder.isRecording && scenePhase == .active, initial: true) { _, keepOn in
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
        // iCloud may have brought changes while the app was in the background.
        .onChange(of: scenePhase, initial: true) { _, phase in
            // A few seconds of background time, so the store finishes writing before iOS suspends
            // the app; suspended with a lock on it, the app would be ended (0xdead10cc, B-366).
            if phase == .background { LibraryWriteHold.linger() }
            if phase == .active {
                Task { await library.refresh() }
                // Files put into “On My iPhone › Wattspur › Import” meanwhile (B-300); not while recording.
                if !recorder.isRecording { phoneImport.importWaitingFiles(library: library) }
                // The weekly backup, when switched on (B-302); not while recording or with a damaged library.
                if !recorder.isRecording, sync.libraryFailure == nil {
                    backup.backUpAutomaticallyIfDue(rideCount: library.state?.rides.count)
                }
            }
        }
    }
}

extension WattspurApp {
    private var launchRestoreTitle: LocalizedStringKey {
        if case .failed = launchRestore { return "Backup Not Restored" }
        return "Backup Restored"
    }

    private var launchRestoreMessage: String {
        switch launchRestore {
        case .restored(let date, let synced):
            String(localized: "The library is now the backup from \(date.formatted(date: .long, time: .shortened)). The library before it is kept in a folder “Library Before Restore …”.")
                + (synced ? " " + String(localized: "iCloud now brings your other devices to the same state; give it a few minutes.") : "")
        case .failed(let message):
            message
        case nil:
            ""
        }
    }
}

/// Whether a ride is recorded, per library: a new library after the iCloud switch gets the hold
/// too (B-380).
private struct HoldKey: Equatable {
    let recording: Bool
    let library: ObjectIdentifier
}

/// Switches iCloud on or off (B-218), for the switch in “More”.
struct SwitchSyncAction {
    private let action: (Bool) -> Void
    init(_ action: @escaping (Bool) -> Void) { self.action = action }
    func callAsFunction(_ on: Bool) { action(on) }
}

extension EnvironmentValues {
    @Entry var switchSync = SwitchSyncAction { _ in }
}
