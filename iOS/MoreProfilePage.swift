import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurSymbols
import WattspurKit
import WattspurMap

// MARK: - Profile

/// The profile (B-299): the rider with the data for the calories, edited here or on the Mac (the
/// same rider over iCloud); the totals and records of each sport; the devices by sport, each opens.
struct ProfilePage: View {
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
                        Button { adding = kind } label: { Label { Text(kind.label) } icon: { kind.image() } }
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
            tile("Distance", RideFormat.distance(totals.distance), "point.topleft.down.to.point.bottomright.curvepath")
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
