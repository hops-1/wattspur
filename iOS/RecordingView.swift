import MapKit
import SwiftUI
import WattspurCore

/// The recording in full screen (B-211, design C): the map with the track and the own position,
/// time, distance, speed and altitude, Pause and Stop. Opened by “Start Ride” in the overview.
struct RecordingView: View {
    @Environment(Recorder.self) private var recorder
    @Environment(ImportFolder.self) private var folder
    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var confirmingStop = false
    @State private var name = ""
    @State private var saveProblem: String?

    var body: some View {
        VStack(spacing: 0) {
            map
            VStack(spacing: 16) {
                if let status = recorder.status {
                    Label(status, systemImage: "location.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if let recording = recorder.recording {
                    RecordingFigures(recording: recording)
                }
                buttons
            }
            .padding()
        }
        .alert("End Ride?", isPresented: $confirmingStop) {
            TextField("Name", text: $name)
            Button("Save") { save() }
            Button("Discard", role: .destructive) { _ = recorder.stop() }
            Button("Keep Riding", role: .cancel) {}
        } message: {
            Text("The ride goes as GPX into the folder “Wattspur Import”, and the Mac imports it.")
        }
        .alert("Could Not Save", isPresented: Binding(get: { saveProblem != nil }, set: { if !$0 { saveProblem = nil } })) {
            Button("OK") {}
        } message: {
            Text(saveProblem ?? "")
        }
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let route = recorder.recording?.route {
                ForEach(route.segments.indices, id: \.self) { index in
                    let segment = route.segments[index]
                    MapPolyline(coordinates: zip(segment.latitude, segment.longitude).map {
                        CLLocationCoordinate2D(latitude: $0, longitude: $1)
                    })
                    .stroke(Color.track, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var buttons: some View {
        HStack(spacing: 16) {
            if recorder.recording?.isPaused == true {
                Button { recorder.resume() } label: {
                    Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .tint(.green)
            } else {
                Button { recorder.pause() } label: {
                    Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                }
                .tint(.orange)
            }
            Button {
                name = Self.defaultName(for: recorder.recording?.startDate ?? .now)
                confirmingStop = true
            } label: {
                Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }
            .tint(.red)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .font(.headline)
    }

    /// “Ride on 2 Nov 2026, 17:05”.
    static func defaultName(for date: Date) -> String {
        String(localized: "Ride on \(date.formatted(date: .abbreviated, time: .shortened))")
    }

    private func save() {
        guard let recording = recorder.recording else { return }
        let title = name.trimmingCharacters(in: .whitespaces).isEmpty ? Self.defaultName(for: recording.startDate) : name
        do {
            try RecordingSaver.save(recording, name: title, folder: folder)
            _ = recorder.stop()
        } catch {
            // The recording and its log stay, so nothing is lost; the rider can try again.
            saveProblem = error.localizedDescription
        }
    }
}

/// Time, distance, speed and altitude in large type.
struct RecordingFigures: View {
    var recording: RideRecording

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    figure("Time", Duration.seconds(context.date.timeIntervalSince(recording.startDate))
                        .formatted(.time(pattern: .hourMinuteSecond)))
                }
                figure("Distance", RideFormat.distance(recording.distance))
            }
            GridRow {
                figure("Speed", RideFormat.speed(recording.currentSpeed))
                figure("Altitude", recording.lastPoint?.fix.altitude.map(RideFormat.altitude) ?? "–")
            }
        }
        .overlay(alignment: .top) {
            if recording.isPaused {
                Text("Paused")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange, in: .capsule)
                    .foregroundStyle(.white)
                    .offset(y: -28)
            }
        }
    }

    private func figure(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// Writes a finished recording as GPX (`GPXWriter`, creator “Wattspur iOS”) into the folder the
/// Mac watches; without a folder into the app's documents, where the Files app shows it.
enum RecordingSaver {
    @MainActor
    static func save(_ recording: RideRecording, name: String, folder: ImportFolder) throws {
        let data = GPXWriter.document(name: name, segments: recording.gpxSegments, creator: "Wattspur iOS")
        let fileName = GPXWriter.fileName(name)
        if folder.url != nil {
            let taken = Set((try? folder.contents()) ?? [])
            try folder.write(data, to: uniqueName(fileName, taken: taken))
        } else {
            let directory = URL.documentsDirectory.appending(path: "Aufnahmen")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let taken = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            try data.write(to: directory.appending(path: uniqueName(fileName, taken: taken)), options: .atomic)
        }
    }

    /// “Ride.gpx”, else “Ride 2.gpx” …
    static func uniqueName(_ name: String, taken: Set<String>) -> String {
        guard taken.contains(name) else { return name }
        let base = (name as NSString).deletingPathExtension
        var counter = 2
        while taken.contains("\(base) \(counter).gpx") { counter += 1 }
        return "\(base) \(counter).gpx"
    }
}
