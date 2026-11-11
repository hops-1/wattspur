import SwiftUI
import WattspurCore
import WattspurKit
import WattspurMap

/// One page of “More” (B-298). `embedded` is the page beside the list in landscape, where the
/// navigation bar is hidden: buttons from the bar then sit in the page itself.
struct MorePageView: View {
    let page: MorePage
    var embedded = false

    var body: some View {
        switch page {
        case .profile: ProfilePage()
        case .recording: RecordingPage()
        case .maps: MapsPage()
        case .library: LibraryPage()
        case .trash: TrashView(embedded: embedded)
        case .help: HelpPage()
        case .about: AboutPage()
        case .testTools: TestToolsPage()
        }
    }
}

extension RecordingVehicle {
    var label: LocalizedStringKey {
        switch self {
        case .eBike: "E-Bike"
        case .motorcycle: "Motorcycle"
        }
    }
}

// MARK: - Profile

/// The rider's data (until B-299 brings the full profile): read here, edited on the Mac.
private struct ProfilePage: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    RiderAvatar(rider: library.rider, size: 88)
                    Text(name)
                        .font(.title2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent("Weight") { value(library.rider?.body.weightKg.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " kg" }) }
                LabeledContent("Height") { value(library.rider?.body.heightCm.map { $0.formatted(.number.precision(.fractionLength(0))) + " cm" }) }
                LabeledContent("Year of Birth") { value(library.rider?.body.birthYear.map { String($0) }) }
                LabeledContent("Sex") { Text(sexLabel) }
            } header: {
                Text("For the Calories")
            } footer: {
                Text("You set these on the Mac under Profile; with iCloud they come to this iPhone. Editing them here comes with a later version.")
            }
        }
    }

    private var name: String {
        let name = library.rider?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "No name yet") : name
    }

    private func value(_ text: String?) -> Text {
        text.map { Text($0) } ?? Text("Not set")
    }

    private var sexLabel: LocalizedStringKey {
        switch library.rider?.body.sex ?? .unspecified {
        case .male: "Male"
        case .female: "Female"
        case .unspecified: "Not specified"
        }
    }
}

// MARK: - Recording

private struct RecordingPage: View {
    @AppStorage(Recorder.vehicleKey) private var vehicle = RecordingVehicle.eBike

    var body: some View {
        Form {
            Section {
                Picker("Vehicle", selection: $vehicle) {
                    ForEach(RecordingVehicle.allCases) { Text($0.label).tag($0) }
                }
            } footer: {
                Text("GPS jumps look like impossible speeds and are left out. For an e-bike that is above 100 km/h, for a motorcycle above 300 km/h.")
            }
        }
    }
}

// MARK: - Maps

private struct MapsPage: View {
    /// The style of every map (B-226), the same choice as on the detail map.
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard

    var body: some View {
        Form {
            Section {
                Picker("Map Style", selection: $mapType) {
                    Section("Apple") {
                        ForEach(RideMapType.apple) { Text($0.label).tag($0) }
                    }
                    Section("OpenStreetMap") {
                        ForEach(RideMapType.openStreetMapStyles) { Text($0.label).tag($0) }
                    }
                }
            } footer: {
                Text("The OpenStreetMap styles come from volunteer servers; Wattspur loads only the tiles on screen and keeps them for a while. Without a connection the route shows on a plain ground.")
            }
        }
    }
}

// MARK: - iCloud & Library

