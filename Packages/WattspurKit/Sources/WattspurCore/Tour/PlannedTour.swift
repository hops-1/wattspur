import Foundation

/// A tour planned before it is ridden, e.g. in komoot (B-372): a line with heights, no times.
///
/// It comes from a GPX file (`PlannedTourReader`) and is stored by the Kit as `PlannedRoute`.
/// Distance and ascent are worked out once from the points, the same way on every device.
public struct PlannedTour: Sendable, Equatable {
    /// One point of the line.
    public struct Point: Sendable, Equatable {
        public var latitude: Double
        public var longitude: Double
        /// Metres; `nil` where the file has no height.
        public var altitude: Double?

        public init(latitude: Double, longitude: Double, altitude: Double? = nil) {
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
        }
    }

    /// Where the tour was planned, as far as the file says.
    public enum Source: String, Sendable, Equatable, CaseIterable {
        /// A GPX file from komoot (`creator` names komoot).
        case komoot
        /// Any other GPX file.
        case gpx
    }

    /// `trk/name`, `rte/name` or `metadata/name`; `nil` if the file has none.
    public var name: String?
    public var points: [Point]
    public var source: Source
    /// Metres along the line.
    public var distance: Double
    /// Whole metres up and down from the smoothed heights; `nil` without heights.
    public var ascent: Int?
    public var descent: Int?

    /// Start and end this close together make a loop, in metres.
    public static let loopDistance = 200.0

    public init(name: String?, points: [Point], source: Source) {
        self.name = name
        self.points = points
        self.source = source
        distance = Self.length(of: points)
        let climb = Self.climb(of: points)
        ascent = climb?.up
        descent = climb?.down
    }

    /// `true` when the tour ends where it starts.
    public var isLoop: Bool {
        guard points.count > 2, let first = points.first, let last = points.last else { return false }
        return GPXGeo.distance(first.latitude, first.longitude, last.latitude, last.longitude) <= Self.loopDistance
    }

    /// What makes two imports of the same file the same tour, on every device alike: the number of
    /// points, the length to the metre and the first and last point to about a metre. Used for
    /// duplicates on import and after the sync.
    public var contentKey: String {
        guard let first = points.first, let last = points.last else { return "" }
        func spot(_ p: Point) -> String { String(format: "%.5f,%.5f", p.latitude, p.longitude) }
        return "\(points.count)|\(Int(distance.rounded()))|\(spot(first))|\(spot(last))"
    }

    // MARK: - Figures

    static func length(of points: [Point]) -> Double {
        zip(points, points.dropFirst()).reduce(0) {
            $0 + GPXGeo.distance($1.0.latitude, $1.0.longitude, $1.1.latitude, $1.1.longitude)
        }
    }

    /// Like a GPX ride (`GPXTrack.totals`): median of 5 heights, a change counts from 2 m.
    static func climb(of points: [Point]) -> (up: Int, down: Int)? {
        let heights = points.compactMap(\.altitude)
        guard heights.count >= 2 else { return nil }
        let parameters = GPXSummaryParameters.standard
        let counted = GPXTrack.climb(GPXTrack.median(heights, points: parameters.altitudeMedianPoints),
                                     threshold: parameters.ascentThreshold)
        return (Int(counted.up.rounded()), Int(counted.down.rounded()))
    }

    // MARK: - Storage

    /// The points as compact bytes for the store: a version byte, then per point latitude,
    /// longitude and height (NaN for none) as little-endian 64-bit floats.
    public static func encode(_ points: [Point]) -> Data {
        var data = Data([encodingVersion])
        data.reserveCapacity(1 + points.count * 24)
        for point in points {
            for value in [point.latitude, point.longitude, point.altitude ?? .nan] {
                withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    /// The points from `encode(_:)`; `nil` for bytes of another version or a broken length.
    public static func decodePoints(_ data: Data) -> [Point]? {
        guard let version = data.first, version == encodingVersion, (data.count - 1) % 24 == 0 else { return nil }
        let bytes = [UInt8](data.dropFirst())
        var points: [Point] = []
        points.reserveCapacity(bytes.count / 24)
        func value(at offset: Int) -> Double {
            var bits: UInt64 = 0
            for i in 0..<8 { bits |= UInt64(bytes[offset + i]) << (8 * UInt64(i)) }
            return Double(bitPattern: bits)
        }
        var offset = 0
        while offset < bytes.count {
            let altitude = value(at: offset + 16)
            points.append(Point(latitude: value(at: offset), longitude: value(at: offset + 8),
                                altitude: altitude.isNaN ? nil : altitude))
            offset += 24
        }
        return points
    }

    static let encodingVersion: UInt8 = 1
}
