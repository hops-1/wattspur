import Compression
import Foundation
import Testing
@testable import WattspurCore

@Suite("Curvy roads from roadcurvature.com (B-182)")
final class CurvyRoadsTests {
    // MARK: Helpers

    /// A KML like roadcurvature's, with the figures in the description's text.
    static func kml(_ roads: [(name: String, curvature: Double, type: String, coordinates: String)]) -> String {
        let placemarks = roads.map { road in
            """
            <Placemark>
              <styleUrl>#paved12</styleUrl>
              <name>\(road.name)</name>
              <description><![CDATA[<div>Curvature: \(road.curvature)<br/>Distance: 2.50 km<br/>Type: \(road.type)<br/>Surface: asphalt</div>]]></description>
              <LineString><tessellate>1</tessellate><coordinates>\(road.coordinates)</coordinates></LineString>
            </Placemark>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2"><Document>
        <Style id="paved12"><LineStyle><width>3</width></LineStyle></Style>
        <Folder><name>Roads</name>
        \(placemarks)
        </Folder></Document></kml>
        """
    }

    static let sample = kml([
        (name: "Nibelungenstraße (B 47)", curvature: 1250.5, type: "primary", coordinates: "8.6185,49.6820 8.6186,49.6821 8.6190,49.6824"),
        (name: "  Waldweg  ", curvature: 420, type: "unclassified", coordinates: "8.70,49.70 8.71,49.71"),
        (name: "Autobahnauffahrt", curvature: 600, type: "motorway_link", coordinates: "8.80,49.80 8.81,49.81"),
    ])

    /// A ZIP file with the given entries, deflated or stored; the checksum stays 0, the reader does not check it.
    static func zip(_ entries: [(name: String, data: Data, deflate: Bool)]) -> Data {
        var out = Data()
        var central = Data()
        func le<T: FixedWidthInteger>(_ value: T, into data: inout Data) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        for entry in entries {
            var payload = entry.data
            if entry.deflate {
                var buffer = [UInt8](repeating: 0, count: entry.data.count + 1024)
                let size = entry.data.withUnsafeBytes { raw in
                    compression_encode_buffer(&buffer, buffer.count, raw.bindMemory(to: UInt8.self).baseAddress!,
                                              entry.data.count, nil, COMPRESSION_ZLIB)
                }
                payload = Data(buffer[0..<size])
            }
            let method: UInt16 = entry.deflate ? 8 : 0
            let name = Data(entry.name.utf8)
            let offset = out.count
            le(UInt32(0x0403_4b50), into: &out); le(UInt16(20), into: &out); le(UInt16(0), into: &out); le(method, into: &out)
            le(UInt32(0), into: &out); le(UInt32(0), into: &out)
            le(UInt32(payload.count), into: &out); le(UInt32(entry.data.count), into: &out)
            le(UInt16(name.count), into: &out); le(UInt16(0), into: &out)
            out.append(name); out.append(payload)
            le(UInt32(0x0201_4b50), into: &central); le(UInt16(20), into: &central); le(UInt16(20), into: &central)
            le(UInt16(0), into: &central); le(method, into: &central)
            le(UInt32(0), into: &central); le(UInt32(0), into: &central)
            le(UInt32(payload.count), into: &central); le(UInt32(entry.data.count), into: &central)
            le(UInt16(name.count), into: &central); le(UInt16(0), into: &central); le(UInt16(0), into: &central)
            le(UInt16(0), into: &central); le(UInt16(0), into: &central); le(UInt32(0), into: &central)
            le(UInt32(offset), into: &central)
            central.append(name)
        }
        let centralOffset = out.count
        out.append(central)
        le(UInt32(0x0605_4b50), into: &out); le(UInt16(0), into: &out); le(UInt16(0), into: &out)
        le(UInt16(entries.count), into: &out); le(UInt16(entries.count), into: &out)
        le(UInt32(central.count), into: &out); le(UInt32(centralOffset), into: &out); le(UInt16(0), into: &out)
        return out
    }

    /// The suite's own temporary folder; it goes with the suite (R-10).
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("curvy-\(UUID().uuidString)")
    deinit { try? FileManager.default.removeItem(at: root) }

    /// Writes data into a new file in a folder of its own and returns the file.
    func file(_ name: String, _ data: Data) throws -> URL {
        let folder = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    // MARK: Reading

    @Test("A KML gives the roads with curvature, length and the line as latitude and longitude")
    func readKML() throws {
        let url = try file("hessen.kml", Data(Self.sample.utf8))
        let roads = try CurvyRoads.read(from: url)
        // The motorway link is left out; nobody cycles there.
        #expect(roads.map(\.name) == ["Nibelungenstraße (B 47)", "Waldweg"])
        let first = roads[0]
        #expect(first.curvature == 1250.5)
        #expect(first.isVeryCurvy)
        #expect(abs(first.length - 2500) < 0.001)
        #expect(first.pointCount == 3)
        #expect(first.coordinates[0] == 49.6820 && first.coordinates[1] == 8.6185)
        #expect(!roads[1].isVeryCurvy)
        #expect(roads[1].curvature == 420)
    }

    @Test("A KMZ is read whether the KML in it is deflated or stored")
    func readKMZ() throws {
        let kml = Data(Self.sample.utf8)
        for deflate in [true, false] {
            let archive = Self.zip([(name: "hessen/doc.kml", data: kml, deflate: deflate),
                                    (name: "images/legend.png", data: Data([1, 2, 3]), deflate: false)])
            let url = try file("hessen.c_300.kmz", archive)
            let roads = try CurvyRoads.read(from: url)
            #expect(roads.count == 2)
        }
    }

    @Test("Files that are not curvature data are turned down")
    func foreign() throws {
        func fails(_ name: String, _ data: Data, _ expected: CurvyRoads.Failure) throws {
            let url = try file(name, data)
            #expect(throws: expected) { try CurvyRoads.read(from: url) }
        }
        // A KML without the figures, a text file called KMZ, a ZIP without KML, no XML at all.
        try fails("route.kml", Data(Self.kml([]).utf8), .notCurvatureData)
        let strangers = Self.kml([]).replacingOccurrences(of: "</Folder>", with: "<Placemark><name>x</name><LineString><coordinates>1,2 3,4</coordinates></LineString></Placemark></Folder>")
        try fails("other.kml", Data(strangers.utf8), .notCurvatureData)
        try fails("text.kmz", Data("hello".utf8), .notCurvatureData)
        try fails("empty.kmz", Self.zip([(name: "readme.txt", data: Data("x".utf8), deflate: false)]), .notCurvatureData)
        try fails("broken.kml", Data("<kml><Document>".utf8), .notCurvatureData)
    }

    @Test("A cut-off KMZ fails instead of giving half the roads")
    func truncated() throws {
        let archive = Self.zip([(name: "doc.kml", data: Data(Self.sample.utf8), deflate: true)])
        for cut in [10, archive.count / 2, archive.count - 5] {
            #expect(throws: (any Error).self) {
                try CurvyRoads.read(from: try file("cut.kmz", archive.prefix(cut)))
            }
        }
    }

    @Test("Limits stop files that are too large, by what they hold, not by what they claim")
    func limits() throws {
        var limits = CurvyRoads.Limits()
        limits.roads = 1
        #expect(throws: CurvyRoads.Failure.tooLarge) {
            try CurvyRoads.read(from: try file("a.kml", Data(Self.sample.utf8)), limits: limits)
        }
        limits = CurvyRoads.Limits()
        limits.points = 4
        #expect(throws: CurvyRoads.Failure.tooLarge) {
            try CurvyRoads.read(from: try file("b.kml", Data(Self.sample.utf8)), limits: limits)
        }
        limits = CurvyRoads.Limits()
        limits.uncompressedBytes = 100
        let archive = Self.zip([(name: "doc.kml", data: Data(Self.sample.utf8), deflate: true)])
        #expect(throws: CurvyRoads.Failure.tooLarge) {
            try CurvyRoads.read(from: try file("c.kmz", archive), limits: limits)
        }
    }

    // MARK: ZIP

    @Test("The ZIP reader lists the entries and extracts them")
    func zipEntries() throws {
        let text = Data(String(repeating: "Kurvige Straße. ", count: 500).utf8)
        let archive = try ZipArchive(data: Self.zip([(name: "a/doc.kml", data: text, deflate: true),
                                                     (name: "b.txt", data: Data("x".utf8), deflate: false)]))
        #expect(archive.entries.map(\.name) == ["a/doc.kml", "b.txt"])
        let entry = try #require(archive.entry(withSuffix: ".KML"))
        #expect(entry.uncompressedSize == text.count && entry.compressedSize < text.count)
        let target = try file("out.kml", Data())
        try archive.extract(entry, to: target, limit: 1_000_000)
        #expect(try Data(contentsOf: target) == text)
        #expect(throws: ZipArchive.Failure.notAZipFile) { try ZipArchive(data: Data("PK".utf8)) }
    }

    // MARK: Region file

    private func region() -> CurvyRegion {
        CurvyRegion(id: "hessen", name: "Hessen", importedAt: Date(timeIntervalSince1970: 1_700_000_000), roads: [
            CurvyRoad(name: "Nibelungenstraße", curvature: 1250.5, length: 2500, coordinates: [49.6820, 8.6185, 49.6821, 8.6186, 49.6824, 8.6190]),
            CurvyRoad(name: "Waldweg", curvature: 420, length: 1000, coordinates: [49.70, 8.70, 49.71, 8.71]),
        ])
    }

    @Test("A region survives the file and its header can be read alone")
    func regionFile() throws {
        let original = region()
        let data = original.encoded()
        let back = try CurvyRegion(data: data)
        #expect(back == original)
        let info = try CurvyRegion.info(from: data)
        #expect(info.id == "hessen" && info.name == "Hessen" && info.roadCount == 2)
        #expect(abs(info.totalLength - 3.5) < 1e-9)
        #expect(info == original.info)
    }

    @Test("A damaged region file is refused")
    func damagedRegionFile() {
        let data = region().encoded()
        for cut in [0, 3, 12, data.count / 2, data.count - 1] {
            #expect(throws: CurvyRoads.Failure.damaged) { try CurvyRegion(data: data.prefix(cut)) }
        }
        var wrong = data
        wrong[0] = 0x58
        #expect(throws: CurvyRoads.Failure.damaged) { try CurvyRegion(data: wrong) }
        var newer = data
        newer[4] = 99
        #expect(throws: CurvyRoads.Failure.damaged) { try CurvyRegion(data: newer) }
        // A point count that claims more than the file holds.
        var lying = CurvyRegion(id: "a", name: "A", roads: [CurvyRoad(name: "x", curvature: 400, length: 100, coordinates: [49, 8, 49.1, 8.1])]).encoded()
        // The point count is the four bytes in front of the two points of eight bytes each.
        let at = lying.count - 2 * 8 - 4
        lying.replaceSubrange(at..<(at + 4), with: [0xFF, 0xFF, 0xFF, 0x7F])
        #expect(throws: CurvyRoads.Failure.damaged) { try CurvyRegion(data: lying) }
    }

    @Test("The distance to a road is the distance to its nearest stretch")
    func distance() {
        // A road heading east at latitude 49, from 8.00 to 8.01 (about 730 m), then north.
        let road = CurvyRoad(name: "x", curvature: 400, length: 1000, coordinates: [49.0, 8.00, 49.0, 8.01, 49.01, 8.01])
        let metresPerDegree = 111_320.0
        // 100 m north of the middle of the eastward stretch.
        #expect(abs(road.distance(toLatitude: 49.0 + 100 / metresPerDegree, longitude: 8.005) - 100) < 0.5)
        // On the road.
        #expect(road.distance(toLatitude: 49.005, longitude: 8.01) < 0.5)
        // Beyond the end: the distance to the end point.
        #expect(abs(road.distance(toLatitude: 49.01 + 50 / metresPerDegree, longitude: 8.01) - 50) < 0.5)
        #expect(road.distance(toLatitude: 50, longitude: 8) > 100_000)
    }

    @Test("A road knows whether its box touches an area")
    func boundingBox() {
        let road = CurvyRoad(name: "x", curvature: 400, length: 100, coordinates: [49.0, 8.0, 49.1, 8.2])
        #expect(road.intersects(minLatitude: 49.05, maxLatitude: 49.5, minLongitude: 8.1, maxLongitude: 9))
        #expect(!road.intersects(minLatitude: 49.2, maxLatitude: 49.5, minLongitude: 8.1, maxLongitude: 9))
        #expect(!road.intersects(minLatitude: 49.0, maxLatitude: 49.5, minLongitude: 8.3, maxLongitude: 9))
    }
}
