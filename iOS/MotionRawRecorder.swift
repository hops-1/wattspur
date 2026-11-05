import CoreLocation
import CoreMotion
import Foundation
import UIKit
import WattspurCore

/// Spike V-16: writes the raw device motion (50 Hz) and every GPS update into a CSV file while the
/// test switch in “More” is on (`MotionRawLog`). The file lands in the documents folder
/// “Bewegung”, which the Files app shows under “On My iPhone › Wattspur”; it is not part of the
/// ride and is never synced.
///
/// Device motion needs no permission and keeps coming while the location updates keep the app
/// running in the background. All file work happens on one serial queue; rows are collected and
/// written about once a second.
final class MotionRawRecorder: @unchecked Sendable {
    /// The test switch in “More”.
    static let enabledKey = "recordRawMotion"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Wattspur raw motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()
    // Touched only on `queue`.
    private var file: FileHandle?
    private var buffer = ""
    private var lastFlush = Date.distantPast
    /// Reads the battery level once a minute; `UIDevice` is only used on the main actor.
    private var batteryTask: Task<Void, Never>?
    /// Seconds between the device's uptime clock (motion timestamps) and the wall clock.
    private let bootDate = Date.now.addingTimeInterval(-ProcessInfo.processInfo.systemUptime)

    /// Opens a new file named after `date` and starts the motion updates; does nothing if the
    /// device has no motion sensors or the file cannot be made.
    @MainActor func start(at date: Date, vehicle: RecordingVehicle) {
        guard manager.isDeviceMotionAvailable else { return }
        let folder = URL.documentsDirectory.appending(path: MotionRawLog.folderName)
        let url = folder.appending(path: MotionRawLog.fileName(for: date))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let handle = try FileHandle(forWritingTo: url)
            queue.addOperation { [self] in
                file = handle
                buffer = MotionRawLog.header + "\n"
                append(MotionRawLog.event("start", at: date))
                append(MotionRawLog.event(vehicle.rawValue, at: date))
            }
        } catch {
            return
        }
        manager.deviceMotionUpdateInterval = 1 / MotionRawLog.rate
        manager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.append(MotionRawLog.line(Self.reading(motion, bootDate: self.bootDate)))
        }
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let level = Double(UIDevice.current.batteryLevel)
                if level >= 0 {
                    let row = MotionRawLog.battery(level, at: .now)
                    self?.queue.addOperation { [weak self] in self?.append(row) }
                }
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// Every location update, also while paused or when the recording drops it.
    func record(_ location: CLLocation) {
        let row = MotionRawLog.line(MotionRawLog.Location(
            date: location.timestamp,
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy, verticalAccuracy: location.verticalAccuracy,
            speed: location.speed, course: location.course))
        queue.addOperation { [self] in append(row) }
    }

    func record(event name: String, at date: Date = .now) {
        let row = MotionRawLog.event(name, at: date)
        queue.addOperation { [self] in append(row) }
    }

    @MainActor func stop() {
        batteryTask?.cancel()
        batteryTask = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
        manager.stopDeviceMotionUpdates()
        let row = MotionRawLog.event("stop", at: .now)
        queue.addOperation { [self] in
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
