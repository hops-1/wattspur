import MapKit
import SwiftUI
import WattspurCore

/// The recording in full screen (B-211, design C): the map with the track and the own position,
/// time, distance, speed and altitude, Pause and Stop. Opened by “Start Ride” in the overview.
struct RecordingView: View {
    @Environment(Recorder.self) private var recorder
    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var ending = false

    var body: some View {
        VStack(spacing: 0) {
            map
            VStack(spacing: 16) {
                if let status = recorder.status {
                    Label(status, systemImage: "location.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else if recorder.recording?.isWaitingForGPS == true {
                    // The first position has to be accurate (RideRecording.startAccuracy).
                    Label("GPS is getting more accurate …", systemImage: "location.magnifyingglass")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let recording = recorder.recording {
                    RecordingFigures(recording: recording)
                }
                buttons
            }
            .padding()
        }
        // Name and bike, then save, discard or keep riding (B-212).
        .sheet(isPresented: $ending) {
            if let recording = recorder.recording {
                SaveRecordingSheet(recording: recording)
            }
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
                ending = true
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
