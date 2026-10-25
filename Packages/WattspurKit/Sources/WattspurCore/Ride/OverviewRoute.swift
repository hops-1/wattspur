import Foundation

/// The simplified route of a ride for the map of all rides (B-104, AGG-05).
/// One segment per part of a merged ride, so the map draws no line across the
/// gap between two parts. Computed once and stored with the ride.
public struct OverviewRoute: Sendable, Equatable {
    /// Raise when the simplification or the encoding changes; stored routes with
    /// an older version are computed again on the next launch.
    public static let version = 1
    /// Douglas-Peucker tolerance in metres (decided 22.10.2026, Requirements 10.11).
    public static let tolerance = 5.0

    public var segments: [[RoutePoint]]

    public init(segments: [[RoutePoint]]) {
        self.segments = segments.filter { !$0.isEmpty }
    }

    /// Simplifies the GPS positions of a ride's time series into one segment.
    public init(samples: [RideSample], tolerance: Double = Self.tolerance) {
        let points = samples.compactMap { s -> RoutePoint? in
            guard let lat = s.latitude, let lon = s.longitude else { return nil }
            return RoutePoint(latitude: lat, longitude: lon)
        }
        self.init(segments: [RouteSimplifier.simplify(points, tolerance: tolerance)])
    }

    /// Simplifies an encoded time series (`Ride.samplesData`); empty without data.
    public init(samplesData: Data?) {
        let samples = samplesData.flatMap { try? PropertyListDecoder().decode([RideSample].self, from: $0) } ?? []
        self.init(samples: samples)
    }

    /// The parts' routes one after another, each part keeping its own segments.
    public init(joining routes: [OverviewRoute]) {
        self.init(segments: routes.flatMap(\.segments))
    }

    public var isEmpty: Bool { segments.isEmpty }
    public var pointCount: Int { segments.reduce(0) { $0 + $1.count } }

    // MARK: - Encoding

    /// Compact form for SwiftData: degrees × 10⁶ as integers (about 0.1 m), each
    /// point as the difference to the one before, zigzag-encoded into variable
    /// length bytes. A typical ride needs 2 to 4 bytes per coordinate.
    /// Layout: format byte, segment count, then per segment the point count and
    /// the differences (latitude, longitude), starting from 0 for every segment.
    public func encoded() -> Data {
        var data = Data([Self.format])
        Self.appendVarint(UInt64(segments.count), to: &data)
        for segment in segments {
            Self.appendVarint(UInt64(segment.count), to: &data)
            var last = (lat: Int64(0), lon: Int64(0))
            for point in segment {
                let lat = Int64((point.latitude * Self.scale).rounded())
                let lon = Int64((point.longitude * Self.scale).rounded())
                Self.appendVarint(Self.zigzag(lat - last.lat), to: &data)
                Self.appendVarint(Self.zigzag(lon - last.lon), to: &data)
                last = (lat, lon)
            }
        }
        return data
    }

    /// Reads the compact form; `nil` for data in another format or cut short.
    public init?(data: Data) {
        var reader = Reader(bytes: [UInt8](data))
        guard reader.byte() == Self.format, let count = reader.varint(), count <= UInt64(data.count) else { return nil }
        var segments: [[RoutePoint]] = []
        for _ in 0..<count {
            guard let points = reader.varint(), points <= UInt64(data.count) else { return nil }
            var segment: [RoutePoint] = []
            segment.reserveCapacity(Int(points))
            var last = (lat: Int64(0), lon: Int64(0))
            for _ in 0..<points {
                guard let dLat = reader.varint(), let dLon = reader.varint() else { return nil }
                last = (last.lat + Self.unzigzag(dLat), last.lon + Self.unzigzag(dLon))
                segment.append(RoutePoint(latitude: Double(last.lat) / Self.scale, longitude: Double(last.lon) / Self.scale))
            }
            segments.append(segment)
        }
        guard reader.isAtEnd else { return nil }
        self.init(segments: segments)
    }

