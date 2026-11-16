import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
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
        case .car: "Car"
        }
    }
}

// MARK: - Profile

/// The profile (B-299): the rider with the data for the calories, edited here or on the Mac (the
/// same rider over iCloud); the totals and records of each sport; the devices by sport, each opens.
private struct ProfilePage: View {
    @Environment(PhoneLibrary.self) private var library
    @State private var editing = false

    private var totals: [SportTotals] { library.state?.sportTotals() ?? [SportTotals(sport: .cycling, rides: [])] }
    private var devices: [(sport: Sport, devices: [RideExchange.Bike])] { library.state?.devicesBySport() ?? [] }

    var body: some View {
        List {
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
                LabeledContent("Sex") { Text(library.rider?.body.sex.label ?? RiderSex.unspecified.label) }
            } header: {
                Text("For the Calories")
            } footer: {
                Text("With iCloud the Mac shows the same profile.")
            }
            ForEach(totals) { sport in
                Section {
                    SportTotalsGrid(totals: sport)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Label { Text(sport.sport.totalsTitle) } icon: { Image(systemName: sport.sport.symbol) }
                }
            }
            ForEach(devices, id: \.sport) { group in
                Section {
                    ForEach(group.devices) { device in
                        NavigationLink {
                            DevicePage(device: device)
                        } label: {
                            DeviceRow(device: device, usage: library.state?.usage(of: device.id) ?? (0, 0))
                        }
                    }
                } header: {
                    Text(group.sport.devicesTitle)
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            Button("Edit") { editing = true }
                .disabled(library.database == nil)
        }
        .sheet(isPresented: $editing) {
            ProfileEditor(details: library.rider ?? RiderDetails()) { library.updateRider($0) }
        }
    }

    private var name: String {
        let name = library.rider?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "No name yet") : name
    }

    private func value(_ text: String?) -> Text {
        text.map { Text($0) } ?? Text("Not set")
    }
}

extension RiderSex {
    var label: LocalizedStringKey {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .unspecified: "Not specified"
        }
    }
}

extension Sport {
    /// The title over the totals of the sport in the profile (B-299).
    var totalsTitle: LocalizedStringKey {
        switch self {
        case .cycling: "Cycling"
        case .vehicle: "Vehicles"
        case .running: "Running"
        }
    }

    /// The title over the devices of the sport.
    var devicesTitle: LocalizedStringKey {
        switch self {
        case .cycling: "Bikes"
        case .vehicle: "Vehicles"
        case .running: "Shoes"
        }
    }

    var symbol: String {
        switch self {
        case .cycling: "bicycle"
        case .vehicle: "car"
        case .running: "figure.run"
        }
    }
}

extension BikeKind {
    /// The kind's name, as in the Mac's profile.
    var label: LocalizedStringKey {
        switch self {
        case .bike: "Bicycle"
        case .mountain: "Mountain bike"
        case .road: "Road bike"
        case .gravel: "Gravel bike"
        case .cargo: "Cargo bike"
        case .motorcycle: "Motorcycle"
        case .car: "Car"
        case .runningShoe: "Running shoes"
        }
    }
}

