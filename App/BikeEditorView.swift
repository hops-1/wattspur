import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// The values the editor works on; applied to the bike only on "Save".
struct BikeDraft: Equatable {
    var name = ""
    var color: BikeColor = .blue
    var kind: BikeKind = .bike
    var isEbike = true
    var photoData: Data?
    var manufacturer = ""
    var model = ""
    var driveUnit = ""
    var batteryWh: Int?
    var weightKg: Double?
    var purchaseDate: Date?
    var startKilometers: Double?
    var makeActive = false

    init() {}

    init(_ bike: Bike, isActive: Bool) {
        name = bike.name
        color = bike.color
        kind = bike.kind
        isEbike = bike.isEbike
        photoData = bike.photoData
        manufacturer = bike.manufacturer
        model = bike.model
        driveUnit = bike.driveUnit
        batteryWh = bike.batteryWh
        weightKg = bike.weightKg
        purchaseDate = bike.purchaseDate
        startKilometers = bike.startKilometers > 0 ? bike.startKilometers : nil
        makeActive = isActive
    }

    func apply(to bike: Bike) {
        bike.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.color = color
        bike.kind = kind
        bike.isEbike = isEbike
        bike.photoData = photoData
        bike.manufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.driveUnit = driveUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        bike.batteryWh = batteryWh
        bike.weightKg = weightKg
        bike.purchaseDate = purchaseDate
        bike.startKilometers = startKilometers ?? 0
    }
}

/// Adds a bike or edits one (B-134, PROF-03): name, colour, kind, photo and the data
/// of the bike. Archiving a bike is offered here, because deleting it would orphan its rides.
struct BikeEditorView: View {
    let target: BikeEditorTarget
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var riders: [Rider]
    @Query private var bikes: [Bike]
    @State private var draft = BikeDraft()
    @State private var loaded = false
    @State private var choosingPhoto = false
    @State private var photoFailed = false

    @Environment(RideLibrary.self) private var library
    private var existing: Bike? {
        if case .edit(let bike) = target { return bike }
        return nil
    }
    private var wasActive: Bool { existing.map { riders.first?.activeBikeID == $0.id } ?? false }
    private var canSave: Bool { draft.name.nonEmpty != nil }
    private var openBikeCount: Int { bikes.filter { !$0.isArchived }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(existing == nil ? "New Bike" : "Edit Bike").font(.title2.bold())
                Spacer()
                HStack(spacing: 8) {
                    BikeChip(kind: draft.kind, color: draft.color, size: 24)
                    Text(verbatim: draft.name.nonEmpty ?? String(localized: "New bike")).font(.callout.weight(.semibold))
                }
                .padding(.leading, 4)
                .padding(.trailing, 12)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 14)

