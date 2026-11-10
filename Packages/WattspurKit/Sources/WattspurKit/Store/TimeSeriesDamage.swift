import Foundation
import os
import Synchronization

/// Rides whose stored time series cannot be read (B-268, R-32). Before, such a ride just showed an
/// empty map and empty charts, and the maintenance reckoned its stored values anew from an empty
/// list. Now a failed read is written to the log, noted here for the diagnostic report, and the
/// stored values (route for the map of all rides, best minute, curviness, steepest climb) stay.
public enum TimeSeriesDamage {
    private static let found = Mutex<Set<UUID>>([])
    private static let log = Logger(subsystem: "io.github.hops-1.wattspur", category: "TimeSeries")

    /// Notes a ride whose time series could not be read; logs it once per ride.
    public static func note(_ rideID: UUID, error: any Error) {
        let isNew = found.withLock { $0.insert(rideID).inserted }
        if isNew { log.error("Time series of ride \(rideID, privacy: .public) cannot be read: \(String(describing: error), privacy: .public)") }
    }

    /// How many rides with an unreadable time series were met since the app started.
    public static var count: Int { found.withLock { $0.count } }

    public static func contains(_ rideID: UUID) -> Bool { found.withLock { $0.contains(rideID) } }

    /// Decodes a stored time series: `[]` without data, `nil` when data is there but cannot be read.
    nonisolated public static func decode(_ data: Data?) -> Result<[RideSample], any Error> {
        guard let data else { return .success([]) }
        return Result { try PropertyListDecoder().decode([RideSample].self, from: data) }
    }

    /// Only for tests.
    static func reset() { found.withLock { $0.removeAll() } }
}
