import CoreLocation
import Foundation
import Observation
import UIKit
import WattspurCore

/// Records a ride with GPS (B-211): `CLLocationUpdate.liveUpdates(.fitness)` with a
/// `CLBackgroundActivitySession`, so it goes on with the screen locked (spike V-14). Every event
/// goes into a log file at once; after a crash the app offers to continue or finish the ride.
@MainActor @Observable
final class Recorder {
    /// The ride being recorded; `nil` when nothing is recorded.
    private(set) var recording: RideRecording?
    /// A recording found at launch that was not finished (crash, app killed).
    private(set) var unfinished: RideRecording?
    /// What the location service reported last, e.g. “Location access denied”.
    private(set) var status: String?

    var isRecording: Bool { recording != nil }

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

    /// The log lives in Application Support: the documents are shown in the Files app.
    init(logURL: URL = .applicationSupportDirectory.appending(path: "Aufnahme.jsonl")) {
        self.logURL = logURL
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: logURL), let recording = RecordingLog.replay(data) {
            unfinished = recording
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
    }

    func pause() {
        guard recording?.isPaused == false else { return }
        recording?.pause()
        write(.pause)
    }

    func resume() {
        guard recording?.isPaused == true else { return }
        recording?.resume()
        write(.resume)
    }

    /// Ends the recording and hands it back; the log is removed.
    func stop() -> RideRecording? {
        let finished = recording ?? unfinished
        stopUpdates()
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
        guard let location = update.location, recording?.isPaused == false else { return }
        let fix = RideRecording.Fix(date: location.timestamp,
                                    latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude,
                                    altitude: location.verticalAccuracy > 0 ? location.altitude : nil,
                                    horizontalAccuracy: location.horizontalAccuracy,
                                    speed: location.speed >= 0 ? location.speed : nil)
        if recording?.add(fix) == true {
            write(.fix(fix))
        }
    }

    private func write(_ event: RecordingLog.Event) {
        log?.write(RecordingLog.line(event))
    }
}
