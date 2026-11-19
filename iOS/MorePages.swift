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
        case .view: ViewPage()
        case .maps: MapsPage()
        case .library: LibraryPage()
        case .trash: TrashView(embedded: embedded)
        case .help: HelpPage()
        case .about: AboutPage()
        case .testTools: TestToolsPage()
        }
    }
}


// MARK: - Profile

/// The profile (B-299): the rider with the data for the calories, edited here or on the Mac (the
/// same rider over iCloud); the totals and records of each sport; the devices by sport, each opens.
private struct ProfilePage: View {
    @Environment(PhoneLibrary.self) private var library
    @State private var editing = false
    /// A new device of this kind is being added (B-290).
    @State private var adding: BikeKind?

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
                            DeviceRow(device: device, usage: library.state?.usage(of: device.id) ?? (rides: 0, distance: 0))
                        }
                    }
                } header: {
                    Text(group.sport.devicesTitle)
                }
            }
            Section {
                Menu {
                    ForEach(BikeKind.selectable, id: \.self) { kind in
                        Button { adding = kind } label: { Label(kind.label, systemImage: BikeBadge.symbol(kind)) }
                    }
                } label: {
                    Label("Add Device", systemImage: "plus.circle")
                }
                .disabled(library.database == nil)
            } footer: {
                Text("With iCloud the devices come to the Mac too.")
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
        .sheet(item: $adding) { kind in
            DeviceEditor(id: nil, draft: Self.newDraft(kind), canArchive: false)
        }
    }

    private var name: String {
        let name = library.rider?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "No name yet") : name
    }

    private func value(_ text: String?) -> Text {
        text.map { Text($0) } ?? Text("Not set")
    }

    /// A new device of a kind: a bicycle is an e-bike, as on the Mac; a car or shoes are not.
    static func newDraft(_ kind: BikeKind) -> BikeDraft {
        var draft = BikeDraft()
        draft.kind = kind
        draft.isEbike = kind.sport == .cycling
        return draft
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
        case .scooter: "E-scooter"
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
                Text(verbatim: RideFormat.distance(usage.distance + (device.startKilometers ?? 0) * 1000))
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

/// One device, opened from the profile (B-299); **Edit** changes it (B-290).
private struct DevicePage: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    let deviceID: UUID
    @State private var editing: BikeDraft?

    init(device: RideExchange.Bike) {
        deviceID = device.id
        fallback = device
    }

    private let fallback: RideExchange.Bike
    /// The device as stored now, so the page shows a change right after saving.
    private var device: RideExchange.Bike { library.state?.bikes.first { $0.id == deviceID } ?? fallback }

    private var kind: BikeKind { BikeKind(rawValue: device.kind) ?? .bike }

    var body: some View {
        let usage = library.state?.usage(of: device.id) ?? (rides: 0, distance: 0)
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
                if let start = device.startKilometers, start > 0 {
                    LabeledContent("Before Wattspur") { Text(verbatim: RideFormat.distance(start * 1000)) }
                }
                if device.isArchived {
                    LabeledContent("Status") { Text("Archived") }
                }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { editing = library.deviceDraft(id: deviceID) }
                .disabled(library.database == nil)
        }
        // Deleted (B-322), here or on the Mac: back to the list.
        .onChange(of: library.state?.bikes.contains { $0.id == deviceID }) { _, exists in
            if exists == false { dismiss() }
        }
        .sheet(item: Binding(get: { editing.map(EditedDevice.init) }, set: { if $0 == nil { editing = nil } })) { edited in
            DeviceEditor(id: deviceID, draft: edited.draft, isArchived: device.isArchived,
                         canArchive: library.canArchive(deviceID: deviceID))
        }
    }

    /// The draft as an item for the sheet.
    private struct EditedDevice: Identifiable {
        var draft: BikeDraft
        var id: Int { 0 }
    }
}

