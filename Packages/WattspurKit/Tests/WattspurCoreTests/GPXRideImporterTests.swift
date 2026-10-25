import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// Small GPX documents built in the test, for rules the fixture files do not cover.
private enum Doc {
    static let base = Date(timeIntervalSince1970: 1_780_732_800) // 2026-06-06 08:00:00 UTC

    static func time(_ offset: TimeInterval, from start: Date = base) -> String {
        GPXWriter.timestamp(start.addingTimeInterval(offset))
    }

    /// A point `second` seconds after `start`, moving north at about 3.3 m/s.
    static func point(_ second: Int, from start: Date = base, step: Int? = nil, time: Bool = true, extras: String = "") -> String {
        let lat = 50 + 0.00003 * Double(step ?? second)
        return "<trkpt lat=\"\(lat)\" lon=\"9.0\"><ele>300</ele>\(time ? "<time>\(Self.time(TimeInterval(second), from: start))</time>" : "")\(extras)</trkpt>"
    }

    static func gpx(_ segments: [[String]]) -> Data {
        let body = segments.map { "<trkseg>\($0.joined())</trkseg>" }.joined()
        return Data("<?xml version=\"1.0\"?><gpx version=\"1.1\" creator=\"Test\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk>\(body)</trk></gpx>".utf8)
    }
}

private let utc = TimeZone(identifier: "UTC")!

@Suite("GPX ride importer")
struct GPXRideImporterTests {
    let importer = GPXRideImporter(timeZone: utc)

    // MARK: - Dialects

    @Test("Handles .gpx files and reports its parser version")
    func protocolBasics() {
        #expect(importer.fileExtensions == ["gpx"])
        #expect(importer.parserVersion == GPXRideImporter.parserVersion)
    }

    @Test("Wattspur export: power, cadence and a second segment come back unchanged")
    func wattspurExport() throws {
        let track = try importer.parseTrack(GPXFixture.data("wattspur-export"))
        #expect(track.name == "Wattspur-Export")
        #expect(track.creator == "Wattspur")
        #expect(track.activityType == "cycling")
        #expect(track.parts.count == 2)
        #expect(track.parts.map(\.samples.count) == [20, 20])
        let first = track.parts[0].samples
        #expect(first[0].power == nil)
        #expect(first[1].power == 121)
        #expect(first[1].cadence == 71)
        #expect(first[1].cadenceMeasured)
        #expect(first[0].cadenceMeasured == false)
        #expect(first[1].altitude == 300.0)
        #expect(first[2].altitude == 300.1)
        #expect(first[19].time == 19)
    }

    @Test("Round trip with the GPX export: positions, heights, power and cadence survive")
    func roundTrip() throws {
        let start = Date(timeIntervalSince1970: 1_792_325_533)
        var first: [RideSample] = []
        for i in 0..<60 {
            first.append(RideSample(time: Double(i), latitude: 49.87 + 0.00003 * Double(i), longitude: 8.84 + 0.00004 * Double(i),
                                    altitude: 166 + Double(i) * 0.1, power: i % 7 == 0 ? nil : 100 + i,
                                    cadence: i % 5 == 0 ? nil : 60 + i % 10, cadenceMeasured: i % 5 != 0))
        }
        let secondStart = start.addingTimeInterval(600)
        let second = (0..<30).map {
            RideSample(time: Double($0), latitude: 49.88 + 0.00003 * Double($0), longitude: 8.85, altitude: 170, power: 90)
        }
        let data = GPXWriter.document(name: "Runde", segments: [.init(startDate: start, samples: first), .init(startDate: secondStart, samples: second)])

        let track = try importer.parseTrack(data)
        #expect(track.name == "Runde")
        #expect(track.parts.count == 2)
        #expect(track.parts[0].startDate == start)
        #expect(track.parts[1].startDate == secondStart)
        for (written, read) in zip(first, track.parts[0].samples) {
            #expect(abs((read.latitude ?? 0) - (written.latitude ?? 1)) < 1e-6)
            #expect(abs((read.longitude ?? 0) - (written.longitude ?? 1)) < 1e-6)
            #expect(abs((read.altitude ?? 0) - (written.altitude ?? 1)) < 0.06)
            #expect(read.time == written.time)
            #expect(read.power == written.power)
            #expect(read.cadence == (written.cadenceMeasured ? written.cadence : nil))
            #expect(read.cadenceMeasured == written.cadenceMeasured)
        }
        #expect(track.parts[1].samples.count == 30)

        // Same day: the pause between the parts stays on the time axis.
        let ride = try importer.parse(data)
        #expect(ride.startDate == start)
        #expect(ride.samples.count == 90)
        #expect(ride.samples[60].time == 600)
        #expect(ride.summary.timerTime == 59 + 29)
        #expect(ride.summary.elapsedTime == 629)
        #expect(ride.workKilojoules != nil)
    }

