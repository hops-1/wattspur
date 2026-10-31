import Foundation

// Curvy roads from roadcurvature.com for the map (V-13, B-182, B-183): the reading of
// their KML/KMZ files and the compact file the app keeps per region.
// The data is © OpenStreetMap contributors (ODbL); it is never shipped with the app, the
// user loads and imports it.

/// One road with its curvature and its line.
public struct CurvyRoad: Sendable, Equatable {
    public var name: String
    /// The curvature after roadcurvature.com: tight and gentle curves, weighted, summed over the road.
    public var curvature: Double
    /// Metres.
    public var length: Double
    /// Latitude and longitude one after the other; `Float` is precise to about half a metre here.
    public var coordinates: [Float]
    public private(set) var minLatitude: Float
    public private(set) var maxLatitude: Float
    public private(set) var minLongitude: Float
    public private(set) var maxLongitude: Float

    public init(name: String, curvature: Double, length: Double, coordinates: [Float]) {
        self.name = name
        self.curvature = curvature
        self.length = length
        self.coordinates = coordinates
        var minLat = Float.infinity, maxLat = -Float.infinity, minLon = Float.infinity, maxLon = -Float.infinity
        for i in stride(from: 0, to: coordinates.count - 1, by: 2) {
            minLat = min(minLat, coordinates[i]); maxLat = max(maxLat, coordinates[i])
            minLon = min(minLon, coordinates[i + 1]); maxLon = max(maxLon, coordinates[i + 1])
        }
        minLatitude = minLat; maxLatitude = maxLat; minLongitude = minLon; maxLongitude = maxLon
    }

    public var pointCount: Int { coordinates.count / 2 }

    /// The stronger classes are drawn more strongly: from 300 curvy, from 1000 very curvy.
    public var isVeryCurvy: Bool { curvature >= CurvyRoads.veryCurvyFrom }

    /// How far the road is from a position, in metres: the shortest distance to any of its stretches.
    public func distance(toLatitude latitude: Double, longitude: Double) -> Double {
        let metresPerDegree = 111_320.0
        let cosine = cos(latitude * .pi / 180)
        func point(_ i: Int) -> (x: Double, y: Double) {
            ((Double(coordinates[2 * i + 1]) - longitude) * metresPerDegree * cosine, (Double(coordinates[2 * i]) - latitude) * metresPerDegree)
        }
        guard pointCount > 0 else { return .infinity }
        var best = Double.infinity
        var a = point(0)
        best = min(best, (a.x * a.x + a.y * a.y).squareRoot())
        for i in 1..<max(1, pointCount) {
            let b = point(i)
            let dx = b.x - a.x, dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            // The foot of the position on the stretch from a to b, held between its ends.
            let t = lengthSquared > 0 ? max(0, min(1, -(a.x * dx + a.y * dy) / lengthSquared)) : 0
            let fx = a.x + t * dx, fy = a.y + t * dy
            best = min(best, (fx * fx + fy * fy).squareRoot())
            a = b
        }
        return best
    }

    /// Whether the road's bounding box touches the area.
    public func intersects(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) -> Bool {
        Double(self.maxLatitude) >= minLatitude && Double(self.minLatitude) <= maxLatitude
            && Double(self.maxLongitude) >= minLongitude && Double(self.minLongitude) <= maxLongitude
    }
}

public enum CurvyRoads {
    /// Raise when the file format changes.
    public static let formatVersion = 1
    public static let curvyFrom = 300.0
    public static let veryCurvyFrom = 1000.0
    /// The map shows the roads only when one point of the screen is at most this many metres wide,
    /// about a district in a window: all of a state at once would be a tangle.
    public static let maximumMetresPerPoint = 90.0
    /// The credit the data asks for.
    public static let attribution = "© OpenStreetMap contributors, roadcurvature.com"
    public static let downloadPage = URL(string: "https://roadcurvature.com/")!

    /// Limits against files that are not what they claim to be (as with the FIT files, B-140).
    public struct Limits: Sendable {
        public var uncompressedBytes = 600_000_000
        public var roads = 200_000
        public var points = 5_000_000

        public init() {}
    }

    public enum Failure: Error, Equatable {
        /// The file is no KML or KMZ, or a KML without roadcurvature's figures.
        case notCurvatureData
        case tooLarge
        case damaged
    }

    /// Roads for cars only; nobody cycles on them.
    static let excludedTypes: Set<String> = ["motorway", "motorway_link"]
}

/// The roads of one region (one state), with the little the list in the settings shows.
public struct CurvyRegion: Sendable, Equatable {
    public var id: String
    public var name: String
    public var importedAt: Date
    public var roads: [CurvyRoad]

    public init(id: String, name: String, importedAt: Date = .now, roads: [CurvyRoad]) {
        self.id = id
        self.name = name
        self.importedAt = importedAt
        self.roads = roads
    }

