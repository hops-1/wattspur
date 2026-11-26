import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// Invented GPX documents for planned tours (B-372): a line north from 50.0/9.0, one point every
/// `spacing` metres.
private enum Tour {
    static let base = Date(timeIntervalSince1970: 1_780_732_800) // 2026-06-06 08:00:00 UTC

    static func latitude(_ index: Int, spacing: Double) -> Double { 50 + Double(index) * spacing / 111_320 }

    static func trackPoints(_ count: Int, spacing: Double = 40, step: TimeInterval? = nil, ele: (Int) -> Double = { 300 + Double($0) }) -> String {
        (0..<count).map { i in
            let time = step.map { "<time>\(GPXWriter.timestamp(base.addingTimeInterval(Double(i) * $0)))</time>" } ?? ""
            return "<trkpt lat=\"\(latitude(i, spacing: spacing))\" lon=\"9.0\"><ele>\(ele(i))</ele>\(time)</trkpt>"
        }.joined()
    }

    static func gpx(creator: String = "Planer", metadata: String = "<metadata><name>Erfundene Tour</name></metadata>", body: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="\(creator)" xmlns="http://www.topografix.com/GPX/1/1">\(metadata)\(body)</gpx>
        """.utf8)
    }

    static func track(_ points: String, name: String = "Spur") -> String {
        "<trk><name>\(name)</name><trkseg>\(points)</trkseg></trk>"
    }
}

@Suite("Planned tour reader")
struct PlannedTourReaderTests {
    let reader = PlannedTourReader()

    @Test("A track without times is a planned tour: points with heights, distance and ascent")
    func trackWithoutTimes() throws {
        let data = Tour.gpx(body: Tour.track(Tour.trackPoints(11), name: "Über den Hügel"))
        #expect(PlannedTourReader.content(of: data) == .plannedTour)
        let tour = try reader.read(data)
        #expect(tour.name == "Über den Hügel")
        #expect(tour.source == .gpx)
        #expect(tour.points.count == 11)
        #expect(tour.points[3].altitude == 303)
        #expect(abs(tour.distance - 400) < 1)
        // The median of 5 heights shortens both ends by one metre.
        #expect(tour.ascent == 8)
        #expect(tour.descent == 0)
        #expect(!tour.isLoop)
    }

    @Test("A route (rte) without a track is a planned tour with the route's name; waypoints are left out")
    func route() throws {
        let points = (0..<6).map { "<rtept lat=\"\(Tour.latitude($0, spacing: 100))\" lon=\"9.0\"><ele>300</ele></rtept>" }.joined()
        let data = Tour.gpx(metadata: "", body: "<wpt lat=\"51.0\" lon=\"10.0\"><name>Ziel</name></wpt><rte><name>Zum See</name>\(points)</rte>")
        #expect(PlannedTourReader.content(of: data) == .plannedTour)
        let tour = try reader.read(data)
        #expect(tour.name == "Zum See")
        #expect(tour.points.count == 6)
        #expect(abs(tour.distance - 500) < 1)
        #expect(tour.ascent == 0)
    }

    @Test("The route fixture of the ride importer reads as a tour")
    func routeFixture() throws {
        let data = try GPXFixture.data("route-and-waypoints-only")
        #expect(PlannedTourReader.content(of: data) == .plannedTour)
        let tour = try reader.read(data)
        #expect(tour.name == "Geplante Route")
        #expect(tour.points.count > 2)
    }

    @Test("A loop ends where it starts")
    func loop() throws {
        let out = (0..<5).map { "<trkpt lat=\"\(Tour.latitude($0, spacing: 200))\" lon=\"9.0\"></trkpt>" }
        let back = (0..<5).reversed().map { "<trkpt lat=\"\(Tour.latitude($0, spacing: 200))\" lon=\"9.001\"></trkpt>" }
        let tour = try reader.read(Tour.gpx(body: Tour.track((out + back).joined())))
        #expect(tour.isLoop)
        #expect(tour.ascent == nil)
        #expect(tour.distance > 1600)
    }

    @Test("A komoot tour (V-22) has estimated times: no metadata time, steps of 7 s, points 37 m apart")
    func komoot() throws {
        let data = try GPXFixture.data("komoot-planned-tour")
        #expect(PlannedTourReader.content(of: data) == .estimatedTimes(komoot: true))
        #expect(PlannedTourReader.content(of: data).isTourWithoutAsking)
        let tour = try reader.read(data)
        #expect(tour.source == .komoot)
        #expect(tour.name == "Erfundene Runde")
        #expect(tour.points.count == 320)
        #expect(tour.distance > 10_000)
        #expect((tour.ascent ?? 0) > 50)
    }

    @Test("Estimated times from another planner ask with the ride preselected")
    func estimatedNotKomoot() {
        let data = Tour.gpx(body: Tour.track(Tour.trackPoints(30, spacing: 40, step: 8)))
        #expect(PlannedTourReader.content(of: data) == .estimatedTimes(komoot: false))
        #expect(!PlannedTourReader.content(of: data).isTourWithoutAsking)
    }

    @Test("Real rides stay rides: 1 s steps, close points, or a time in the metadata")
    func rides() throws {
        #expect(PlannedTourReader.content(of: Tour.gpx(body: Tour.track(Tour.trackPoints(30, spacing: 5, step: 1)))) == .ride)
        // Sparse but with the time a recording names.
        let withTime = Tour.gpx(metadata: "<metadata><time>2026-06-06T08:00:00Z</time></metadata>",
                                body: Tour.track(Tour.trackPoints(30, spacing: 40, step: 8)))
        #expect(PlannedTourReader.content(of: withTime) == .ride)
        // A ridden komoot tour (an anonymized excerpt): 1 s steps.
        #expect(PlannedTourReader.content(of: try GPXFixture.data("pair-tour1-komoot")) == .ride)
        #expect(PlannedTourReader.content(of: try GPXFixture.data("wattspur-export")) == .ride)
        #expect(PlannedTourReader.content(of: Data("no xml".utf8)) == .ride)
    }

    @Test("Only the start of a big file is needed for the quick look")
    func quickLookOnTheStart() throws {
        let data = try GPXFixture.data("komoot-planned-tour")
        #expect(PlannedTourReader.content(of: data.prefix(8_000)) == .estimatedTimes(komoot: true))
    }

    @Test("Too few points, broken files and waypoints alone are refused")
    func refused() {
        #expect(throws: GPXImportError.noTrackPoints) { try reader.read(Tour.gpx(body: Tour.track(Tour.trackPoints(1)))) }
        #expect(throws: GPXImportError.onlyRoutesOrWaypoints) {
            try reader.read(Tour.gpx(body: "<wpt lat=\"50.0\" lon=\"9.0\"/><wpt lat=\"50.1\" lon=\"9.0\"/>"))
        }
        #expect(throws: GPXImportError.notGPX) { try reader.read(Data("<html></html>".utf8)) }
        #expect(throws: GPXImportError.tooLarge) { try PlannedTourReader(maxFileSize: 10).read(Tour.gpx(body: "")) }
        #expect(throws: GPXImportError.tooManyPoints) {
            try PlannedTourReader(maxPoints: 5).read(Tour.gpx(body: Tour.track(Tour.trackPoints(10))))
        }
    }

    @Test("The points survive the store's encoding; the same file gives the same key")
    func encoding() throws {
        let tour = try reader.read(GPXFixture.data("komoot-planned-tour"))
        let data = PlannedTour.encode(tour.points)
        #expect(data.count == 1 + 24 * tour.points.count)
        #expect(PlannedTour.decodePoints(data) == tour.points)
        let withoutHeight = [PlannedTour.Point(latitude: 50, longitude: 9)]
        #expect(PlannedTour.decodePoints(PlannedTour.encode(withoutHeight)) == withoutHeight)
        #expect(PlannedTour.decodePoints(Data([9, 1, 2])) == nil)
        #expect(try reader.read(GPXFixture.data("komoot-planned-tour")).contentKey == tour.contentKey)
        #expect(!tour.contentKey.isEmpty)
    }
}