    @Test("Strava style: power, heart rate and cadence as written, power missing from point 50")
    func stravaStyle() throws {
        let track = try importer.parseTrack(GPXFixture.data("strava-style-power-hr-cad"))
        #expect(track.name == "Morgenrunde & Café")
        #expect(track.creator == "StravaGPX")
        let samples = track.parts[0].samples
        #expect(samples.count == 60)
        #expect(samples[0].power == 150)
        #expect(samples[0].heartRate == 120)
        #expect(samples[0].cadence == 85)
        #expect(samples[49].power != nil)
        #expect(samples[50...].allSatisfy { $0.power == nil })
        #expect(samples[50...].allSatisfy { $0.heartRate != nil })
    }

    @Test("Garmin TrackPointExtension v1: temperature, heart rate and cadence")
    func garminExtension() throws {
        let track = try importer.parseTrack(GPXFixture.data("garmin-tpx-v1-hr-cad-temp"))
        #expect(track.name == "Testfahrt Radcomputer")
        #expect(track.activityType == "road_biking")
        let samples = track.parts[0].samples
        #expect(samples.count == 60)
        #expect(samples[0].temperature == 21.0)
        #expect(samples[0].heartRate == 110)
        #expect(samples[0].cadence == 80)
        #expect(samples.allSatisfy { $0.power == nil })
    }

    @Test("GPX 1.0: speed, course and fix elements are ignored, the time comes from the track points")
    func gpx10() throws {
        let track = try importer.parseTrack(GPXFixture.data("gpx10-speed-course"))
        #expect(track.name == "Fahrt")
        #expect(track.parts.count == 1)
        #expect(track.parts[0].samples.count == 30)
        #expect(track.parts[0].duration == 29)
        // Speed comes from distance and time, not from the file's 5.5 m/s.
        let speed = try #require(track.parts[0].samples[10].speed)
        #expect(abs(speed - 5.5) < 0.3)
    }

    @Test("BOM, CRLF, DOCTYPE with an internal entity, comments, CDATA and foreign extensions")
    func oddities() throws {
        let track = try importer.parseTrack(GPXFixture.data("bom-crlf-doctype-vendor-extensions"))
        #expect(track.parts.count == 1)
        #expect(track.parts[0].samples.count == 10)
        #expect(track.parts[0].samples.allSatisfy { $0.power == nil && $0.heartRate == nil && $0.temperature == nil })
        #expect(track.name != nil)
    }

