import CoreMotion
import Foundation
import Synchronization
import WattspurCore

/// Keeps the barometer's readings by the time they were measured (B-369). They arrive on their own
/// queue, so they keep coming when the main thread is busy, and a GPS position handled late still
/// finds the reading of its own second.
final class Barometer: Sendable {
    private let history = Mutex(BarometerHistory())
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Wattspur barometer"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    func reset() {
        history.withLock { $0 = BarometerHistory() }
    }

    func metres(at date: Date) -> Double? {
        history.withLock { $0.metres(at: date) }
    }

    // Not on the main actor on purpose, like the motion's closures (MotionRecorder): the queue runs them.
    nonisolated func receive(from altimeter: CMAltimeter) {
        altimeter.startRelativeAltitudeUpdates(to: queue) { @Sendable [weak self] data, _ in
            guard let self, let data else { return }
            // The reading's time counts since the iPhone started; its age gives the clock time.
            let age = max(0, ProcessInfo.processInfo.systemUptime - data.timestamp)
            let date = Date.now.addingTimeInterval(-age)
            let metres = data.relativeAltitude.doubleValue
            self.history.withLock { $0.add(metres: metres, at: date) }
        }
    }
}
