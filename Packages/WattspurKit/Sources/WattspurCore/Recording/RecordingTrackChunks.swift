import Foundation

/// The recording map draws the track in pieces (B-365). Before, every fix replaced the one line of
/// the whole ride, so MapKit drew every tile of a long car ride anew each second: heat and memory
/// (two watchdog kills on 21.11.2026). Now only the last piece changes; the others stay as they are.
public enum RecordingTrackChunks {
    /// Points per piece: with a point every 10 m (`RideRecording.route`) about 5 km.
    public static let size = 500

    /// The index ranges of the pieces of a line with `count` points. Each piece starts at the last
    /// point of the one before, so the line has no gap; adding a point changes only the last range.
    public static func ranges(count: Int, size: Int = size) -> [Range<Int>] {
        guard count > 0, size > 1 else { return count > 0 ? [0..<count] : [] }
        var ranges: [Range<Int>] = []
        var start = 0
        repeat {
            let end = min(start + size, count)
            ranges.append(start..<end)
            start = end - 1
        } while start + 1 < count
        return ranges
    }
}

/// How often the recording map may be drawn again (B-365): with every fix normally; a coloured
/// track is worked out from the whole ride, so at most every few seconds; and when the iPhone is
/// hot (`ProcessInfo.thermalState` serious or critical) even less, so the ride's own work does not
/// add to the heat.
public enum RecordingMapPace {
    public static let colouredInterval: TimeInterval = 5
    public static let hotInterval: TimeInterval = 15

    public static func interval(thermal: ProcessInfo.ThermalState, plain: Bool) -> TimeInterval {
        switch thermal {
        case .serious, .critical: hotInterval
        default: plain ? 0 : colouredInterval
        }
    }
}
