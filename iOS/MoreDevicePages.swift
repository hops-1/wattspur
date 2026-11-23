import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurSymbols
import WattspurKit
import WattspurMap

/// A device in the profile: symbol, name, kind and what was ridden on it.
struct DeviceRow: View {
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
struct DevicePage: View {
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
struct DeviceEditor: View {
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
                            Label { Text(kind.label) } icon: { kind.image() }.tag(kind)
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
                BikeKindIcon(kind: kind, size: 52)
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
