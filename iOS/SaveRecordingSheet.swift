import SwiftUI
import WattspurCore

/// After Stop (B-212): name the ride, choose the device (set to the one it was started with, B-286),
/// then save it, discard it, or keep riding.
struct SaveRecordingSheet: View {
    @Environment(Recorder.self) private var recorder
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    var recording: RideRecording
    /// Closes the window; beside the bar of the landscape recording it is no sheet (B-243).
    var close: (() -> Void)?

    @State private var name = ""
    @State private var device: RecordingDevice?
    @State private var confirmingDiscard = false
    @State private var problem: String?

    private var bikes: [RideExchange.Bike] {
        (library.state?.bikes ?? []).filter { !$0.isArchived }
    }

    /// The devices, then the vehicle types without one (B-286, B-321).
    private var choices: [RecordingDevice] {
        bikes.map { RecordingDevice(bikeID: $0.id, kind: BikeKind(rawValue: $0.kind) ?? .bike) }
            + RecordingDevice.vehicleTypes.map(RecordingDevice.without)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Device", selection: $device) {
                        ForEach(choices, id: \.self) { choice in
                            if let bike = bikes.first(where: { $0.id == choice.bikeID }) {
                                Label { Text(bike.name) } icon: { BikeBadge(bike: bike) }
                                    .tag(Optional(choice))
                            } else {
                                Label { Text("\(choice.kind.localizedName) (vehicle type only)") } icon: { Image(systemName: choice.symbol) }
                                    .tag(Optional(choice))
                            }
                        }
                    }
                } footer: {
                    switch library.mode {
                    case .iCloud:
                        Text("The ride is saved on this iPhone and reaches your Mac over iCloud.")
                    case .local:
                        Text("The ride is saved on this iPhone.")
                    }
                }
                Section {
                    LabeledContent("Distance", value: RideFormat.distance(recording.distance))
                    LabeledContent("Riding Time", value: RideFormat.duration(recording.movingTime))
                    if let ascent = recording.ascent {
                        LabeledContent("Ascent", value: RideFormat.ascent(ascent))
                    }
                }
                if recording.isTooShort {
                    Text("The recording has no track yet: GPS needs a few seconds of riding. Keep riding or discard it.")
                        .foregroundStyle(.orange)
                }
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
                Section {
                    Button("Discard Ride", role: .destructive) { confirmingDiscard = true }
                }
            }
            .navigationTitle("End Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Riding") { finish() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(recording.isTooShort)
                }
            }
            .confirmationDialog("Discard this ride?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard Ride", role: .destructive) {
                    _ = recorder.stop()
                    finish()
                }
            }
        }
        .onAppear {
            name = RecordingView.defaultName(for: recording.startDate)
            device = Self.defaultDevice(for: recording, among: bikes, lastRide: library.state?.lastRide)
        }
    }

    init(recording: RideRecording, close: (() -> Void)? = nil) {
        self.recording = recording
        self.close = close
    }

    private func finish() {
        if let close { close() } else { dismiss() }
    }

    /// The bike chosen last time, else the bike of the last ride from the Mac, else the first.
    static func defaultBike(among bikes: [RideExchange.Bike], last: UUID?, lastRide: RideExchange.Ride?) -> UUID? {
        let ids = Set(bikes.map(\.id))
        if let last, ids.contains(last) { return last }
        if let id = lastRide?.bikeID, ids.contains(id) { return id }
        return bikes.first?.id
    }

    /// The device the recording was started with if it is still there (B-286); for a recording from
    /// before the choice, the bike chosen last time as before.
    static func defaultDevice(for recording: RideRecording, among bikes: [RideExchange.Bike],
                              lastRide: RideExchange.Ride?) -> RecordingDevice? {
        if let device = recording.device, device.bikeID == nil || bikes.contains(where: { $0.id == device.bikeID }) {
            return device
        }
        let id = defaultBike(among: bikes, last: lastBikeID, lastRide: lastRide)
        return bikes.first { $0.id == id }.map { RecordingDevice(bikeID: $0.id, kind: BikeKind(rawValue: $0.kind) ?? .bike) }
    }

    /// The last bike chosen when saving, as the default for the next ride.
    static var lastBikeID: UUID? {
        get { UserDefaults.standard.string(forKey: PhoneSettingsKey.lastRecordingBike).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: PhoneSettingsKey.lastRecordingBike) }
    }

    /// Saves a finished recording as a ride of the iPhone's own store (B-216): as GPX with its bike
    /// (creator “Wattspur iOS”, B-213) through the Kit's import, as on the Mac.
    /// Without a bike, the ride goes in as its kind (`wattspur:kind`, B-286): a car or motorcycle stays
    /// out of the cycling totals, a bicycle (B-321) counts in them but towards no bike.
    static func store(_ recording: RideRecording, name: String, device: RecordingDevice?,
                      library: PhoneLibrary) throws {
        let bike = (library.state?.bikes ?? []).first { $0.id == device?.bikeID && device?.bikeID != nil }
        let kind = bike == nil ? device?.kind : nil
        let note = bike.map { String(localized: "Vehicle: \($0.name)") }
        let data = GPXWriter.document(name: name, segments: recording.gpxSegments, description: note,
                                      creator: GPXWriter.iPhoneCreator, bikeID: bike?.id,
                                      sport: (bike.flatMap { BikeKind(rawValue: $0.kind) } ?? kind ?? .bike).sport,
                                      kind: kind)
        try library.saveRecording(gpx: data, fileName: GPXWriter.fileName(name))
    }

    private func save() {
        let title = name.trimmingCharacters(in: .whitespaces)
        do {
            try Self.store(recording, name: title.isEmpty ? RecordingView.defaultName(for: recording.startDate) : title,
                           device: device, library: library)
            if let id = device?.bikeID { Self.lastBikeID = id }
            if let device { RecordingChoice.last = device }
            _ = recorder.stop()
            finish()
        } catch {
            // The recording and its log stay, so nothing is lost; the rider can try again.
            problem = error.localizedDescription
        }
    }
}
