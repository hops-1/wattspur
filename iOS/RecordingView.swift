import MapKit
import SwiftUI
import WattspurCore
import WattspurMap

/// The recording in full screen (B-211, design C): the map with the track and the own position,
/// time, distance, speed and altitude, Pause and Stop. Opened by “Start Ride” in the overview.
struct RecordingView: View {
    @Environment(Recorder.self) private var recorder
    @State private var ending = false
    /// Figures or profile below the map and in the bar on the left (B-277).
    enum Page: Hashable { case figures, profile }
    @State private var page = Page.figures
    /// The map turns with the direction of travel instead of north up (B-280); remembered.
    @AppStorage(PhoneSettingsKey.recordingMapHeadingUp) private var headingUp = false
    /// The direction the map points in while `headingUp`; kept while standing.
    @State private var mapHeading: Double?
    /// The track by height while recording (B-283); remembered.
    @AppStorage(PhoneSettingsKey.recordingTrackByElevation) private var byElevation = false
    /// The style of every map (B-226), chosen in the ride's detail or under More.
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard
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
                    // Swipe from the figures to the profile of the ride so far (B-277).
                    // The page dots sit at the bottom: the figures keep room for them below (B-320).
                    TabView(selection: $page) {
                        RecordingFigures(recording: recording)
                            .padding(.top, 28)
                            .padding(.bottom, recording.vehicle == .car ? Self.dotsRoom : 0)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .tag(Page.figures)
                        RecordingProfileView(recording: recording)
                            .padding(.bottom, Self.dotsRoom)
                            .tag(Page.profile)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    // A car adds the bar of the lateral acceleration (B-287) and room for the dots.
                    .frame(height: recording.vehicle == .car ? 330 : 210)
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
                        // Swipe from the figures to a small profile of the ride so far (B-277).
                        TabView(selection: $page) {
                            // Room for the page dots at the bottom, so they cover no figure (B-320).
                            LandscapeRecordingFigures(recording: recording)
                                .padding(.bottom, recording.vehicle == .car ? Self.dotsRoom : 0)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .tag(Page.figures)
                            RecordingProfileView(recording: recording, compact: true)
                                .padding(.bottom, 26)
                                .tag(Page.profile)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .indexViewStyle(.page(backgroundDisplayMode: .always))
                    } else {
                        Spacer(minLength: 0)
                    }
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

    /// Points at the bottom of a page for the page dots.
    static let dotsRoom: CGFloat = 28

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
        RecordingMapView(mapType: mapType, segments: trackSegments, colouring: trackColouring,
                         heading: headingUp ? mapHeading : nil,
                         center: recorder.movement.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
        .onChange(of: recorder.movement) { _, movement in
            follow(movement)
        }
        .onChange(of: headingUp) { _, on in
            mapHeading = nil
            if on { follow(recorder.movement) }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
            Button {
                byElevation.toggle()
            } label: {
                Image(systemName: "mountain.2")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(byElevation ? Color.track : nil)
            .accessibilityLabel(Text("Color the route by elevation"))
            .accessibilityValue(Text(byElevation ? LocalizedStringKey("On") : LocalizedStringKey("Off")))
            .accessibilityAddTraits(.isToggle)
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
            .accessibilityLabel(Text("Direction of travel up"))
            .accessibilityValue(Text(headingUp ? LocalizedStringKey("On") : LocalizedStringKey("Off")))
            .accessibilityAddTraits(.isToggle)
            }
            .padding(12)
            .padding(.bottom, creditRoom)
        }
        .overlay(alignment: .bottomLeading) {
            if byElevation, let route = recorder.recording?.route, let elevation = RouteElevation.stretches(route) {
                ElevationLegend(scale: elevation.scale)
                    .padding(isLandscape ? 0 : 8)
                    // In landscape the bar with the figures covers the left side.
                    .padding(.leading, isLandscape ? 270 : 0)
                    .padding(.bottom, (isLandscape ? 12 : 0) + creditRoom)
            }
        }
        .overlay(alignment: .topTrailing) {
            // The map style while riding (B-226), at the top right as on every other map; the buttons
            // for the position and the compass sit below it.
            MapTypeMenu(mapType: $mapType, size: 44)
                .padding(12)
        }
    }

    /// Points at the bottom kept free for the credit of an OpenStreetMap style.
    private var creditRoom: CGFloat { mapType.tileSource == nil ? 0 : 30 }

    /// The track so far, one line per segment.
    private var trackSegments: [[CLLocationCoordinate2D]] {
        (recorder.recording?.route.segments ?? []).map { segment in
            zip(segment.latitude, segment.longitude).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
        }
    }

    /// By height (B-283): the scale follows the heights ridden so far; only worked out while on.
    private var trackColouring: RouteColouring {
        guard byElevation, let route = recorder.recording?.route, let elevation = RouteElevation.stretches(route) else { return .plain }
        return .elevation(elevation.stretches)
    }

    /// With the direction of travel up, the map turns to the course of the GPS; standing, it keeps its
    /// direction (B-280). North up, MapKit follows the position itself.
    private func follow(_ movement: Recorder.Movement?) {
        guard headingUp, let movement else { return }
        mapHeading = MapHeading.next(current: mapHeading, course: movement.course,
                                     courseAccuracy: movement.courseAccuracy, speed: movement.speed)
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
            if recording.vehicle == .car {
                Divider()
                LateralBar(recording: recording)
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
            if recording.vehicle == .car {
                GridRow {
                    LateralBar(recording: recording)
                        .padding(12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .gridCellColumns(2)
                }
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

/// A car's lateral acceleration while recording (B-287): the value of the last GPS point in g and a
/// bar from 0.5 g left to 0.5 g right, filled from the middle towards the side of the turn, like the
/// lean of a bike.
struct LateralBar: View {
    var recording: RideRecording
    static let reach = 0.5
    static var scaleText: String { "\(reach.formatted(.number.precision(.fractionLength(1)))) g" }

    /// In g, positive in a left turn; `nil` before the first value or while paused.
    private var lateral: Double? {
        guard !recording.isPaused, let lean = recording.lastPoint?.fix.motion?.lean else { return nil }
        return SideMeasure.lateralAcceleration.value(lean: lean)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lateral Acceleration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: lateral.map { SideMeasure.lateralAcceleration.text(lean: atan($0) * 180 / .pi) } ?? "–")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                let half = proxy.size.width / 2
                let share = min(abs(lateral ?? 0) / Self.reach, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    // Left turn: from the middle to the left; right turn: from the middle to the right.
                    Capsule()
                        .fill(Color.indigo)
                        .frame(width: half * share)
                        .offset(x: (lateral ?? 0) > 0 ? half - half * share : half)
                    Rectangle().fill(.secondary).frame(width: 1.5).offset(x: half - 0.75)
                }
            }
            .frame(height: 10)
            .clipShape(.capsule)
            // The ends of the bar, in the device's language: “0,5 g” in German (B-320).
            HStack {
                Text(verbatim: Self.scaleText).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: Self.scaleText).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Lateral Acceleration"))
        .accessibilityValue(Text(verbatim: lateral.map { value in
            let side = value > 0 ? String(localized: "left") : value < 0 ? String(localized: "right") : ""
            return "\(SideMeasure.lateralAcceleration.text(lean: atan(value) * 180 / .pi)) \(side)"
        } ?? "–"))
    }
}
