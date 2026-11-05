import CoreLocation
import CoreMotion
import Foundation
import Synchronization
import UIKit
import WattspurCore

/// Reads the motion sensors while recording (B-245): device motion at 50 Hz goes into a
/// `MotionFusion`, and each GPS point takes the lean angle, acceleration and roughness since the
/// point before (`values(at:)`). Device motion needs no permission and keeps coming while the
/// location updates keep the app running in the background. Without motion sensors the recording
/// goes on as before, without these values.
///
/// With the test switch in “More” on (spike V-16) it also writes every reading and every GPS update
/// into a CSV file (`MotionRawLog`) in the documents folder “Bewegung”, which the Files app shows
/// under “On My iPhone › Wattspur”; the file is not part of the ride and is never synced.
///
/// The readings arrive on one serial queue, which also does the file work; rows are collected and
/// written about once a second. The fusion sits behind a lock, as the GPS points come on the main actor.
final class MotionRecorder: @unchecked Sendable {
    /// The test switch in “More”.
    static let rawLogKey = "recordRawMotion"
    static var writesRawLog: Bool { UserDefaults.standard.bool(forKey: rawLogKey) }

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Wattspur motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()
    private let fusion = Mutex(MotionFusion())
    // Touched only on `queue`.
    private var file: FileHandle?
    private var buffer = ""
    private var lastFlush = Date.distantPast
    /// Set on the main actor at the start: the raw log is written.
    @MainActor private var writesRaw = false
    /// Reads the battery level once a minute for the raw log; `UIDevice` is only used on the main actor.
    private var batteryTask: Task<Void, Never>?
    /// Seconds between the device's uptime clock (motion timestamps) and the wall clock.
    private let bootDate = Date.now.addingTimeInterval(-ProcessInfo.processInfo.systemUptime)

    /// Starts the motion updates; with `rawLog` also a new raw file named after `date`. Does nothing
    /// if the device has no motion sensors.
    @MainActor func start(at date: Date, vehicle: RecordingVehicle, rawLog: Bool) {
        guard manager.isDeviceMotionAvailable else { return }
        if rawLog, let handle = Self.makeFile(for: date) {
            writesRaw = true
            open(handle, at: date, vehicle: vehicle)
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    let level = Double(UIDevice.current.batteryLevel)
                    if level >= 0 { self?.enqueue(MotionRawLog.battery(level, at: .now)) }
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
        startMotion()
    }

    /// The values since the GPS point before; `nil` without readings in between. Called for each
    /// kept GPS point.
    func values(at location: CLLocation) -> MotionValues? {
        fusion.withLock { $0.close(at: location.timestamp, speed: location.speed) }
    }

    /// Every location update for the raw log, also while paused or when the recording drops it.
    @MainActor func record(_ location: CLLocation) {
        guard writesRaw else { return }
        enqueue(MotionRawLog.line(MotionRawLog.Location(
            date: location.timestamp,
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: location.verticalAccuracy,
            speed: location.speed, course: location.course)))
    }

    @MainActor func record(event name: String, at date: Date = .now) {
        guard writesRaw else { return }
        enqueue(MotionRawLog.event(name, at: date))
    }

    @MainActor func stop() {
        writesRaw = false
        if batteryTask != nil {
            batteryTask?.cancel()
            batteryTask = nil
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
        manager.stopDeviceMotionUpdates()
        close(MotionRawLog.event("stop", at: .now))
    }

    private static func makeFile(for date: Date) -> FileHandle? {
        let folder = URL.documentsDirectory.appending(path: MotionRawLog.folderName)
        let url = folder.appending(path: MotionRawLog.fileName(for: date))
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try? FileHandle(forWritingTo: url)
    }

    // MARK: - Handing work to the queue
    //
    // These are not on the main actor on purpose: a closure made inside a `@MainActor` method is
    // isolated to the main actor too, and Swift stops the app when the queue then runs it on
    // another thread (crash of the test build 0.5.1 (6) on 5.11.2026, `dispatch_assert_queue`).

    private nonisolated func open(_ handle: FileHandle, at date: Date, vehicle: RecordingVehicle) {
        queue.addOperation { @Sendable [self] in
            file = handle
            buffer = MotionRawLog.header + "\n"
            append(MotionRawLog.event("start", at: date))
            append(MotionRawLog.event(vehicle.rawValue, at: date))
        }
    }

    private nonisolated func startMotion() {
        manager.deviceMotionUpdateInterval = 1 / MotionRawLog.rate
        manager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { @Sendable [weak self] motion, _ in
            guard let self, let motion else { return }
            let reading = Self.reading(motion, bootDate: self.bootDate)
            self.fusion.withLock { $0.add(reading) }
            if self.file != nil { self.append(MotionRawLog.line(reading)) }
        }
    }

    private nonisolated func enqueue(_ row: String) {
        queue.addOperation { @Sendable [self] in append(row) }
    }

    private nonisolated func close(_ row: String) {
        queue.addOperation { @Sendable [self] in
            guard file != nil else { return }
            append(row)
            flush()
            try? file?.close()
            file = nil
        }
    }

    // MARK: - On the queue

    private func append(_ row: String) {
        guard file != nil else { return }
        buffer += row
        if Date.now.timeIntervalSince(lastFlush) >= 1 { flush() }
    }

    private func flush() {
        lastFlush = .now
        guard !buffer.isEmpty else { return }
        try? file?.write(contentsOf: Data(buffer.utf8))
        buffer = ""
    }

    private static func reading(_ motion: CMDeviceMotion, bootDate: Date) -> MotionRawLog.Motion {
        let q = motion.attitude.quaternion
        let g = motion.gravity
        let a = motion.userAcceleration
        let r = motion.rotationRate
        return MotionRawLog.Motion(date: bootDate.addingTimeInterval(motion.timestamp),
                                   quaternion: (q.x, q.y, q.z, q.w),
                                   gravity: (g.x, g.y, g.z),
                                   acceleration: (a.x, a.y, a.z),
                                   rotation: (r.x, r.y, r.z))
    }
}
