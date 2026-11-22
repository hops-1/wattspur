import CoreLocation
import CoreMotion
import Foundation
import Observation
import UIKit
import WattspurCore

/// Records a ride with GPS (B-211): `CLLocationUpdate.liveUpdates(.fitness)` with a
/// `CLBackgroundActivitySession`, so it goes on with the screen locked (spike V-14). Every event
/// goes into a log file at once; after a crash the app offers to continue or finish the ride.
/// The height comes from the barometer, lifted to the GPS level (`AltitudeFusion`, B-235).
///
/// Two states (B-369): `recording` is the ride as it is recorded, and no view observes it; `shown`
/// is what the screen draws, brought up to date only while someone can see it (`RecordingDisplay`).
/// `isRecording` and `isReady` change only when they really change, so the app's root and the tabs
/// behind the recording are not drawn again with every position.
@MainActor @Observable
final class Recorder {
    /// The ride being recorded, always current; `nil` when nothing is recorded. For the log, the Live
    /// Activity, CarPlay, the intents and saving. Views read `shown`.
    @ObservationIgnored private(set) var recording: RideRecording?
    /// The ride as the screen shows it.
    private(set) var shown: RideRecording?
    /// A recording found at launch that was not finished (crash, app killed).
    private(set) var unfinished: RideRecording?
    /// What the location service reported last, e.g. “Location access denied”.
    private(set) var status: String?
    /// Set when the log of the recording could not be written (storage full, R-52): the ride goes on
    /// in memory and can be saved, but would not survive a crash.
    private(set) var logProblem: String?

    /// Where the iPhone is and how it moves, from the last GPS fix, for the map with the direction of
    /// travel up (B-280); also while paused.
    struct Movement: Equatable {
        var latitude: Double
        var longitude: Double
        var course: Double
        var courseAccuracy: Double
        var speed: Double
    }
    private(set) var movement: Movement?
    @ObservationIgnored private var latestMovement: Movement?

    private(set) var isRecording = false
    /// Waiting for the vehicle to move (auto-start, B-311): the track begins above 10 km/h.
    private(set) var isReady = false
    /// Whether the recording screen can be seen.
    @ObservationIgnored private var isVisible = false
    /// The recording came from auto-start (B-311): it may end and save by itself (B-339).
    private(set) var isAutoStarted = false
    /// Saves an auto-ended ride with a name (B-339); set by the app, which has the library. Returns
    /// whether it was saved: if not, the recording goes on, so nothing is lost.
    var autoSave: (_ recording: RideRecording, _ name: String) -> Bool = { _, _ in false }
    /// How long the vehicle has stood (B-339); only for an auto-started recording.
    @ObservationIgnored private var standstill: AutoStart.Standstill?
    @ObservationIgnored private var standstillCheck: Task<Void, Never>?
    /// Set while an automatic end looks up the names of the places, so it runs once.
    @ObservationIgnored private var isEndingAutomatically = false
    /// Siri or a shortcut asked to end the ride (B-225): the recording screen opens “Save Ride”.
    var endRequested = false

    /// Where a start without a device (Siri, a shortcut) gets it from: the library's next device
    /// (B-286). Set by the app; without it a recording starts as a bicycle.
    var nextDevice: () -> RecordingDevice = { RecordingChoice.next(devices: RecordingChoice.cachedDevices, activeID: nil) }

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?
    @ObservationIgnored private var serviceSession: CLServiceSession?
    @ObservationIgnored private var log: FileHandle?
    @ObservationIgnored private var diagnostics: RecordingDiagnostics?
    private let logURL: URL
    /// The barometer (B-235); every iPhone with iOS 26 has one, but motion access may be denied.
    private let altimeter = CMAltimeter()
    private let barometer = Barometer()
    @ObservationIgnored private var fusion = AltitudeFusion()
    /// Lean angle, acceleration and roughness (B-245), and the raw motion of spike V-16 while the
    /// test switch in “More” is on.
    @ObservationIgnored private var motion: MotionRecorder?
    /// The motion values of GPS points the recording dropped, for the next point it keeps.
    @ObservationIgnored private var droppedMotion: MotionValues?
    /// The Live Activity on the Lock Screen and in the Dynamic Island (B-223).
    private let activity = RecordingActivityController()

