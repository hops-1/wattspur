import MapKit
import SwiftUI
import WattspurCore

/// The recording in full screen (B-211, design C): the map with the track and the own position,
/// time, distance, speed and altitude, Pause and Stop. Opened by “Start Ride” in the overview.
struct RecordingView: View {
    @Environment(Recorder.self) private var recorder
    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var ending = false
    /// The map turns with the direction of travel instead of north up (B-280); remembered.
    @AppStorage(PhoneSettingsKey.recordingMapHeadingUp) private var headingUp = false
    /// The direction the map points in while `headingUp`; kept while standing.
    @State private var mapHeading: Double?
    /// The zoom the rider chose, kept while the map turns.
    @State private var cameraDistance = 1_500.0
    @Environment(\.isLandscape) private var isLandscape

    var body: some View {
        Group {
            if isLandscape { landscape } else { portrait }
        }
        // Name and bike, then save, discard or keep riding (B-212). In landscape a window beside
        // the bar instead (B-243). Only its buttons close it: iOS also closes the sheet when the
        // iPhone turns, and the window has to stay open then.
        .sheet(isPresented: Binding(get: { ending && !isLandscape }, set: { _ in })) {
            if let recording = recorder.recording {
                SaveRecordingSheet(recording: recording) { ending = false }
                    .interactiveDismissDisabled()
            }
        }
        // “End ride” from Siri or a shortcut (B-225) does what Stop does: name the ride, then save.
        .onChange(of: recorder.endRequested, initial: true) { _, requested in
            if requested {
                ending = true
                recorder.endRequested = false
            }
        }
    }

    private var portrait: some View {
        VStack(spacing: 0) {
            map
            VStack(spacing: 16) {
                gpsStatus
                if let recording = recorder.recording {
                    RecordingFigures(recording: recording)
                }
                buttons
            }
            .padding()
        }
    }

    /// Landscape for the handlebar mount (B-243, variant B2): the map over the whole screen, on the
    /// left an upright glass bar with the speed large, the average below it, distance, time,
    /// altitude and ascent in two by two, Pause and Stop at the bottom. Only values from the iPhone.
    private var landscape: some View {
        map
            .ignoresSafeArea()
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 10) {
                    gpsStatus
                    if let recording = recorder.recording {
                        LandscapeRecordingFigures(recording: recording)
                    }
                    Spacer(minLength: 0)
                    buttons
                }
                .padding(14)
                .frame(width: 250)
                .frame(maxHeight: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 30))
                .padding(.vertical, 8)
            }
            .overlay(alignment: .trailing) {
                if ending, let recording = recorder.recording {
                    SaveRecordingSheet(recording: recording) { ending = false }
                        .frame(width: 440)
                        .clipShape(.rect(cornerRadius: 30))
                        .shadow(radius: 20)
                        .padding(.vertical, 8)
                        // Inside the safe area, so clear of the map's buttons at the top right.
                        .padding(.trailing, 8)
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.snappy, value: ending)
    }

    /// Why there is no position, or that the GPS is still settling.
    @ViewBuilder private var gpsStatus: some View {
        if let problem = recorder.logProblem {
            Label(problem, systemImage: "externaldrive.badge.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
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
        .onMapCameraChange(frequency: .onEnd) { context in
            cameraDistance = context.camera.distance
        }
        .onChange(of: recorder.movement) { _, movement in
            follow(movement)
        }
        .onChange(of: headingUp) { _, on in
            mapHeading = nil
            if on { follow(recorder.movement) } else { camera = .userLocation(followsHeading: false, fallback: .automatic) }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                headingUp.toggle()
            } label: {
                Image(systemName: headingUp ? "location.north.line.fill" : "location.north.line")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(headingUp ? Color.track : nil)
            .padding(12)
            .accessibilityLabel(Text("Direction of travel up"))
            .accessibilityValue(Text(headingUp ? LocalizedStringKey("On") : LocalizedStringKey("Off")))
            .accessibilityAddTraits(.isToggle)
        }
    }

    /// With the direction of travel up, the map follows the position and turns to the course of the
    /// GPS; standing, it keeps its direction (B-280). North up, MapKit follows the position itself.
    private func follow(_ movement: Recorder.Movement?) {
        guard headingUp, let movement else { return }
        mapHeading = MapHeading.next(current: mapHeading, course: movement.course,
                                     courseAccuracy: movement.courseAccuracy, speed: movement.speed)
        guard let heading = mapHeading else { return }
        let center = CLLocationCoordinate2D(latitude: movement.latitude, longitude: movement.longitude)
        withAnimation(.linear(duration: 0.8)) {
            camera = .camera(MapCamera(centerCoordinate: center, distance: cameraDistance, heading: heading, pitch: 0))
        }
    }

    private var buttons: some View {
        HStack(spacing: isLandscape ? 10 : 16) {
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
        // The bar in landscape is narrow: smaller buttons, so “Pause” and “Stop” stay on one line.
        .controlSize(isLandscape ? .regular : .large)
        .font(isLandscape ? .subheadline.weight(.semibold) : .headline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// “Ride on 2 Nov 2026, 17:05”.
    static func defaultName(for date: Date) -> String {
        String(localized: "Ride on \(date.formatted(date: .abbreviated, time: .shortened))")
    }
}

/// The figures of the landscape bar (B-243): the speed large with the average below, then
/// distance, time, altitude and ascent.
struct LandscapeRecordingFigures: View {
    var recording: RideRecording

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Speed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if recording.isPaused {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.orange, in: .capsule)
                            .foregroundStyle(.white)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(RideFormat.speedNumber(recording.currentSpeed))
                        .font(.system(size: 60, weight: .bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(verbatim: "km/h")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: "Ø \(RideFormat.speed(recording.averageSpeed))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    figure("Distance", RideFormat.distance(recording.distance))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        figure("Time", Duration.seconds(context.date.timeIntervalSince(recording.startDate))
                            .formatted(.time(pattern: .hourMinuteSecond)))
                    }
                }
                GridRow {
                    figure("Altitude", recording.lastPoint?.fix.altitude.map(RideFormat.altitude) ?? "–")
                    figure("Ascent", recording.ascent.map(RideFormat.ascent) ?? "–")
                }
            }
        }
    }

    private func figure(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