/// iCloud on or off, where the rides are and the state of the sync.
private struct LibraryPage: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneImport.self) private var phoneImport
    @Environment(PhoneSync.self) private var sync
    @Environment(\.switchSync) private var switchSync
    @State private var confirmingOff = false

    var body: some View {
        Form {
            if sync.canChoose {
                Section {
                    Toggle("Sync with iCloud", isOn: Binding(
                        get: { sync.isOn },
                        set: { if $0 { switchSync(true) } else { confirmingOff = true } }))
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if sync.isOn {
                            Text("One library on this iPhone and your Mac, in your own iCloud account.")
                        } else {
                            Text("Without iCloud, the rides stay on this iPhone. They reach the Mac with “Share GPX”, e.g. by AirDrop.")
                        }
                        if sync.needsRestart {
                            Text("Takes effect the next time Wattspur opens: close it in the app switcher.")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .confirmationDialog("Stop syncing with iCloud?", isPresented: $confirmingOff, titleVisibility: .visible) {
                    Button("Turn Off") { switchSync(false) }
                } message: {
                    Text("The rides stay in iCloud, on your Mac and on this iPhone. New rides then stay on this iPhone.")
                }
            }
            if let monitor = library.syncMonitor {
                SyncSection(monitor: monitor)
            }
            Section {
                Button {
                    phoneImport.choosingFiles = true
                } label: {
                    Label("Import Files …", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("FIT and GPX files, several at once, also from iCloud Drive. Files you put into “On My iPhone › Wattspur › Import” in the Files app are imported when Wattspur opens; then they move to “Importiert”, or to “Fehler” if they cannot be read.")
            }
            Section {
                LabeledContent("Rides") { Text((library.state?.rides.count ?? 0).formatted()) }
            } header: {
                Text("Library")
            } footer: {
                if library.mode == .iCloud {
                    Text("Your rides are on this iPhone and in your own iCloud account, the same as on your Mac.")
                } else {
                    Text("Your rides are on this iPhone. Sync with the Mac comes with iCloud.")
                }
            }
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

// MARK: - Help & Handbook

/// Links to the handbook online, in the language of the app (as in the Mac's Help menu).
private struct HelpPage: View {
    var body: some View {
        Form {
            Section {
                Link(destination: HelpLinks.url(.iPhone)) {
                    Label("Wattspur on the iPhone", systemImage: "iphone")
                }
                Link(destination: HelpLinks.url(.handbook)) {
                    Label("Handbook", systemImage: "book")
                }
                Link(destination: HelpLinks.url(.faq)) {
                    Label("Questions and Answers", systemImage: "questionmark.circle")
                }
            } footer: {
                Text("The handbook is online, so it can get better between versions.")
            }
            Section {
                Link(destination: HelpLinks.releases) {
                    Label("What's New", systemImage: "sparkles")
                }
            }
        }
    }
}

// MARK: - About

/// The version, where the maps come from and the privacy policy.
private struct AboutPage: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text("\(AppInfo.version) (\(AppInfo.build))")
                        .textSelection(.enabled)
                }
                LabeledContent("Commit") {
                    Text(AppInfo.commit)
                        .textSelection(.enabled)
                }
            }
            Section {
                LabeledContent("Apple") { Text("Standard, Satellite, Hybrid") }
                ForEach(TileSource.all) { source in
                    Link(destination: source.attributionURL) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                                .foregroundStyle(.primary)
                            Text(source.attribution)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Map Sources")
            } footer: {
                Text("Apple shows its credit on the map itself.")
            }
            Section {
                Link(destination: HelpLinks.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            } footer: {
                Text("Wattspur has no server and no account. Your rides stay on your devices and in your own iCloud.")
            }
        }
    }
}

// MARK: - Test tools

/// Only in Debug and TestFlight builds (`BuildChannel`).
private struct TestToolsPage: View {
    @AppStorage(MotionRecorder.rawLogKey) private var recordsRawMotion = false

    var body: some View {
        Form {
            // Spike V-16; goes again once acceleration and lean angle are part of the recording.
            Section {
                Toggle("Record Raw Motion", isOn: $recordsRawMotion)
            } footer: {
                Text("For a test of acceleration and lean angle: each recording also writes the motion sensors and GPS into a file. You find it in the Files app under “On My iPhone › Wattspur › Bewegung”. About 20 MB per hour.")
            }
        }
    }
}