    /// The log lives in Application Support: the documents are shown in the Files app.
    init(logURL: URL = .applicationSupportDirectory.appending(path: "Aufnahme.jsonl")) {
        self.logURL = logURL
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: logURL), let recording = RecordingLog.replay(data) {
            // A recording that was still ready has nothing in it to continue (B-311).
            if recording.isReady {
                try? FileManager.default.removeItem(at: logURL)
            } else {
                unfinished = recording
            }
        }
        // Pause and Resume from the Live Activity (B-223).
        RecordingControl.togglePause = { [weak self] in
            guard let self, let recording = self.recording else { return }
            if recording.isPaused { self.resume() } else { self.pause() }
        }
        // Cancel “Ready” from the Live Activity (B-311).
        RecordingControl.cancelReady = { [weak self] in self?.cancelReady() }
        watchVisibility()
    }

    // MARK: - What the screen shows (B-369)

    /// The iPhone's window, not the app: with CarPlay the app stays in front while the window is hidden.
    private func watchVisibility() {
        let changes = [(UIScene.willEnterForegroundNotification, true), (UIScene.didActivateNotification, true),
                       (UIScene.didEnterBackgroundNotification, false)]
        for (name, visible) in changes {
            // The recorder lives as long as the app.
            _ = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let scene = note.object as? UIScene else { return }
                MainActor.assumeIsolated {
                    guard scene.session.role == .windowApplication else { return }
                    self?.setVisible(visible)
                }
            }
        }
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible { publish() }
    }

    /// Hands the recording to the screen when it is visible or the recording's state changed.
    private func publish() {
        if RecordingDisplay.publishes(recording, over: shown, isVisible: isVisible) { shown = recording }
        if isVisible, movement != latestMovement { movement = latestMovement }
        let recordingNow = recording != nil
        if isRecording != recordingNow { isRecording = recordingNow }
        let readyNow = recording?.isReady == true
        if isReady != readyNow { isReady = readyNow }
    }

    /// Starts a recording with `device` (B-286), or the next one (the last device used) without.
    /// `ready`: auto-start (B-311), the recording waits until the vehicle moves.
    func start(at date: Date = .now, device: RecordingDevice? = nil, ready: Bool = false) {
        guard recording == nil else { return }
        unfinished = nil
        let device = device ?? nextDevice()
        RecordingChoice.last = device
        let vehicle = device.vehicle
        recording = RideRecording(startDate: date, device: device)
        if ready { recording?.waitForMovement() }
        publish()
        logProblem = nil
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        log = try? FileHandle(forWritingTo: logURL)
        write(.start(date))
        write(.vehicle(vehicle))
        write(.device(device))
        if ready {
            write(.ready)
            watchStandstill(since: date)
        }
        startUpdates()
        if let recording { activity.start(recording) }
    }

    /// Continues the recording that was not finished.
    func continueUnfinished() {
        guard let unfinished, recording == nil else { return }
        recording = unfinished
        self.unfinished = nil
        logProblem = nil
        log = try? FileHandle(forWritingTo: logURL)
        _ = try? log?.seekToEnd()
        // The time in between is a gap, not riding.
        if recording?.isPaused == false {
            recording?.pause()
            write(.pause)
        }
        recording?.resume()
        write(.resume)
        publish()
        startUpdates()
        if let recording { activity.start(recording) }
    }

    func pause() {
        guard recording?.isPaused == false else { return }
        recording?.pause()
        write(.pause)
        publish()
        motion?.record(event: "pause")
        if let recording { activity.update(recording, force: true) }
    }

    func resume() {
        guard recording?.isPaused == true else { return }
        recording?.resume()
        write(.resume)
        publish()
        motion?.record(event: "resume")
        if let recording { activity.update(recording, force: true) }
    }

    /// Ends “Ready” without a ride (B-311): nothing was recorded, so nothing is asked or kept.
    func cancelReady() {
        guard recording?.isReady == true else { return }
        _ = stop()
    }

    /// Ends an auto-started ride by itself (B-339): from the automation when the connection ends, or
    /// after standing still. Under 500 m it is thrown away; else it is saved with the device and the
    /// places at start and end as its name, and a notification says so.
    func endAutomatically() async {
        guard isAutoStarted else { return }
        await endAndSave(keepsShort: false)
    }

    /// Ends the ride and saves it without the sheet “Save Ride”: from CarPlay (B-327), where nobody
    /// should type, and for an automatic end. `keepsShort`: a ride under 500 m is saved too (a
    /// deliberate end); else it is thrown away (B-339). A recording without a position is dropped.
    func endAndSave(keepsShort: Bool = true) async {
        guard let recording, !isEndingAutomatically else { return }
        guard !recording.isReady, keepsShort ? recording.pointCount > 0 : AutoStart.keeps(recording) else {
            _ = stop()
            return
        }
        isEndingAutomatically = true
        defer { isEndingAutomatically = false }
        let name = await RideNaming.suggested(for: recording)
        // What was recorded while the names were looked up belongs to the ride too.
        guard let final = self.recording, autoSave(final, name) else { return }
        _ = stop()
        RideSavedNotice.post(name: name, distance: final.distance)
    }

    /// Checks every 30 s, also while no positions come (iOS pauses them for a parked car).
    private func watchStandstill(since date: Date) {
        isAutoStarted = true
        var limit = TimeInterval(AutoStartSettings.standstillMinutes * 60)
        #if DEBUG
        // `-WattspurDemoStandstillSeconds 40`: a short standstill for the simulator.
        let seconds = UserDefaults.standard.integer(forKey: "WattspurDemoStandstillSeconds")
        if seconds > 0 { limit = TimeInterval(seconds) }
        #endif
        standstill = AutoStart.Standstill(limit: limit, since: date)
        standstillCheck?.cancel()
        standstillCheck = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.checkStandstill()
            }
        }
    }

    private func checkStandstill() async {
        guard let standstill, standstill.isOver(at: .now) else { return }
        if recording?.isReady == true {
            // Nobody drove off: “Ready” ends without a ride.
            cancelReady()
        } else if AutoStartSettings.endsAfterStandstill {
            await endAutomatically()
        }
    }

    /// Ends the recording and hands it back; the log is removed.
    func stop() -> RideRecording? {
        endRequested = false
        isAutoStarted = false
        standstill = nil
        standstillCheck?.cancel()
        standstillCheck = nil
        let finished = recording ?? unfinished
        stopUpdates()
        activity.end(recording)
        recording = nil
        latestMovement = nil
        movement = nil
        unfinished = nil
        publish()
        try? log?.close()
        log = nil
        try? FileManager.default.removeItem(at: logURL)
        return finished
    }

    // MARK: - Location

    private func startUpdates() {
        // Both sessions must start while the app is in front: the service session asks for
        // “While Using”, the background session keeps the updates coming when the screen is locked.
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundSession = CLBackgroundActivitySession()
        startBarometer()
        diagnostics = RecordingDiagnostics(start: .now)
        if let recording {
            let motion = MotionRecorder()
            motion.start(at: .now, vehicle: recording.vehicle, rawLog: MotionRecorder.writesRawLog)
            self.motion = motion
        }
        updates = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    guard let self, self.recording != nil else { break }
                    self.handle(update)
                }
            } catch {
                self?.status = error.localizedDescription
            }
        }
    }

    private func stopUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
        barometer.reset()
        diagnostics?.stop(isVisible: isVisible)
        diagnostics = nil
        motion?.stop()
        motion = nil
        updates?.cancel()
        updates = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
    }

    private func handle(_ update: CLLocationUpdate) {
        defer { publish() }
        let newStatus: String? = if update.authorizationDenied || update.authorizationDeniedGlobally {
            String(localized: "Location access denied")
        } else if update.accuracyLimited {
            String(localized: "Only approximate location allowed")
        } else if update.locationUnavailable {
            String(localized: "No location at the moment")
        } else {
            nil
        }
        if status != newStatus { status = newStatus }
        let wasReady = recording?.isReady == true
        var pressure: Double?
        if let location = update.location {
            pressure = barometer.metres(at: location.timestamp)
            diagnostics?.position(measured: location.timestamp, hasBarometer: pressure != nil, isVisible: isVisible)
            latestMovement = Movement(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                                course: location.course, courseAccuracy: location.courseAccuracy, speed: location.speed)
            motion?.record(location)
            // While paused or ready the motion is not part of the ride: the interval starts afresh.
            if recording?.isPaused == true || wasReady {
                _ = motion?.values(at: location)
                droppedMotion = nil
            }
        }
        guard let location = update.location, recording?.isPaused == false else { return }
        let altitude = fusion.altitude(gps: location.verticalAccuracy > 0 ? location.altitude : nil,
                                       verticalAccuracy: location.verticalAccuracy, barometer: pressure,
                                       at: location.timestamp)
        var fix = RideRecording.Fix(date: location.timestamp,
                                    latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude,
                                    altitude: altitude,
                                    horizontalAccuracy: location.horizontalAccuracy,
                                    speed: location.speed >= 0 ? location.speed : nil)
        // The motion since the point before; a dropped point hands its values on to the next one.
        let values = motion?.values(at: location)
        fix.motion = droppedMotion.map { $0.merged(with: values) } ?? values
        if wasReady { takeConnectedDevice() }
        standstill?.record(fix)
        if standstill?.isOver(at: fix.date) == true { Task { await checkStandstill() } }
        if recording?.add(fix) == true {
            droppedMotion = nil
            write(.fix(fix))
            // When the ride begins (B-311) its time counts from now; the Live Activity takes that in an
            // update, as an app in the background may not start a new one (B-370).
            if let recording { activity.update(recording, force: wasReady) }
        } else {
            droppedMotion = fix.motion
        }
    }

    /// While ready the connection may still come: the audio route follows CarPlay or the headset a
    /// moment after the automation ran (B-370). Its device then replaces the last vehicle.
    private func takeConnectedDevice() {
        guard let connected = AutoStartSettings.deviceForConnection(devices: RecordingChoice.cachedDevices),
              connected != recording?.device else { return }
        recording?.device = connected
        RecordingChoice.last = connected
        write(.vehicle(connected.vehicle))
        write(.device(connected))
        motion?.stop()
        let motion = MotionRecorder()
        motion.start(at: .now, vehicle: connected.vehicle, rawLog: MotionRecorder.writesRawLog)
        self.motion = motion
        droppedMotion = nil
        if let recording {
            shown = recording
            activity.update(recording, force: true)
        }
    }

    // MARK: - Barometer (B-235)

    /// The relative height since this start; a new start (or continuing after a crash) begins at 0,
    /// and the fusion finds the GPS level again.
    private func startBarometer() {
        fusion = AltitudeFusion()
        barometer.reset()
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        // With a barometer that may be used, the first seconds wait for it instead of starting
        // with the GPS height (the first point of a test on 5.11.2026).
        let access = CMAltimeter.authorizationStatus()
        fusion.waitsForBarometer = access != .denied && access != .restricted
        barometer.receive(from: altimeter)
    }

    /// `FileHandle.write(_:)` raises an Objective-C exception on an error, which ends the app in the
    /// middle of a ride (R-52); the throwing variant lets the recording go on.
    private func write(_ event: RecordingLog.Event) {
        guard let log else { return }
        do {
            try log.write(contentsOf: RecordingLog.line(event))
            // Written only when it changes: every write would tell the screen (B-369).
            if logProblem != nil { logProblem = nil }
        } catch {
            if logProblem == nil { logProblem = String(localized: "Storage full: the ride is not backed up") }
        }
    }
}
