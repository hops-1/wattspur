import Foundation
import Testing
@testable import WattspurCore

@Suite("GPS recording on the iPhone")
struct RideRecordingTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A position `metres` north of the start, `seconds` after it.
    static func fix(_ seconds: Double, north metres: Double, accuracy: Double = 5, altitude: Double? = 100) -> RideRecording.Fix {
        RideRecording.Fix(date: start.addingTimeInterval(seconds), latitude: 49.8 + metres / 111_195,
                          longitude: 8.8, altitude: altitude, horizontalAccuracy: accuracy)
    }

    @Test("Riding at 18 km/h: distance and moving time add up")
    func riding() {
        var recording = RideRecording(startDate: Self.start)
        for second in 0...60 { recording.add(Self.fix(Double(second), north: Double(second) * 5)) }
        #expect(abs(recording.distance - 300) < 1)
        #expect(recording.movingTime == 60)
        #expect(abs(recording.currentSpeed - 5) < 0.1)
    }

    @Test("Average speed over the time in motion, ascent from the smoothed heights (B-243)")
    func averageAndAscent() {
        var recording = RideRecording(startDate: Self.start)
        #expect(recording.averageSpeed == 0)
        #expect(recording.ascent == nil)
        // 60 s at 5 m/s, climbing 0.5 m per second with ±0.5 m of noise: 30 m up.
        for second in 0...60 {
            let noise = second.isMultiple(of: 2) ? 0.5 : -0.5
            recording.add(Self.fix(Double(second), north: Double(second) * 5, altitude: 100 + Double(second) * 0.5 + noise))
        }
        #expect(abs(recording.averageSpeed - 5) < 0.05)
        let ascent = recording.ascent ?? 0
        #expect((28...31).contains(ascent))
    }

    @Test("A recording saved before the ascent cache (0.5.1) gives the same ascent (R-26)")
    func ascentWithoutCache() throws {
        var recording = RideRecording(startDate: Self.start)
        for stretch in 0..<3 {
            for second in 0...10 {
                let t = Double(stretch * 20 + second)
                recording.add(Self.fix(t, north: t * 5, altitude: 100 + t))
            }
            recording.pause()
            recording.resume()
        }
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(recording)) as? [String: Any])
        json["ascentCache"] = nil
        let old = try JSONDecoder().decode(RideRecording.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(recording.ascent != nil)
        #expect(old.ascent == recording.ascent)
    }

    @Test("Ascent adds up over pauses, and stays nil without heights")
    func ascentOverPauses() {
        var recording = RideRecording(startDate: Self.start)
        for second in 0...10 { recording.add(Self.fix(Double(second), north: Double(second) * 5, altitude: 100 + Double(second))) }
        recording.pause()
        recording.resume()
        for second in 20...30 { recording.add(Self.fix(Double(second), north: Double(second) * 5, altitude: 100 + Double(second))) }
        // Each stretch is smoothed on its own, as in the saved GPX, so the two add up.
        var one = RideRecording(startDate: Self.start)
        for second in 0...10 { one.add(Self.fix(Double(second), north: Double(second) * 5, altitude: 100 + Double(second))) }
        let single = one.ascent ?? 0
        #expect(single >= 8)
        #expect(recording.ascent == 2 * single)

        var flat = RideRecording(startDate: Self.start)
        for second in 0...10 { flat.add(Self.fix(Double(second), north: Double(second) * 5, altitude: nil)) }
        #expect(flat.ascent == nil)
    }

    @Test("Inaccurate positions and jumps are dropped")
    func dropsBadFixes() {
        var recording = RideRecording(startDate: Self.start)
        let kept = [
            recording.add(Self.fix(0, north: 0, accuracy: 65)),
            recording.add(Self.fix(0, north: 0, accuracy: -1)),
            recording.add(Self.fix(1, north: 0)),
            recording.add(Self.fix(2, north: 500)),  // 500 m in one second: a jump
            recording.add(Self.fix(3, north: 10)),
            recording.add(Self.fix(3, north: 15)),   // the same time again
        ]
        #expect(kept == [false, false, true, false, true, false])
        #expect(abs(recording.distance - 10) < 0.5)
        #expect(recording.pointCount == 2)
    }

    @Test("At the start only an accurate position begins the track; the GPS jumps of the first seconds are left out")
    func startWaitsForAccurateGPS() {
        // Like the test of 5.11.2026: standing, the GPS jumps by 9, 24 and 12 m in the first seconds.
        var recording = RideRecording(startDate: Self.start)
        let settling = [(0.0, 0.0), (2, 9), (3, 33), (4, 21), (5, 15)]
        for (second, north) in settling {
            let kept = recording.add(Self.fix(second, north: north, accuracy: 25))
            #expect(!kept)
        }
        #expect(recording.isWaitingForGPS)
        let first = recording.add(Self.fix(7, north: 15, accuracy: 8))
        #expect(first)
        #expect(!recording.isWaitingForGPS)
        // Once begun, the normal limit holds again, so a forest does not leave gaps.
        let coarse = recording.add(Self.fix(8, north: 16, accuracy: 25))
        #expect(coarse)
        #expect(recording.distance == 0)
    }

    @Test("Without an accurate position the recording still begins after the start timeout")
    func startTimeout() {
        var recording = RideRecording(startDate: Self.start)
        let early = recording.add(Self.fix(RideRecording.startTimeout - 1, north: 0, accuracy: 20))
        let late = recording.add(Self.fix(RideRecording.startTimeout, north: 0, accuracy: 20))
        #expect(!early)
        #expect(late)
    }

    @Test("The GPS accuracy goes into the GPX and comes back on import")
    func accuracyInGPX() throws {
        var recording = RideRecording(startDate: Self.start)
        recording.add(Self.fix(0, north: 0, accuracy: 4.7))
        recording.add(Self.fix(1, north: 6, accuracy: 12.4))
        let data = GPXWriter.document(name: "Test", segments: recording.gpxSegments, creator: GPXWriter.iPhoneCreator)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("xmlns:wattspur="))
        #expect(text.contains("<wattspur:accuracy>4.7</wattspur:accuracy>"))
        let samples = try GPXRideImporter(timeZone: TimeZone(identifier: "UTC")!).parse(data).samples
        #expect(samples.map(\.horizontalAccuracy) == [4.7, 12.4])
    }

    @Test("On a motorcycle 130 km/h is kept, for an e-bike it is a jump; 500 m in a second is a jump for both")
    func motorcycle() {
        // 36 m a second is about 130 km/h.
        var bike = RideRecording(startDate: Self.start)
        var motorcycle = RideRecording(startDate: Self.start, vehicle: .motorcycle)
        for second in 0...10 {
            bike.add(Self.fix(Double(second), north: Double(second) * 36))
            motorcycle.add(Self.fix(Double(second), north: Double(second) * 36))
        }
        #expect(bike.pointCount == 1)
        #expect(motorcycle.pointCount == 11)
        #expect(abs(motorcycle.distance - 360) < 1)
        let jumpKept = motorcycle.add(Self.fix(11, north: 360 + 500))
        #expect(!jumpKept)
    }

    @Test("The log keeps the vehicle; an old log without it is an e-bike")
    func logKeepsVehicle() throws {
        var log = RecordingLog.line(.start(Self.start))
        log.append(RecordingLog.line(.vehicle(.motorcycle)))
        #expect(RecordingLog.replay(log)?.vehicle == .motorcycle)
        #expect(RecordingLog.replay(RecordingLog.line(.start(Self.start)))?.vehicle == .eBike)
        // A recording encoded before the vehicle existed decodes as an e-bike.
        var json = try #require(String(data: JSONEncoder().encode(RideRecording(startDate: Self.start)), encoding: .utf8))
        json = json.replacingOccurrences(of: #""storedVehicle":"ebike","#, with: "")
            .replacingOccurrences(of: #","storedVehicle":"ebike""#, with: "")
        #expect(!json.contains("storedVehicle"))
        #expect(try JSONDecoder().decode(RideRecording.self, from: Data(json.utf8)).vehicle == .eBike)
    }

    @Test("Standing still: GPS wandering adds no distance and no moving time")
    func standing() {
        var recording = RideRecording(startDate: Self.start)
        for second in 0...120 {
            recording.add(Self.fix(Double(second), north: second.isMultiple(of: 2) ? 0 : 3))
        }
        #expect(recording.distance == 0)
        #expect(recording.movingTime == 0)
    }

    @Test("A pause starts a new segment and the distance does not jump over the gap")
    func pause() {
        var recording = RideRecording(startDate: Self.start)
        recording.add(Self.fix(0, north: 0))
        recording.add(Self.fix(10, north: 50))
        recording.pause()
        let whilePaused = recording.add(Self.fix(20, north: 100))
        #expect(!whilePaused)
        #expect(recording.currentSpeed == 0)
        recording.resume()
        recording.add(Self.fix(300, north: 1000))
        recording.add(Self.fix(310, north: 1050))
        #expect(recording.segments.count == 2)
        #expect(abs(recording.distance - 100) < 1)
        #expect(recording.movingTime == 20)

        let gpx = recording.gpxSegments
        #expect(gpx.count == 2)
        #expect(gpx[1].startDate == Self.start.addingTimeInterval(300))
        #expect(gpx[1].samples.map(\.time) == [0, 10])
        #expect(gpx[0].samples[0].altitude == 100)
    }

    @Test("A recording without two positions a second apart is too short for a GPX track")
    func tooShort() {
        var recording = RideRecording(startDate: Self.start)
        #expect(recording.isTooShort)
        recording.add(Self.fix(0, north: 0))
        recording.add(Self.fix(0.4, north: 0.5))
        #expect(recording.isTooShort)
        recording.add(Self.fix(1, north: 1))
        #expect(!recording.isTooShort)
    }

    @Test("The map route keeps a point every 10 m and the last one")
    func route() {
        var recording = RideRecording(startDate: Self.start)
        for second in 0...100 { recording.add(Self.fix(Double(second), north: Double(second) * 3)) }
        let route = recording.route
        #expect(route.pointCount < 40)
        #expect(route.segments[0].distance.last == recording.distance)
    }

    @Test("The log gives the recording back, even with a line cut off by a crash")
    func log() {
        var data = RecordingLog.line(.start(Self.start))
        var expected = RideRecording(startDate: Self.start)
        for second in 0...20 {
            let fix = Self.fix(Double(second), north: Double(second) * 6)
            expected.add(fix)
            data.append(RecordingLog.line(.fix(fix)))
        }
        data.append(RecordingLog.line(.pause))
        expected.pause()
        data.append(RecordingLog.line(.fix(Self.fix(30, north: 200))).prefix(25))
        #expect(RecordingLog.replay(data) == expected)
        #expect(RecordingLog.replay(Data()) == nil)
    }
}