/// Adds or edits a device on the iPhone (B-290): name, kind, colour, photo, odometer, maker and
/// model, the switch “E-Bike” for a bicycle only; the same rules as the Mac's editor (`BikeDraft`).
private struct DeviceEditor: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    /// `nil` for a new device.
    let id: UUID?
    @State private var draft: BikeDraft
    var isArchived = false
    let canArchive: Bool
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmingDelete = false

    init(id: UUID?, draft: BikeDraft, isArchived: Bool = false, canArchive: Bool) {
        self.id = id
        _draft = State(initialValue: draft)
        self.isArchived = isArchived
        self.canArchive = canArchive
    }

    /// Longer edge of the stored photo in pixels, as on the Mac.
    static let photoEdge = 1000

    private var kinds: [BikeKind] {
        BikeKind.selectable + (BikeKind.selectable.contains(draft.kind) ? [] : [draft.kind])
    }

    var body: some View {
        let photo = draft.photoData
        let kind = draft.kind
        let color = draft.color
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            DevicePhoto(photoData: photo, kind: kind, color: color)
                        }
                        .accessibilityLabel(Text("Choose Photo"))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    if draft.photoData != nil {
                        Button("Remove Photo", role: .destructive) { draft.photoData = nil }
                    }
                    TextField("Name", text: $draft.name)
                }
                Section {
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(kinds, id: \.self) { kind in
                            Label(kind.label, systemImage: BikeBadge.symbol(kind)).tag(kind)
                        }
                    }
                    if draft.kind.sport == .cycling {
                        Toggle("E-Bike", isOn: $draft.isEbike)
                    }
                    Picker("Color", selection: $draft.color) {
                        ForEach(BikeColor.allCases, id: \.self) { color in
                            Label { Text(color.label) } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(color == .white ? Color.white : BikeBadge.color(color))
                                    .overlay { Circle().strokeBorder(.secondary.opacity(color.isLight ? 0.6 : 0)) }
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section {
                    TextField("Manufacturer", text: $draft.manufacturer)
                    TextField("Model", text: $draft.model)
                    TextField("Kilometres before Wattspur", value: $draft.startKilometers,
                              format: .number.precision(.fractionLength(0...1)), prompt: Text("km"))
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("The kilometres before the first ride in Wattspur count in this device's total only.")
                }
                if let id {
                    Section {
                        if isArchived {
                            Button("Restore from Archive") {
                                library.saveDevice(draft, id: id)
                                library.setArchived(false, deviceID: id)
                                dismiss()
                            }
                            // Only without rides in the list, so no ride loses its device (B-322).
                            Button("Delete Device", role: .destructive) { confirmingDelete = true }
                                .disabled(library.listedRideCount(deviceID: id) > 0)
                        } else {
                            Button("Archive", role: .destructive) {
                                library.saveDevice(draft, id: id)
                                library.setArchived(true, deviceID: id)
                                dismiss()
                            }
                            .disabled(!canArchive)
                        }
                    } footer: {
                        let rides = library.listedRideCount(deviceID: id)
                        if isArchived && rides > 0 {
                            Text("To delete it, assign all its rides (\(rides)) to another device first.")
                        } else {
                            Text(canArchive || isArchived
                                 ? "An archived device keeps its rides and stays in the filters; new rides do not go to it."
                                 : "The last device cannot be archived: new rides need one.")
                        }
                    }
                    .confirmationDialog("Delete this device?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                        Button("Delete Device", role: .destructive) {
                            library.deleteDevice(id: id)
                            dismiss()
                        }
                    } message: {
                        Text("It disappears on all your devices. This cannot be undone.")
                    }
                }
            }
            .navigationTitle(id == nil ? "New Device" : "Edit Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        library.saveDevice(draft, id: id)
                        dismiss()
                    }
                }
            }
            .task(id: photoItem) {
                guard let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
                if let scaled = PhotoScaler.jpegData(from: data, maxEdge: Self.photoEdge) { draft.photoData = scaled }
            }
        }
    }
}

/// The device's photo, or its symbol in its colour without one.
private struct DevicePhoto: View {
    var photoData: Data?
    var kind: BikeKind
    var color: BikeColor

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: BikeBadge.symbol(kind))
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(BikeBadge.color(color))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: 120, height: 88)
        .clipShape(.rect(cornerRadius: 16))
        // A filling photo must not take taps outside its frame (B-331).
        .contentShape(.rect(cornerRadius: 16))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .padding(4)
        }
    }
}

