import Foundation

/// Finds rides that probably belong together, e.g. one tour the eBike recorded
/// as two rides because it was switched off at a café (B-096, LIST-10).
///
/// Only a suggestion: nothing is merged without the user's confirmation.
public enum RideMergeSuggestion {
    /// Default for "gap between two rides", in minutes; adjustable in the settings.
    public static let defaultGapMinutes = 60
    /// How far the end of one ride may be from the start of the next, in metres.
    public static let maxDistance = 1_000.0

    /// A position, in degrees.
    public typealias Coordinate = (latitude: Double, longitude: Double)

    /// One ride (or merged ride) to look at. Positions are looked up only when
    /// the times fit, because decoding the time series is the expensive part.
    public struct Entry {
        public var id: UUID
        public var start: Date
        public var end: Date
        public var timeZone: TimeZone
        public var startCoordinate: () -> Coordinate?
        public var endCoordinate: () -> Coordinate?

        public init(id: UUID, start: Date, end: Date, timeZone: TimeZone = .current,
                    startCoordinate: @escaping () -> Coordinate? = { nil },
                    endCoordinate: @escaping () -> Coordinate? = { nil }) {
            self.id = id
            self.start = start
            self.end = end
            self.timeZone = timeZone
            self.startCoordinate = startCoordinate
            self.endCoordinate = endCoordinate
        }
    }

    /// Rides that probably belong together, oldest first.
    public struct Group: Sendable, Equatable {
        public var rideIDs: [UUID]
        /// Start of the first ride, to name the day.
        public var start: Date
        public var timeZone: TimeZone
    }

    /// Groups of two or more consecutive rides: each starts on the same day as
    /// the previous one ended, no later than `maxGap` after it, and not
    /// farther than `maxDistance` from where it ended (if both positions are
    /// known). Overlapping rides are never suggested.
    public static func groups(in entries: [Entry], maxGap: TimeInterval = TimeInterval(defaultGapMinutes * 60),
                              maxDistance: Double = maxDistance) -> [Group] {
        guard maxGap > 0 else { return [] }
        let sorted = entries.sorted { $0.start < $1.start }
        var groups: [Group] = []
        var current: [Entry] = []

        func flush() {
            if current.count >= 2, let first = current.first {
                groups.append(Group(rideIDs: current.map(\.id), start: first.start, timeZone: first.timeZone))
            }
            current = []
        }

        for entry in sorted {
            if let previous = current.last, follows(entry, previous, maxGap: maxGap, maxDistance: maxDistance) {
                current.append(entry)
            } else {
                flush()
                current = [entry]
            }
        }
        flush()
        return groups
    }

    private static func follows(_ next: Entry, _ previous: Entry, maxGap: TimeInterval, maxDistance: Double) -> Bool {
        let gap = next.start.timeIntervalSince(previous.end)
        guard gap >= 0, gap <= maxGap else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = previous.timeZone
        guard calendar.isDate(previous.start, inSameDayAs: next.start) else { return false }
        guard let end = previous.endCoordinate(), let start = next.startCoordinate() else { return true }
        return distance(end, start) <= maxDistance
    }

    /// Great-circle distance in metres.
    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let radius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, h.squareRoot()))
    }
}