            ScrollView {
                HStack(alignment: .top, spacing: 28) {
                    photoColumn.frame(width: 190)
                    fields
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }

            Divider()
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 760, height: 800)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let bike = existing {
                draft = BikeDraft(bike, isActive: riders.first?.activeBikeID == bike.id)
            }
        }
        .fileImporter(isPresented: $choosingPhoto, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result, let data = PhotoPicker.load(url, maxEdge: 1000) else {
                photoFailed = true
                return
            }
            draft.photoData = data
        }
        .alert("The photo could not be read", isPresented: $photoFailed) {} message: {
            Text("Choose an image file such as JPEG, PNG or HEIC.")
        }
    }

    // MARK: - Photo

    private var photoColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo").font(.caption).foregroundStyle(.secondary)
            ZStack {
                if let data = draft.photoData, let image = NSImage(data: data) {
                    Color.clear.overlay { Image(nsImage: image).resizable().scaledToFill() }.clipped()
                } else {
                    draft.color.color.opacity(0.14)
                        .overlay { BikeKindIcon(kind: draft.kind, size: 56).foregroundStyle(draft.color.color) }
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
            .accessibilityHidden(true)
            HStack {
                Button(draft.photoData == nil ? "Choose Photo…" : "Change Photo…") { choosingPhoto = true }
                    .controlSize(.small)
                if draft.photoData != nil {
                    Button("Remove") { draft.photoData = nil }
                        .controlSize(.small)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            Text("The photo shows only here and on the tile in Profile; everywhere else you see the colored symbol.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledField("Name") {
                TextField("Name", text: $draft.name, prompt: Text("Bike name"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }
            BikeColorPicker(selection: $draft.color)
            kinds
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    LabeledField("Manufacturer") { text($draft.manufacturer, "Manufacturer") }
                    LabeledField("Model") { text($draft.model, "Model") }
                }
                GridRow {
                    LabeledField("Drive unit") { text($draft.driveUnit, "Drive unit", prompt: "Bosch Performance Line CX") }
                    LabeledField("Battery (Wh)") {
                        TextField("Battery (Wh)", value: battery, format: .number.grouping(.never), prompt: Text("Wh"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .monospacedDigit()
                    }
                }
                GridRow(alignment: .top) {
                    LabeledField("Weight (kg)") {
                        VStack(alignment: .leading, spacing: 4) {
                            NumberField("Weight (kg)", value: bikeWeight, range: ProfileInput.bikeWeightKg, width: 120, prompt: "kg")
                            Text("For information only, not used in any calculation.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    LabeledField("Purchase date") { purchaseDate }
                }
                GridRow(alignment: .top) {
                    LabeledField("Starting mileage (km)") {
                        VStack(alignment: .leading, spacing: 4) {
                            NumberField("Starting mileage (km)", value: startKilometers, range: ProfileInput.startKilometers, width: 120, prompt: "0")
                            Text("Odometer before the first ride in Wattspur; counts on the tile only.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
            }
            Toggle(isOn: $draft.makeActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make this the active bike")
                    Text("New rides go to the active bike.").font(.caption).foregroundStyle(.secondary)
                }
            }
            // The active bike stays active until another one is chosen.
            .disabled(wasActive)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            if let bike = existing { archiveBox(bike) }
        }
    }

    private func text(_ binding: Binding<String>, _ title: LocalizedStringKey, prompt: LocalizedStringKey? = nil) -> some View {
        TextField(title, text: binding, prompt: prompt.map { Text($0) })
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
    }

    private var battery: Binding<Int?> {
        Binding(get: { draft.batteryWh }, set: { draft.batteryWh = ProfileInput.accepted($0, in: ProfileInput.batteryWh) })
    }
    private var bikeWeight: Binding<Double?> {
        Binding(get: { draft.weightKg }, set: { draft.weightKg = ProfileInput.accepted($0, in: ProfileInput.bikeWeightKg) })
    }
    private var startKilometers: Binding<Double?> {
        Binding(get: { draft.startKilometers }, set: { draft.startKilometers = ProfileInput.accepted($0, in: ProfileInput.startKilometers) })
    }

    /// An optional date: a checkbox decides whether there is one.
    private var purchaseDate: some View {
        HStack(spacing: 8) {
            Toggle("Purchase date", isOn: Binding(get: { draft.purchaseDate != nil },
                                                  set: { draft.purchaseDate = $0 ? (draft.purchaseDate ?? .now) : nil }))
                .labelsHidden()
            DatePicker("Purchase date", selection: Binding(get: { draft.purchaseDate ?? .now }, set: { draft.purchaseDate = $0 }),
                       in: ...Date.now, displayedComponents: .date)
                .labelsHidden()
                .disabled(draft.purchaseDate == nil)
        }
    }

    private var kinds: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Bike type").font(.caption).foregroundStyle(.secondary).padding(.bottom, 4)
            ForEach(BikeKind.allCases) { kind in
                let selected = draft.kind == kind
                Button { draft.kind = kind } label: {
                    HStack(spacing: 14) {
                        BikeKindIcon(kind: kind, size: 26)
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .frame(width: 42, height: 42)
                            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.name).font(.body.weight(.semibold))
                            Text(kind.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).opacity(selected ? 1 : 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selected ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            HStack(spacing: 14) {
                EbikeShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .frame(width: 42, height: 42)
                    .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("E-bike").font(.body.weight(.semibold))
                    Text("With motor assistance (Bosch Smart System).").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("E-bike", isOn: $draft.isEbike).toggleStyle(.switch).labelsHidden()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Bike type"))
    }

    private func archiveBox(_ bike: Bike) -> some View {
        let isLast = openBikeCount <= 1 && !bike.isArchived
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Archive bike").font(.body.weight(.semibold))
                Text(isLast
                     ? "The last bike cannot be archived: new rides need a bike."
                     : "It disappears from the Import menu. Its rides stay assigned and the bike stays in the filters. You can restore it any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Archive", role: .destructive) { archive(bike) }
                .disabled(isLast)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }

    // MARK: - Actions

    private func save() {
        guard canSave else { return }
        let bike: Bike
        if let existing {
            bike = existing
        } else {
            bike = library.makeBike(name: draft.name, kind: draft.kind, color: draft.color)
        }
        draft.apply(to: bike)
        if draft.makeActive { library.setActiveBike(bike) }
        try? modelContext.save()
        dismiss()
    }

    private func archive(_ bike: Bike) {
        draft.apply(to: bike)
        do {
            try library.archive(bike)
            dismiss()
        } catch {
            // The button is disabled for the last bike; nothing else can go wrong.
        }
    }
}
