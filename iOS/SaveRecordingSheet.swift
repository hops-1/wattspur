import SwiftUI
import WattspurCore

/// After Stop (B-212): name the ride, choose the bike, then save it for the Mac, discard it, or
/// keep riding.
struct SaveRecordingSheet: View {
    @Environment(Recorder.self) private var recorder
    @Environment(PhoneRecordings.self) private var recordings
    @Environment(PhoneLibrary.self) private var library
    @Environment(ImportFolder.self) private var folder
    @Environment(\.dismiss) private var dismiss
    var recording: RideRecording
    /// Closes the window; beside the bar of the landscape recording it is no sheet (B-243).
    var close: (() -> Void)?

    @State private var name = ""
    @State private var bikeID: UUID?
    @State private var confirmingDiscard = false
    @State private var problem: String?

    private var bikes: [RideExchange.Bike] {
        (library.state?.bikes ?? []).filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    if !bikes.isEmpty {
                        Picker("Bike", selection: $bikeID) {
                            ForEach(bikes) { bike in
                                Label { Text(bike.name) } icon: { BikeBadge(bike: bike) }
                                    .tag(Optional(bike.id))
                            }
                        }
                    }
                } footer: {
                    switch library.mode {
                    case .iCloud:
                        Text("The ride is saved on this iPhone and reaches your Mac over iCloud.")
                    case .local:
                        Text("The ride is saved on this iPhone.")
                    case .folder:
                        Text(folder.url == nil
                             ? "No folder is chosen: the ride stays on the iPhone, in the Files app under “On My iPhone › Wattspur”."
                             : "The ride goes as GPX into the folder “Wattspur Import”. The Mac imports it on the bike chosen here.")
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
            bikeID = Self.defaultBike(among: bikes, last: recordings.lastBikeID, lastRide: library.state?.lastRide)
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

    /// Saves a finished recording: with the iPhone's own store it becomes a ride there (B-216), else it
    /// goes as GPX into the folder for the Mac (B-212). The GPX is the same either way, with its bike.
    static func store(_ recording: RideRecording, name: String, bike: RideExchange.Bike?,
                      library: PhoneLibrary, recordings: PhoneRecordings, folder: ImportFolder) throws {
        guard library.usesDatabase else {
            try recordings.save(recording, name: name, bike: bike, folder: folder)
            return
        }
        let note = bike.map { String(localized: "Bike: \($0.name)") }
        let data = GPXWriter.document(name: name, segments: recording.gpxSegments, description: note,
                                      creator: GPXWriter.iPhoneCreator, bikeID: bike?.id)
        try library.saveRecording(gpx: data, fileName: GPXWriter.fileName(name))
    }

    private func save() {
        let title = name.trimmingCharacters(in: .whitespaces)
        let bike = bikes.first { $0.id == bikeID }
        do {
            try Self.store(recording, name: title.isEmpty ? RecordingView.defaultName(for: recording.startDate) : title,
                           bike: bike, library: library, recordings: recordings, folder: folder)
            recordings.lastBikeID = bike?.id
            _ = recorder.stop()
            finish()
        } catch {
            // The recording and its log stay, so nothing is lost; the rider can try again.
            problem = error.localizedDescription
        }
    }
}