    @Test("Times with offsets, 1 to 9 fraction digits and without a zone are read as UTC instants")
    func timeFormats() throws {
        let track = try importer.parseTrack(GPXFixture.data("time-formats-and-offsets"))
        let times = track.parts[0].samples.map(\.time)
        #expect(times.count == 8)
        let expected: [Double] = [0, 1.5, 2.25, 3.123456789, 4, 5, 6, 7]
        for (a, b) in zip(times, expected) { #expect(abs(a - b) < 1e-6) }
        #expect(track.startDate == Doc.base)
    }

    @Test("parseTime accepts ISO 8601 variants and refuses nonsense")
    func parseTime() {
        let t = Doc.base
        #expect(GPXRideImporter.parseTime("2026-06-06T08:00:00Z") == t)
        #expect(GPXRideImporter.parseTime(" 2026-06-06T08:00:00Z\n") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06T10:00:00+02:00") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06T10:00:00+0200") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06T10:00:00+02") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06T04:00:00-04:00") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06T08:00:00") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06 08:00:00Z") == t)
        #expect(GPXRideImporter.parseTime("2026-06-06T08:00:00.5Z") == t.addingTimeInterval(0.5))
        #expect(GPXRideImporter.parseTime("1970-01-01T00:00:00Z") == Date(timeIntervalSince1970: 0))
        #expect(GPXRideImporter.parseTime("2024-02-29T12:00:00Z") == Date(timeIntervalSince1970: 1_709_208_000))
        for bad in ["", "yesterday", "2026-13-06T08:00:00Z", "2026-06-06T25:00:00Z", "2026-06-06T08:00:00.Z",
                    "2026-06-06T08:00:00Zjunk", "2026-06-06", "06.06.2026 08:00"] {
            #expect(GPXRideImporter.parseTime(bad) == nil, "\(bad)")
        }
    }

    // MARK: - Cleaning

    @Test("Faults: order, equal times, 0/0, missing height, a 40 km jump, empty segments")
    func faults() throws {
        let track = try importer.parseTrack(GPXFixture.data("faults-order-duplicates-zero"))
        let d = track.discarded
        #expect(d.invalidPosition == 1)      // 0/0
        #expect(d.duplicateTime == 2)        // two points share a time stamp
        #expect(d.jumps == 1)                // 40 km in one second
        #expect(d.singlePointParts == 1)     // the lone point in the last segment
        #expect(d.reordered == 2)            // 15 s, 14 s, 13 s run backwards
        #expect(track.parts.count == 1)
        let samples = track.parts[0].samples
        #expect(samples.count == 20)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0.time < $1.time })
        #expect(samples.last?.time == 23)
        // Height 0 and a missing height both mean "no height".
        let atSecond20 = try #require(samples.first { $0.time == 20 })
        let atSecond21 = try #require(samples.first { $0.time == 21 })
        #expect(atSecond20.altitude == nil)
        #expect(atSecond21.altitude == nil)
        #expect(samples[0].altitude == 300)
        // The first of two points with the same time wins.
        #expect(samples.filter { $0.time == 16 }.count == 1)
    }

    @Test("A motorcycle at a steady 160 km/h is not a row of GPS jumps; single jumps are dropped")
    func fastRidesAreNotJumps() throws {
        let fast = try importer.parseTrack(GPXFixture.data("bmw-motorrad-excerpt-glitch"))
        #expect(fast.discarded.jumps == 0)
        #expect(fast.parts.count == 1)
        #expect(fast.parts[0].samples.count == 90)

        let multi = try importer.parseTrack(GPXFixture.data("bmw-motorrad-multi-segment"))
        #expect(multi.discarded.jumps > 0)
        let fastest = multi.parts.flatMap(\.samples).compactMap(\.speed).max() ?? 0
        #expect(fastest < 100, "a kept step of \(fastest) m/s is a jump")
    }

    @Test("Gaps of 30 s and more and new segments split the track; no time and no distance count across")
    func parts() throws {
        let day = Doc.base
        let data = Doc.gpx([
            (0...20).map { Doc.point($0) } + (50...70).map { Doc.point($0) },   // 29 s gap: still one part (20 → 50 is 30 s: a pause)
            (200...210).map { Doc.point($0) }
        ])
        let track = try importer.parseTrack(data)
        #expect(track.parts.map(\.samples.count) == [21, 21, 11])
        #expect(track.parts.map(\.duration) == [20, 20, 10])
        #expect(track.parts[1].startDate == day.addingTimeInterval(50))
        #expect(track.parts.allSatisfy { $0.samples.first?.distance == 0 })

        let almost = Doc.gpx([(0...20).map { Doc.point($0) } + (49...60).map { Doc.point($0) }])
        #expect(try importer.parseTrack(almost).parts.count == 1) // a 29 s gap is still riding

        // Distance restarts per part but runs on in the ride.
        let ride = try importer.parse(data)
        let sum = track.parts.reduce(0) { $0 + $1.distance }
        #expect(abs(ride.summary.distance - sum) < 0.01)
        #expect(abs((ride.samples.last?.distance ?? 0) - sum) < 0.01)
        #expect(ride.summary.timerTime == 50)
    }

    @Test("Segments out of order are put in time order; overlapping points are dropped")
    func segmentOrder() throws {
        let later = (100...110).map { Doc.point($0) }
        let earlier = (0...10).map { Doc.point($0) }
        let overlap = (105...115).map { Doc.point($0) }
        let track = try importer.parseTrack(Doc.gpx([later, earlier, overlap]))
        // Every segment is a part of its own; 105...110 lie inside the span of the segment before.
        #expect(track.parts.map(\.startDate) == [Doc.base, Doc.base.addingTimeInterval(100), Doc.base.addingTimeInterval(111)])
        #expect(track.parts.map(\.samples.count) == [11, 11, 5])
        #expect(track.discarded.overlapping == 6)
    }

    @Test("Parts on one day keep their pause on the time axis, parts on different days follow directly")
    func timeAxis() throws {
        let nextDay = Doc.base.addingTimeInterval(86_400)
        let sameDay = Doc.gpx([(0...10).map { Doc.point($0) }, (3600...3610).map { Doc.point($0) }])
        let a = try importer.parse(sameDay)
        #expect(a.samples[11].time == 3600)
        #expect(a.summary.elapsedTime == 3610)

        let otherDay = Doc.gpx([(0...10).map { Doc.point($0) }, (0...10).map { Doc.point($0, from: nextDay) }])
        let b = try importer.parse(otherDay)
        #expect(b.samples.count == 22)
        #expect(b.samples[11].time == 10)   // continues right after the first part
        #expect(b.samples.last?.time == 20)
        #expect(b.summary.elapsedTime == 20)
        #expect(b.summary.timerTime == 20)

        // The same two parts count as one day in a zone where both fall on one local day.
        let westCoast = GPXRideImporter(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        let near = Doc.gpx([(0...10).map { Doc.point($0) }, (0...10).map { Doc.point($0, from: Doc.base.addingTimeInterval(20 * 3600)) }])
        #expect(try westCoast.parse(near).samples[11].time == 20 * 3600)
        #expect(try importer.parse(near).samples[11].time == 10)
    }

    @Test("Speed comes from distance and time, distance runs from the start")
    func speedAndDistance() throws {
        let track = try importer.parseTrack(Doc.gpx([(0...10).map { Doc.point($0) }]))
        let samples = track.parts[0].samples
        let step = 0.00003 * 111_195 // metres per second
        #expect(abs((samples[10].distance ?? 0) - 10 * step) < 0.5)
        #expect(abs((samples[5].speed ?? 0) - step) < 0.1)
        #expect(samples[0].speed == samples[1].speed)
    }

    @Test("Hand-made extensions: aliases for power, cadence, heart rate and temperature; first value wins")
    func aliases() throws {
        let extras = "<extensions><powerInWatts>230</powerInWatts><ns:cadence xmlns:ns=\"urn:x\">88.4</ns:cadence><heartrate>141</heartrate><atemp>-3.5</atemp><power>999</power></extensions>"
        let track = try importer.parseTrack(Doc.gpx([[Doc.point(0, extras: extras), Doc.point(1, extras: extras)]]))
        let s = track.parts[0].samples[0]
        #expect(s.power == 230)
        #expect(s.cadence == 88)
        #expect(s.heartRate == 141)
        #expect(s.temperature == -3.5)
        let ride = try importer.parse(Doc.gpx([[Doc.point(0, extras: extras), Doc.point(1, extras: extras)]]))
        #expect(ride.workKilojoules == 0.23)
        #expect(ride.summary.averagePower == 230)
    }

    // MARK: - Real files

    @Test("Bosch Flow tour 1 (anonymized): ride time and distance along the GPS path")
    func boschTour1() throws {
        let track = try importer.parseTrack(GPXFixture.data("pair-tour1-bosch-flow"))
        #expect(track.name == "Beispielrunde")
        #expect(track.parts.count == 4)
        let ride = try importer.parse(GPXFixture.data("pair-tour1-bosch-flow"))
        // Anonymized (V-05): the first and last 500 m stand still on one point, so the
        // ride time is about 200 s below the FIT's 2 916 s and the GPS path 1.2 km shorter.
        #expect(abs(ride.summary.timerTime - 2719) < 29)
        #expect(abs(ride.summary.distance - 17_271) < 5)
        #expect(ride.workKilojoules == nil)
        #expect(ride.samples.allSatisfy { $0.power == nil && $0.heartRate == nil })
        #expect(track.discarded.total == 0)
    }

    @Test("komoot, same tour: doubled time stamps are merged and the numbers match the Bosch file")
    func komootTour1() throws {
        let bosch = try importer.parse(GPXFixture.data("pair-tour1-bosch-flow"))
        let komoot = try importer.parseTrack(GPXFixture.data("pair-tour1-komoot"))
        #expect(komoot.creator == "https://www.komoot.de")
        #expect(komoot.activityType == "e_touring_bicycle")
        #expect(komoot.discarded.duplicateTime > 1000)
        #expect(komoot.parts.allSatisfy { part in zip(part.samples, part.samples.dropFirst()).allSatisfy { $0.time < $1.time } })
        let ride = GPXRideImporter.ride(from: komoot, timeZone: utc)
        #expect(abs(ride.summary.timerTime - bosch.summary.timerTime) < 15)
        #expect(abs(ride.summary.distance - bosch.summary.distance) < 50)
        #expect(abs(ride.startDate.timeIntervalSince(bosch.startDate)) < 10)
    }

    @Test("Bosch Flow tour 2: the 15 s gap is riding, the 69 s gap is a pause")
    func boschTour2() throws {
        let track = try importer.parseTrack(GPXFixture.data("pair-tour2-bosch-flow"))
        #expect(track.parts.count == 2)
        let excerpt = try importer.parseTrack(GPXFixture.data("bosch-flow-excerpt-gaps"))
        #expect(excerpt.parts.count == 2)
    }

    @Test("BMW with four segments: a gap of 17 hours does not stretch the time axis")
    func bmwMultiSegment() throws {
        let ride = try importer.parse(GPXFixture.data("bmw-motorrad-multi-segment"))
        #expect(ride.samples.count > 100)
        #expect(ride.summary.elapsedTime < 30_000)
        #expect(ride.summary.timerTime < ride.summary.elapsedTime)
        // Like a merged ride: a part on another day starts at the end of the one before.
        #expect(zip(ride.samples, ride.samples.dropFirst()).allSatisfy { $0.time <= $1.time })
        #expect(zip(ride.samples, ride.samples.dropFirst()).allSatisfy { ($0.distance ?? 0) <= ($1.distance ?? 0) })
    }

    @Test("Standing still with GPS drift is kept as recorded; B-142 decides what counts as standing")
    func driftKept() throws {
        let track = try importer.parseTrack(GPXFixture.data("stillstand-gps-drift"))
        #expect(track.parts.count == 1)
        #expect(track.parts[0].samples.count == 430)
    }

    // MARK: - The ride

    @Test("The ride carries start, totals from the track, version and work")
    func parsedRide() throws {
        let ride = try importer.parse(GPXFixture.data("strava-style-power-hr-cad"))
        #expect(ride.startDate == Doc.base)
        #expect(ride.parserVersion == GPXRideImporter.parserVersion)
        #expect(ride.deviceSerialNumber == nil)
        #expect(ride.summary.timerTime == 59)
        #expect(ride.summary.elapsedTime == 59)
        #expect(abs(ride.summary.distance - 324.5) < 1)
        #expect(ride.summary.averagePower != nil)
        #expect(ride.summary.maxPower != nil)
        #expect(ride.summary.totalAscent == 0)   // flat track
        #expect(ride.summary.maxSpeed != nil)
        let work = try #require(ride.workKilojoules)
        #expect(work > 7 && work < 9)
    }

    // MARK: - Refusals

    @Test("Routes and waypoints only: refused with its own reason")
    func routesOnly() {
        #expect(throws: RideImportError.gpx(.onlyRoutesOrWaypoints)) {
            try importer.parse(GPXFixture.data("route-and-waypoints-only"))
        }
    }

    @Test("A track without time stamps is refused")
    func noTime() {
        #expect(throws: RideImportError.gpx(.noTimestamps)) {
            try importer.parse(GPXFixture.data("track-without-time"))
        }
    }

