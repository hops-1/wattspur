import Foundation
import SwiftData
import Testing
@testable import WattspurKit

/// Reads a GPX file back with `XMLParser` (namespace-aware): a stand-in for the later
/// GPX import (B-060), so the export is checked as a round trip.
private final class GPXReader: NSObject, XMLParserDelegate {
    struct Point {
        var latitude: Double
        var longitude: Double
        var elevation: Double?
        var time: Date?
        var power: Int?
        var cadence: Int?
    }

    var segments: [[Point]] = []
    var trackName: String?
    var gpxVersion: String?
    private var point: Point?
    private var text = ""
    private var path: [String] = []

    static func read(_ data: Data) -> (reader: GPXReader, ok: Bool) {
        let reader = GPXReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = reader
        return (reader, parser.parse())
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        let gpx = "http://www.topografix.com/GPX/1/1"
        let key = namespaceURI == gpx ? name : "\(namespaceURI ?? ""):\(name)"
        path.append(key)
        text = ""
        switch key {
        case "gpx": gpxVersion = attributes["version"]
        case "trkseg": segments.append([])
        case "trkpt":
            point = Point(latitude: Double(attributes["lat"] ?? "") ?? .nan,
                          longitude: Double(attributes["lon"] ?? "") ?? .nan)
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let key = path.removeLast()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch key {
        case "ele": point?.elevation = Double(value)
        case "time" where point != nil: point?.time = try? Date(value, strategy: .iso8601)
        case "power": point?.power = Int(value)
        case "\(GPXWriter.trackPointExtensionNamespace):cad": point?.cadence = Int(value)
        case "name" where path.last == "trk": trackName = value
        case "trkpt":
            if let point { segments[segments.count - 1].append(point) }
            point = nil
        default: break
        }
    }
}

@Suite("GPX export")
struct GPXWriterTests {
    let start = Date(timeIntervalSince1970: 1_792_325_533) // 2026-10-18 12:12:13 UTC

    @Test("Valid GPX 1.1 with UTC times, elevation, power and measured cadence only")
    func writesTrackPoints() throws {
        let samples = [
            RideSample(time: 0, latitude: 49.8712345, longitude: 8.8412345, altitude: 166.04, power: 135,
                       cadence: 60, cadenceMeasured: true),
            RideSample(time: 1, latitude: 49.8712400, longitude: 8.8412500, altitude: 166.2, power: 0,
                       cadence: 60, cadenceMeasured: false),
            RideSample(time: 2, altitude: 167), // no position: skipped
        ]
        let data = GPXWriter.document(name: "Reinheim <Runde> & Kaffee", segments: [.init(startDate: start, samples: samples)])
        let text = try #require(String(data: data, encoding: .utf8))
        let (gpx, ok) = GPXReader.read(data)

        #expect(ok)
        #expect(gpx.gpxVersion == "1.1")
        #expect(gpx.trackName == "Reinheim <Runde> & Kaffee")
        #expect(text.contains("<time>2026-10-18T12:12:13Z</time>"))
        #expect(gpx.segments.count == 1)
        let points = gpx.segments[0]
        #expect(points.count == 2)
        #expect(points[0].latitude == 49.8712345)
        #expect(points[0].elevation == 166.0)
        #expect(points[1].time == start.addingTimeInterval(1))
        #expect(points[0].power == 135)
        #expect(points[0].cadence == 60)
        #expect(points[1].power == 0)
        #expect(points[1].cadence == nil)
    }

    @Test("One segment per recording; empty recordings are left out")
    func segments() {
        let a = GPXWriter.Segment(startDate: start, samples: [RideSample(time: 0, latitude: 1, longitude: 2)])
        let b = GPXWriter.Segment(startDate: start.addingTimeInterval(86_400),
                                  samples: [RideSample(time: 5, latitude: 1.1, longitude: 2.1)])
        let empty = GPXWriter.Segment(startDate: start, samples: [RideSample(time: 0, altitude: 100)])
        let (gpx, ok) = GPXReader.read(GPXWriter.document(name: "Zwei Teile", segments: [a, empty, b]))
        let secondDay: Date = start.addingTimeInterval(86_405)
        #expect(ok)
        #expect(gpx.segments.count == 2)
        #expect(gpx.segments[1].first?.time == secondDay)
    }

    @Test("The reference ride exports every position with its real time")
    func referenceRide() throws {
        let parsed = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
        let data = GPXWriter.document(name: "Reinheim", segments: [.init(startDate: parsed.startDate, samples: parsed.samples)])
        let (gpx, ok) = GPXReader.read(data)
        let withPosition = parsed.samples.filter { $0.latitude != nil && $0.longitude != nil }
        #expect(ok)
        #expect(gpx.segments.first?.count == withPosition.count)
        #expect(gpx.segments.first?.first?.time == parsed.startDate.addingTimeInterval(withPosition[0].time))
        #expect(gpx.segments.first?.contains { $0.power != nil } == true)
    }

    @Test("File names lose characters Finder does not accept")
    func fileName() {
        #expect(GPXWriter.fileName("Runde 1/2: Feierabend") == "Runde 1-2- Feierabend.gpx")
    }

    @MainActor
    @Test("A merged ride exports its parts with their own start times")
    func mergedRide() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let library = RideLibrary(context: container.mainContext)
        let fixture = try Fixture.data("reinheim-rundfahrt")
        let anonymizer = { (weeks: Int) in FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, trimDistance: 0, weeks: weeks) }
        var ids: [UUID] = []
        for (i, weeks) in [0, 1].enumerated() {
            let result = library.importFile(data: try anonymizer(weeks).anonymize(fixture), fileName: "Teil \(i).fit")
            if case .imported(let id) = result.outcome { ids.append(id) }
        }
        let rides = ids.compactMap { library.ride(withID: $0) }
        try #require(rides.count == 2)
        let merged = try library.merge(rides, name: "Zusammen")
        let segments = merged.gpxSegments
        #expect(segments.count == 2)
        #expect(segments.map(\.startDate) == rides.map(\.startDate).sorted())
        let (gpx, ok) = GPXReader.read(GPXWriter.document(name: merged.name, segments: segments))
        #expect(ok)
        #expect(gpx.segments.count == 2)
    }
}