    private static let format: UInt8 = 1
    private static let scale = 1_000_000.0

    private static func zigzag(_ value: Int64) -> UInt64 {
        UInt64(bitPattern: (value << 1) ^ (value >> 63))
    }

    private static func unzigzag(_ value: UInt64) -> Int64 {
        Int64(bitPattern: value >> 1) ^ -Int64(bitPattern: value & 1)
    }

    private static func appendVarint(_ value: UInt64, to data: inout Data) {
        var value = value
        while value >= 0x80 {
            data.append(UInt8(value & 0x7F) | 0x80)
            value >>= 7
        }
        data.append(UInt8(value))
    }

    private struct Reader {
        let bytes: [UInt8]
        var index = 0

        var isAtEnd: Bool { index == bytes.count }

        mutating func byte() -> UInt8? {
            guard index < bytes.count else { return nil }
            defer { index += 1 }
            return bytes[index]
        }

        mutating func varint() -> UInt64? {
            var value: UInt64 = 0
            for shift in stride(from: 0, to: 64, by: 7) {
                guard let byte = byte() else { return nil }
                value |= UInt64(byte & 0x7F) << shift
                if byte < 0x80 { return value }
            }
            return nil
        }
    }
}

/// Douglas-Peucker line simplification in metres (B-104).
public enum RouteSimplifier {
    /// Keeps the points needed so that no original point lies more than
    /// `tolerance` metres from the simplified line. Start and end always stay.
    public static func simplify(_ points: [RoutePoint], tolerance: Double) -> [RoutePoint] {
        // Repeated positions (standing at a traffic light) add nothing.
        var unique: [RoutePoint] = []
        unique.reserveCapacity(points.count)
        for point in points where point != unique.last { unique.append(point) }
        guard unique.count > 2 else { return unique }

        let latitudes = unique.map(\.latitude)
        let middle = RoutePoint(latitude: ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2, longitude: unique[0].longitude)
        let plane = unique.map(LocalPlane(origin: middle).project)
        var keep = [Bool](repeating: false, count: unique.count)
        keep[0] = true
        keep[unique.count - 1] = true
        // A stack instead of recursion: a long ride must not run out of stack.
        var ranges = [(unique.startIndex, unique.endIndex - 1)]
        while let (first, last) = ranges.popLast() {
            guard last - first > 1 else { continue }
            var farthest = first, distance = 0.0
            for i in (first + 1)..<last {
                let d = distanceToSegment(plane[i], plane[first], plane[last])
                if d > distance { (farthest, distance) = (i, d) }
            }
            guard distance > tolerance else { continue }
            keep[farthest] = true
            ranges.append((first, farthest))
            ranges.append((farthest, last))
        }
        return unique.indices.compactMap { keep[$0] ? unique[$0] : nil }
    }

    /// Shortest distance from a point to a line segment, all in metres. To the
    /// segment, not the infinite line, so that a loop whose start and end meet
    /// keeps its far side.
    static func distanceToSegment(_ p: (x: Double, y: Double), _ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    /// Flat approximation around the middle latitude of the ride: metres east and
    /// north. East–west distances are off by about 0.2 % per 10 km north or south
    /// of that latitude, about 1 m on a straight 500 m stretch 10 km away.
    struct LocalPlane {
        static let earthRadius = 6_371_000.0
        let origin: RoutePoint
        let metresPerDegreeLongitude: Double
        let metresPerDegreeLatitude = earthRadius * .pi / 180

        init(origin: RoutePoint) {
            self.origin = origin
            metresPerDegreeLongitude = metresPerDegreeLatitude * cos(origin.latitude * .pi / 180)
        }

        func project(_ point: RoutePoint) -> (x: Double, y: Double) {
            ((point.longitude - origin.longitude) * metresPerDegreeLongitude,
             (point.latitude - origin.latitude) * metresPerDegreeLatitude)
        }
    }
}