/// The totals and records of one sport as small tiles (B-299).
private struct SportTotalsGrid: View {
    var totals: SportTotals

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            tile("Distance", RideFormat.distance(totals.distance), "road.lanes")
            tile("Rides", totals.rides.formatted(), "number")
            tile("Ride Time", RideFormat.duration(totals.rideTime), "clock")
            tile("Longest Ride", totals.longest.map { RideFormat.distance($0.value) } ?? "–", "arrow.left.and.right")
            tile("Top Speed", totals.fastest.map { RideFormat.speed($0.value) } ?? "–", "speedometer")
        }
    }

    private func tile(_ title: LocalizedStringKey, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// A device in the profile: symbol, name, kind and what was ridden on it.
private struct DeviceRow: View {
    var device: RideExchange.Bike
    var usage: (rides: Int, distance: Double)

    var body: some View {
        HStack(spacing: 12) {
            BikeBadge(bike: device)
                .font(.title3)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                Text(kind.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: RideFormat.distance(usage.distance))
                    .monospacedDigit()
                if device.isArchived {
                    Text("Archived").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var kind: BikeKind { BikeKind(rawValue: device.kind) ?? .bike }
}

/// One device, opened from the profile (B-299); editing on the iPhone comes with B-290.
private struct DevicePage: View {
    @Environment(PhoneLibrary.self) private var library
    var device: RideExchange.Bike

    private var kind: BikeKind { BikeKind(rawValue: device.kind) ?? .bike }

    var body: some View {
        let usage = library.state?.usage(of: device.id) ?? (0, 0)
        Form {
            Section {
                VStack(spacing: 8) {
                    BikeBadge(bike: device)
                        .font(.system(size: 44))
                    Text(device.name)
                        .font(.title2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                LabeledContent("Kind") { Text(kind.label) }
                if kind.sport == .cycling {
                    LabeledContent("E-Bike") { Text(device.isEbike ? LocalizedStringKey("Yes") : LocalizedStringKey("No")) }
                }
                LabeledContent("Rides") { Text(usage.rides.formatted()) }
                LabeledContent("Distance") { Text(verbatim: RideFormat.distance(usage.distance)) }
                if device.isArchived {
                    LabeledContent("Status") { Text("Archived") }
                }
            } footer: {
                Text("You change devices on the Mac under Profile; with iCloud they come to this iPhone.")
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Edits the rider (B-299): name, photo and the data for the calories. Numbers out of range are
/// not saved, as on the Mac (`ProfileInput`).
private struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var details: RiderDetails
    @State private var weight: Double?
    @State private var height: Double?
    @State private var photoItem: PhotosPickerItem?
    let save: (RiderDetails) -> Void

    init(details: RiderDetails, save: @escaping (RiderDetails) -> Void) {
        _details = State(initialValue: details)
        _weight = State(initialValue: details.body.weightKg)
        _height = State(initialValue: details.body.heightCm)
        self.save = save
    }

    /// Longer edge of the stored photo in pixels, as on the Mac.
    static let photoEdge = 1000

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            RiderAvatar(rider: details, size: 88)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.multicolor)
                                }
                        }
                        .accessibilityLabel(Text("Choose Photo"))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    if details.photoData != nil {
                        Button("Remove Photo", role: .destructive) { details.photoData = nil }
                    }
                    TextField("Name", text: $details.name)
                        .textContentType(.name)
                }
                Section {
                    TextField("Weight", value: $weight, format: .number.precision(.fractionLength(0...1)), prompt: Text("kg"))
                        .keyboardType(.decimalPad)
                    TextField("Height", value: $height, format: .number.precision(.fractionLength(0)), prompt: Text("cm"))
                        .keyboardType(.numberPad)
                    Picker("Year of Birth", selection: $details.body.birthYear) {
                        Text("Not set").tag(Int?.none)
                        ForEach(ProfileInput.birthYears().reversed(), id: \.self) { year in
                            Text(verbatim: String(year)).tag(Int?.some(year))
                        }
                    }
                    Picker("Sex", selection: $details.body.sex) {
                        ForEach([RiderSex.unspecified, .female, .male], id: \.self) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("For the Calories")
                } footer: {
                    Text("Weight 20–300 kg, height 80–250 cm. Without them the calories come from the work alone.")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = details
                        saved.body.weightKg = ProfileInput.accepted(weight, in: ProfileInput.weightKg)
                        saved.body.heightCm = ProfileInput.accepted(height, in: ProfileInput.heightCm)
                        save(saved)
                        dismiss()
                    }
                }
            }
            .task(id: photoItem) {
                guard let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
                if let scaled = PhotoScaler.jpegData(from: data, maxEdge: Self.photoEdge) { details.photoData = scaled }
            }
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
                Text("GPS jumps look like impossible speeds and are left out. For an e-bike that is above 100 km/h, for a motorcycle or a car above 300 km/h. In a car the recording shows the lateral acceleration.")
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
            BackupSection()
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

/// Back up the library into a folder of the rider's choice and bring a backup back (B-302), in the
/// format of the Mac.
private struct BackupSection: View {
    enum Picking { case destination, backup }

    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneSync.self) private var sync
    @Environment(PhoneBackup.self) private var backup
    @Environment(Recorder.self) private var recorder
    @AppStorage(PhoneSettingsKey.autoBackup) private var automatic = false
    /// What the folder picker is for. Kept until the picker's result is handled: SwiftUI sets
    /// `choosingFolder` back to false before it calls the result, so the purpose must not hang on it.
    @State private var picking: Picking?
    @State private var choosingFolder = false

    /// With sync on, the restore reaches the other devices too (B-265); the confirmation says so.
    private var syncs: Bool { sync.isOn || library.mode == .iCloud }

    var body: some View {
        @Bindable var backup = backup
        Section {
            Button {
                picking = .destination
                choosingFolder = true
            } label: {
                Label("Back Up Library …", systemImage: "externaldrive.badge.plus")
            }
            .disabled(backup.isWorking || backup.state == .restoreStaged)
            Button {
                picking = .backup
                choosingFolder = true
            } label: {
                Label("Restore Backup …", systemImage: "arrow.counterclockwise")
            }
            .disabled(backup.isWorking || backup.state == .restoreStaged || recorder.isRecording)
            Toggle("Back Up Automatically", isOn: $automatic)
            status
        } header: {
            Text("Backup")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("A backup is a folder with all your rides, bikes, goals and notes, the same as on the Mac. Choose iCloud Drive, On My iPhone or a USB stick. A backup from this iPhone restores on the Mac, and the other way round.")
                if automatic {
                    if backup.automaticFolderMissing {
                        Text("The folder for the automatic backup is no longer there. Back up once by hand to choose a new one.")
                            .foregroundStyle(.orange)
                    } else if !backup.hasFolder {
                        Text("Back up once by hand to choose the folder. After that Wattspur backs up there when it opens and the last backup is older than a week, and keeps the newest three automatic backups.")
                    } else {
                        Text("When Wattspur opens and the last backup is older than a week, it backs up into the folder you chose last. It keeps the newest three automatic backups there and deletes only its own.")
                    }
                }
                if let last = backup.lastBackup {
                    Text("Last backup: \(last.formatted(date: .abbreviated, time: .shortened))")
                }
            }
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            let purpose = picking
            picking = nil
            guard case .success(let folder) = result else { return }
            switch purpose {
            case .destination: backup.backUp(to: folder, rideCount: library.state?.rides.count)
            case .backup: backup.choose(folder)
            case nil: break
            }
        }
        .alert("Restore This Backup?", isPresented: Binding(get: { backup.candidate != nil },
                                                            set: { if !$0 { backup.candidate = nil } }),
               presenting: backup.candidate) { candidate in
            Button("Restore", role: .destructive) { backup.restore(candidate) }
            Button("Cancel", role: .cancel) { backup.candidate = nil }
        } message: { candidate in
            Text(confirmation(for: candidate.manifest))
        }
    }

    @ViewBuilder private var status: some View {
        switch backup.state {
        case .idle:
            EmptyView()
        case .working(let text):
            HStack(spacing: 8) {
                ProgressView()
                Text(text)
            }
        case .saved(let name, let place):
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Backed Up")
                    Text("“\(name)” in “\(place)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        case .restoreStaged:
            VStack(alignment: .leading, spacing: 8) {
                Label("Ready to Restore", systemImage: "arrow.triangle.2.circlepath")
                Text("Close Wattspur in the app switcher and open it again. It then replaces the library with the backup.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Cancel Restore", role: .destructive) { backup.cancelRestore() }
            }
        case .failed(let text):
            Label {
                Text(text)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }

    private func confirmation(for manifest: LibraryBackup.Manifest) -> String {
        var text = String(localized: "The backup is from \(manifest.createdAt.formatted(date: .long, time: .shortened)) (Wattspur \(manifest.appVersion)).")
        if let count = manifest.rideCount {
            text += " " + String(localized: "It holds \(count) rides.")
        }
        text += "\n\n" + String(localized: "The library on this iPhone is replaced with the backup the next time Wattspur opens. Rides and changes since the backup are not in it. The current library is kept in a folder beside it.")
        if syncs {
            text += "\n\n" + String(localized: "Sync with iCloud is on: the rides in iCloud and on all your devices are then replaced with the backup too.")
        }
        if manifest.build.compare(AppInfo.build, options: .numeric) == .orderedDescending {
            text += "\n\n" + String(localized: "This backup was made by a newer version of Wattspur. Update Wattspur before you restore it.")
        }
        return text
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
