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
@MainActor @Observable
final class Recorder {
    /// The ride being recorded; `nil` when nothing is recorded.
    private(set) var recording: RideRecording?
    /// A recording found at launch that was not finished (crash, app killed).
    private(set) var unfinished: RideRecording?
    /// What the location service reported last, e.g. “Location access denied”.
    private(set) var status: String?

    var isRecording: Bool { recording != nil }
    /// Siri or a shortcut asked to end the ride (B-225): the recording screen opens “Save Ride”.
    var endRequested = false

    /// What is recorded, chosen in “More”; a motorcycle keeps speeds above 100 km/h.
    static let vehicleKey = "recordingVehicle"
    static var vehicle: RecordingVehicle {
        UserDefaults.standard.string(forKey: vehicleKey).flatMap(RecordingVehicle.init(rawValue:)) ?? .eBike
    }

    private var updates: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?
    private var log: FileHandle?
    private let logURL: URL
    /// The barometer (B-235); every iPhone with iOS 26 has one, but motion access may be denied.
    private let altimeter = CMAltimeter()
    private var barometer: (metres: Double, date: Date)?
    private var fusion = AltitudeFusion()
    /// A barometer reading older than this is not used; the GPS height stands in.
    private static let barometerMaxAge: TimeInterval = 5
    /// Lean angle, acceleration and roughness (B-245), and the raw motion of spike V-16 while the
    /// test switch in “More” is on.
    private var motion: MotionRecorder?
    /// The motion values of GPS points the recording dropped, for the next point it keeps.
    private var droppedMotion: MotionValues?
    /// The Live Activity on the Lock Screen and in the Dynamic Island (B-223).
    private let activity = RecordingActivityController()

    /// The log lives in Application Support: the documents are shown in the Files app.
    init(logURL: URL = .applicationSupportDirectory.appending(path: "Aufnahme.jsonl")) {
        self.logURL = logURL
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: logURL), let recording = RecordingLog.replay(data) {
            unfinished = recording
        }
        // Pause and Resume from the Live Activity (B-223).
        RecordingControl.togglePause = { [weak self] in
            guard let self, let recording = self.recording else { return }
            if recording.isPaused { self.resume() } else { self.pause() }
        }
    }

    func start(at date: Date = .now) {
        guard recording == nil else { return }
        unfinished = nil
        let vehicle = Self.vehicle
        recording = RideRecording(startDate: date, vehicle: vehicle)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        log = try? FileHandle(forWritingTo: logURL)
        write(.start(date))
        write(.vehicle(vehicle))
        startUpdates()
        if let recording { activity.start(recording) }
    }

    /// Continues the recording that was not finished.
    func continueUnfinished() {
        guard let unfinished, recording == nil else { return }
        recording = unfinished
        self.unfinished = nil
        log = try? FileHandle(forWritingTo: logURL)
        _ = try? log?.seekToEnd()
        // The time in between is a gap, not riding.
        if recording?.isPaused == false {
            recording?.pause()
            write(.pause)
        }
        recording?.resume()
        write(.resume)
        startUpdates()
        if let recording { activity.start(recording) }
    }

    func pause() {
        guard recording?.isPaused == false else { return }
        recording?.pause()
        write(.pause)
        motion?.record(event: "pause")
        if let recording { activity.update(recording, force: true) }
    }

    func resume() {
        guard recording?.isPaused == true else { return }
        recording?.resume()
        write(.resume)
        motion?.record(event: "resume")
        if let recording { activity.update(recording, force: true) }
    }

    /// Ends the recording and hands it back; the log is removed.
    func stop() -> RideRecording? {
        endRequested = false
        let finished = recording ?? unfinished
        stopUpdates()
        activity.end(recording)
        recording = nil
        unfinished = nil
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
        barometer = nil
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
        if update.authorizationDenied || update.authorizationDeniedGlobally {
            status = String(localized: "Location access denied")
        } else if update.accuracyLimited {
            status = String(localized: "Only approximate location allowed")
        } else if update.locationUnavailable {
            status = String(localized: "No location at the moment")
        } else {
            status = nil
        }
        if let location = update.location {
            motion?.record(location)
            // While paused the motion is not part of the ride: the interval starts afresh.
            if recording?.isPaused == true {
                _ = motion?.values(at: location)
                droppedMotion = nil
            }
        }
        guard let location = update.location, recording?.isPaused == false else { return }
        let fresh = barometer.flatMap { abs($0.date.timeIntervalSince(location.timestamp)) <= Self.barometerMaxAge ? $0.metres : nil }
        let altitude = fusion.altitude(gps: location.verticalAccuracy > 0 ? location.altitude : nil,
                                       verticalAccuracy: location.verticalAccuracy, barometer: fresh,
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
        if recording?.add(fix) == true {
            droppedMotion = nil
            write(.fix(fix))
            if let recording { activity.update(recording) }
        } else {
            droppedMotion = fix.motion
        }
    }

    // MARK: - Barometer (B-235)

    /// The relative height since this start; a new start (or continuing after a crash) begins at 0,
    /// and the fusion finds the GPS level again.
    private func startBarometer() {
        fusion = AltitudeFusion()
        barometer = nil
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        // With a barometer that may be used, the first seconds wait for it instead of starting
        // with the GPS height (the first point of a test on 5.11.2026).
        let access = CMAltimeter.authorizationStatus()
        fusion.waitsForBarometer = access != .denied && access != .restricted
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let metres = data.relativeAltitude.doubleValue
            MainActor.assumeIsolated {
                self?.barometer = (metres, .now)
            }
        }
    }

    private func write(_ event: RecordingLog.Event) {
        log?.write(RecordingLog.line(event))
    }
}