    /// Kilometres of road in the region.
    public var totalLength: Double { roads.reduce(0) { $0 + $1.length } / 1000 }

    /// What the settings show without reading all roads.
    public struct Info: Sendable, Equatable, Identifiable {
        public var id: String
        public var name: String
        public var importedAt: Date
        public var roadCount: Int
        public var totalLength: Double
    }

    public var info: Info { Info(id: id, name: name, importedAt: importedAt, roadCount: roads.count, totalLength: totalLength) }
}

// MARK: - File format

extension CurvyRegion {
    private static let magic: [UInt8] = Array("WCRV".utf8)

    /// The region as a compact file: header with the figures of `Info`, then each road.
    public func encoded() -> Data {
        var out = Data()
        out.append(contentsOf: Self.magic)
        out.appendInteger(UInt32(CurvyRoads.formatVersion))
        out.appendString(id)
        out.appendString(name)
        out.appendInteger(importedAt.timeIntervalSince1970.bitPattern)
        out.appendInteger(UInt32(roads.count))
        out.appendInteger(totalLength.bitPattern)
        for road in roads {
            out.appendString(road.name)
            out.appendInteger(Float(road.curvature).bitPattern)
            out.appendInteger(Float(road.length).bitPattern)
            out.appendInteger(UInt32(road.pointCount))
            for value in road.coordinates { out.appendInteger(value.bitPattern) }
        }
        return out
    }

    /// Reads the figures at the start of a region file, without the roads.
    public static func info(from data: Data) throws -> Info {
        var reader = RegionFileReader(data)
        return try header(&reader).info
    }

    /// Reads a whole region file; anything cut off, too long or from a newer format is `damaged`.
    public init(data: Data) throws {
        var reader = RegionFileReader(data)
        let header = try Self.header(&reader)
        var roads: [CurvyRoad] = []
        roads.reserveCapacity(min(header.info.roadCount, 200_000))
        for _ in 0..<header.info.roadCount {
            let name = try reader.string()
            let curvature = Double(Float(bitPattern: try reader.uint32()))
            let length = Double(Float(bitPattern: try reader.uint32()))
            let count = Int(try reader.uint32())
            guard count <= reader.remaining / 8 else { throw CurvyRoads.Failure.damaged }
            var coordinates = [Float](repeating: 0, count: count * 2)
            for i in 0..<(count * 2) { coordinates[i] = Float(bitPattern: try reader.uint32()) }
            roads.append(CurvyRoad(name: name, curvature: curvature, length: length, coordinates: coordinates))
        }
        self.init(id: header.info.id, name: header.info.name, importedAt: header.info.importedAt, roads: roads)
    }

    private static func header(_ reader: inout RegionFileReader) throws -> (info: Info, roads: Int) {
        guard try reader.bytes(4).elementsEqual(magic), try reader.uint32() == UInt32(CurvyRoads.formatVersion) else {
            throw CurvyRoads.Failure.damaged
        }
        let id = try reader.string()
        let name = try reader.string()
        let importedAt = Date(timeIntervalSince1970: Double(bitPattern: try reader.uint64()))
        let count = Int(try reader.uint32())
        let length = Double(bitPattern: try reader.uint64())
        guard count <= reader.remaining else { throw CurvyRoads.Failure.damaged }
        return (Info(id: id, name: name, importedAt: importedAt, roadCount: count, totalLength: length), count)
    }
}

private extension Data {
    mutating func appendInteger<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendString(_ string: String) {
        let bytes = Array(string.utf8.prefix(Int(UInt16.max)))
        appendInteger(UInt16(bytes.count))
        append(contentsOf: bytes)
    }
}

/// Reads little-endian values and fails instead of running past the end.
private struct RegionFileReader {
    private let data: Data
    private var position: Int

    init(_ data: Data) {
        self.data = data
        position = data.startIndex
    }

    var remaining: Int { data.endIndex - position }

    mutating func bytes(_ count: Int) throws -> Data {
        guard count >= 0, count <= remaining else { throw CurvyRoads.Failure.damaged }
        defer { position += count }
        return data[position..<(position + count)]
    }

    mutating func uint16() throws -> UInt16 {
        let b = try bytes(2)
        return UInt16(b[b.startIndex]) | UInt16(b[b.startIndex + 1]) << 8
    }

    mutating func uint32() throws -> UInt32 {
        let b = try bytes(4)
        var value: UInt32 = 0
        for i in 0..<4 { value |= UInt32(b[b.startIndex + i]) << (8 * UInt32(i)) }
        return value
    }

    mutating func uint64() throws -> UInt64 {
        let b = try bytes(8)
        var value: UInt64 = 0
        for i in 0..<8 { value |= UInt64(b[b.startIndex + i]) << (8 * UInt64(i)) }
        return value
    }

    mutating func string() throws -> String {
        String(decoding: try bytes(Int(try uint16())), as: UTF8.self)
    }
}