    @Test("A cut-off file is refused, not imported in part")
    func truncated() {
        #expect(throws: RideImportError.gpx(.truncated)) {
            try importer.parse(GPXFixture.data("truncated"))
        }
    }

    @Test("Files that are not GPX are refused without a crash")
    func notGPX() throws {
        for data in [Data(), Data("hello".utf8), Data("<html><body/></html>".utf8), try Fixture.data("reinheim-rundfahrt"), Data(repeating: 0xFF, count: 500)] {
            #expect(throws: RideImportError.gpx(.notGPX)) { try importer.parse(data) }
        }
        #expect(throws: RideImportError.gpx(.noTrackPoints)) { try importer.parse(Data("<gpx version=\"1.1\"/>".utf8)) }
        #expect(throws: RideImportError.gpx(.malformedXML)) {
            try importer.parse(Data("<gpx><trk><trkseg></trk></trkseg></gpx>".utf8))
        }
    }

    @Test("UTF-16 text is read like UTF-8")
    func utf16() throws {
        let text = String(decoding: Doc.gpx([(0...10).map { Doc.point($0) }]), as: UTF8.self)
            .replacingOccurrences(of: "<?xml version=\"1.0\"?>", with: "<?xml version=\"1.0\" encoding=\"UTF-16\"?>")
        let data = try #require(text.data(using: .utf16))
        #expect(try importer.parseTrack(data).parts.first?.samples.count == 11)
    }

    @Test("Without usable positions or with a single point there is nothing to import")
    func nothingUsable() {
        let broken = "<trkpt lat=\"abc\" lon=\"9\"><time>\(Doc.time(0))</time></trkpt>"
        #expect(throws: GPXImportError.noTrackPoints) { try importer.parseTrack(Doc.gpx([[broken]])) }
        let outOfRange = "<trkpt lat=\"91\" lon=\"9\"><time>\(Doc.time(0))</time></trkpt>"
        #expect(throws: GPXImportError.noTrackPoints) { try importer.parseTrack(Doc.gpx([[outOfRange]])) }
        #expect(throws: GPXImportError.noUsablePoints) { try importer.parseTrack(Doc.gpx([[Doc.point(0)]])) }
        #expect(throws: GPXImportError.noUsablePoints) { try importer.parseTrack(Doc.gpx([[Doc.point(0)], [Doc.point(100)]])) }
    }

    @Test("A few points without time are dropped; more than 5 % are refused")
    func untimed() throws {
        let few = (0...40).map { Doc.point($0) } + [Doc.point(41, time: false)]
        let track = try importer.parseTrack(Doc.gpx([few]))
        #expect(track.discarded.withoutTime == 1)
        #expect(track.parts[0].samples.count == 41)
        let many = (0...9).map { Doc.point($0) } + [Doc.point(10, time: false)]
        #expect(throws: GPXImportError.tooManyPointsWithoutTime) { try importer.parseTrack(Doc.gpx([many])) }
    }

    @Test("Times that run backwards often are refused instead of sorted")
    func unordered() {
        let points = (0...20).reversed().map { Doc.point($0, step: 20 - $0) }
        #expect(throws: GPXImportError.unorderedTimes) { try importer.parseTrack(Doc.gpx([points])) }
    }

    @Test("Size and point limits")
    func limits() throws {
        let data = Doc.gpx([(0...50).map { Doc.point($0) }])
        #expect(throws: GPXImportError.tooLarge) { try GPXRideImporter(maxFileSize: 100).parseTrack(data) }
        #expect(throws: GPXImportError.tooManyPoints) { try GPXRideImporter(maxPoints: 20).parseTrack(data) }
        #expect(try GPXRideImporter(maxPoints: 51).parseTrack(data).pointCount == 51)
    }

    @Test("Reading a big track is fast")
    func speed() throws {
        let points = (0..<60_000).map { Doc.point($0 % 50_000 + ($0 / 50_000) * 100_000, step: $0) }
        let data = Doc.gpx([points])
        let started = Date()
        let track = try importer.parseTrack(data)
        #expect(track.pointCount > 59_000)
        #expect(Date().timeIntervalSince(started) < 5)
    }
}
