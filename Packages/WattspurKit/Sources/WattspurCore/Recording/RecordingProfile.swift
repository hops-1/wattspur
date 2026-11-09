import Foundation

/// The height or speed profile of the recording so far (B-277), over the distance, for the small chart
/// on the recording screen. At most `bins` points however long the ride is, so the chart stays light
/// after hours: each point is the mean of the values in its stretch of the distance.
public enum RecordingProfile {
    public enum Kind: String, CaseIterable, Sendable {
        case elevation, speed
    }

    public struct Point: Sendable, Equatable, Identifiable {
        /// Metres from the start.
        public var distance: Double
        /// Metres above sea level, or metres per second.
        public var value: Double
        public var id: Double { distance }
    }

    public static let defaultBins = 150

    /// The profile of `recording`; empty until there are values. Pauses leave no gap in the distance
    /// (the distance does not grow while paused).
    public static func points(_ recording: RideRecording, kind: Kind, bins: Int = defaultBins) -> [Point] {
        let total = recording.distance
        var sums = [Double](repeating: 0, count: max(bins, 1))
        var counts = [Int](repeating: 0, count: max(bins, 1))
        for segment in recording.segments {
            for point in segment {
                let value: Double?
                switch kind {
                case .elevation: value = point.fix.altitude
                case .speed: value = point.fix.speed
                }
                guard let value else { continue }
                let index = total > 0 ? min(sums.count - 1, Int(point.distance / total * Double(sums.count))) : 0
                sums[index] += value
                counts[index] += 1
            }
        }
        let width = total / Double(sums.count)
        return sums.indices.compactMap { index in
            guard counts[index] > 0 else { return nil }
            return Point(distance: (Double(index) + 0.5) * width, value: sums[index] / Double(counts[index]))
        }
    }
}