extension BikeColor {
    var label: LocalizedStringKey {
        switch self {
        case .blue: "Blue"
        case .orange: "Orange"
        case .teal: "Teal"
        case .purple: "Purple"
        case .pink: "Pink"
        case .green: "Green"
        case .black: "Black"
        case .silver: "Silver"
        case .white: "White"
        }
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
        // The picker's label is a Sendable closure: it gets a copy, not the state.
        let avatar = details
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            RiderAvatar(rider: avatar, size: 88)
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

// MARK: - View

/// How the iPad shows the charts of a ride (wish of Nils, B-292): stacked to swipe through, as on
/// the iPhone, or one below the other, as on the Mac.
private struct ViewPage: View {
    @AppStorage(PhoneSettingsKey.padChartLayout) private var chartLayout: ChartLayout = .column

    var body: some View {
        Form {
            Section {
                Picker("Charts", selection: $chartLayout) {
                    ForEach(ChartLayout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Charts")
            } footer: {
                Text("Stacked: one chart at a time, swipe to the next, as on the iPhone. One below the other: all charts at once, as on the Mac. The map stays at the top either way.")
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
                            DeviceText.text("One library on this iPhone and your Mac, in your own iCloud account.", pad: "One library on this iPad and your Mac, in your own iCloud account.")
                        } else {
                            DeviceText.text("Without iCloud, the rides stay on this iPhone. They reach the Mac with “Share GPX”, e.g. by AirDrop.", pad: "Without iCloud, the rides stay on this iPad. They reach the Mac with “Share GPX”, e.g. by AirDrop.")
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
                    DeviceText.text("The rides stay in iCloud, on your Mac and on this iPhone. New rides then stay on this iPhone.", pad: "The rides stay in iCloud, on your Mac and on this iPad. New rides then stay on this iPad.")
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
                DeviceText.text("FIT and GPX files, several at once, also from iCloud Drive. Files you put into “On My iPhone › Wattspur › Import” in the Files app are imported when Wattspur opens; then they move to “Importiert”, or to “Fehler” if they cannot be read.", pad: "FIT and GPX files, several at once, also from iCloud Drive. Files you put into “On My iPad › Wattspur › Import” in the Files app are imported when Wattspur opens; then they move to “Importiert”, or to “Fehler” if they cannot be read.")
            }
            BackupSection()
            Section {
                LabeledContent("Rides") { Text((library.state?.rides.count ?? 0).formatted()) }
            } header: {
                Text("Library")
            } footer: {
                if library.mode == .iCloud {
                    DeviceText.text("Your rides are on this iPhone and in your own iCloud account, the same as on your Mac.", pad: "Your rides are on this iPad and in your own iCloud account, the same as on your Mac.")
                } else {
                    DeviceText.text("Your rides are on this iPhone. Sync with the Mac comes with iCloud.", pad: "Your rides are on this iPad. Sync with the Mac comes with iCloud.")
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
                DeviceText.text("A backup is a folder with all your rides, bikes, goals and notes, the same as on the Mac. Choose iCloud Drive, On My iPhone or a USB stick. A backup from this iPhone restores on the Mac, and the other way round.", pad: "A backup is a folder with all your rides, bikes, goals and notes, the same as on the Mac. Choose iCloud Drive, On My iPad or a USB stick. A backup from this iPad restores on the Mac, and the other way round.")
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
        text += "\n\n" + DeviceText.string("The library on this iPhone is replaced with the backup the next time Wattspur opens. Rides and changes since the backup are not in it. The current library is kept in a folder beside it.", pad: "The library on this iPad is replaced with the backup the next time Wattspur opens. Rides and changes since the backup are not in it. The current library is kept in a folder beside it.")
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
                            DeviceText.text("Some changes from this iPhone are not in iCloud yet. Keep iCloud on for Wattspur until they are, or they may be lost.", pad: "Some changes from this iPad are not in iCloud yet. Keep iCloud on for Wattspur until they are, or they may be lost.")
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
            DeviceText.string("This iPhone is not signed in to iCloud, or iCloud is off for Wattspur. New rides stay only on this iPhone.", pad: "This iPad is not signed in to iCloud, or iCloud is off for Wattspur. New rides stay only on this iPad.")
        case .restricted:
            DeviceText.string("iCloud is restricted on this iPhone. New rides stay only on this iPhone.", pad: "iCloud is restricted on this iPad. New rides stay only on this iPad.")
        case .quotaExceeded:
            DeviceText.string("Your iCloud storage is full. New rides stay on this iPhone until there is room again.", pad: "Your iCloud storage is full. New rides stay on this iPad until there is room again.")
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
                    Label { DeviceText.text("Wattspur on the iPhone", pad: "Wattspur on the iPad") } icon: { Image(systemName: DeviceText.isPad ? "ipad" : "iphone") }
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
                DeviceText.text("For a test of acceleration and lean angle: each recording also writes the motion sensors and GPS into a file. You find it in the Files app under “On My iPhone › Wattspur › Bewegung”. About 20 MB per hour.", pad: "For a test of acceleration and lean angle: each recording also writes the motion sensors and GPS into a file. You find it in the Files app under “On My iPad › Wattspur › Bewegung”. About 20 MB per hour.")
            }
        }
    }
}
