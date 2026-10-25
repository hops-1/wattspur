import Foundation
import Testing
@testable import WattspurKit

/// B-142: totals from the GPX track – ride time without standing still, distance, speeds,
/// ascent from smoothed heights. Start values confirmed by Nils on 25.10.2026.
@Suite("GPX totals from the track")
struct GPXSummaryTests {
    let utc = TimeZone(identifier: "UTC")!
    let start = Date(timeIntervalSince1970: 1_780_732_800)

    /// One part with a point per second; `metresPerSecond(t)` moves it north, `height(t)` gives the height.
    private func track(seconds: Int, metresPerSecond: (Int) -> Double, height: ((Int) -> Double?)? = nil,
                       from first: Int = 0) -> GPXTrack {
        var samples: [RideSample] = []
        var north = 0.0
        for t in first...seconds {
            north += t == first ? 0 : metresPerSecond(t)
            samples.append(RideSample(time: Double(t - first), latitude: 50 + north / 111_195, longitude: 9,
                                      altitude: height?(t), distance: north))
        }
        return GPXTrack(name: nil, creator: nil, activityType: nil,
                        parts: [.init(startDate: start.addingTimeInterval(Double(first)), samples: samples)], discarded: .init())
    }

    @Test("The confirmed start values")
    func startValues() {
        let p = GPXSummaryParameters.standard
        #expect(GPXRideImporter.pauseGap == 30)
        #expect(p.standstillSpeed == 0.8)
        #expect(p.altitudeMedianPoints == 5)
        #expect(p.ascentThreshold == 3)
    }

    @Test("Standing still does not count as ride time, riding does")
    func standing() {
        // 60 s at 5 m/s, 60 s standing, 60 s at 5 m/s.
        let t = track(seconds: 180) { ($0 > 60 && $0 <= 120) ? 0 : 5 }.totals()
        #expect(abs(t.movingTime - 120) <= 10)         // the window of ±5 s blurs the edges
        #expect(abs(t.standingTime - 60) <= 10)
        #expect(abs(t.distance - 600) < 60)
    }

    @Test("A slow climb at 4 km/h is still riding")
    func slowClimb() {
        let t = track(seconds: 120) { _ in 1.1 }.totals()
        #expect(t.standingTime == 0)
        #expect(abs(t.movingTime - 120) < 0.001)
    }

    @Test("GPS jitter while standing adds neither ride time nor distance")
    func jitter() throws {
        let track = try GPXRideImporter().parseTrack(GPXFixture.data("stillstand-gps-drift"))
        let t = track.totals()
        #expect(abs(t.movingTime - 300) < 30)          // the file was made with 300 s of riding
        #expect(t.standingTime > 90)
        #expect(t.distance < track.parts[0].distance - 200)
        #expect(abs(t.distance - 1650) < 100)
    }

    @Test("Bosch Flow tour 1 (anonymized): ride time, and ascent as the FIT reports it")
    func boschTour1() throws {
        let track = try GPXRideImporter().parseTrack(GPXFixture.data("pair-tour1-bosch-flow"))
        let t = track.totals()
        // Anonymized (V-05): the first and last 500 m stand still on one point, so
        // about 200 s and 1.2 km less than the FIT's 2 916 s timer.
        #expect(abs(t.movingTime - 2719) / 2719 < 0.01)
        #expect(abs(t.distance - 17_271) < 5)
        #expect(t.maxSpeed.map { abs($0 - 15.142) / 15.142 < 0.1 } == true) // FIT max 54.5 km/h
        // 3 m threshold (standard) against the 1 m of the FIT: fewer metres on barometric heights.
        #expect(t.ascent == 147)
        #expect(t.descent == 149)
        var fine = GPXSummaryParameters()
        fine.ascentThreshold = 1
        let f = track.totals(fine)
        #expect(f.ascent == 166)                                  // FIT ascent exactly
        #expect(abs((f.descent ?? 0) - 169) <= 1)                 // FIT descent 169
        var coarse = GPXSummaryParameters()
        coarse.ascentThreshold = 5
        #expect((track.totals(coarse).ascent ?? 0) < 147)
    }

    @Test("komoot, same tour: heights from a model give less ascent, ride time is the same")
    func komootTour1() throws {
        let bosch = try GPXRideImporter().parseTrack(GPXFixture.data("pair-tour1-bosch-flow")).totals()
        let komoot = try GPXRideImporter().parseTrack(GPXFixture.data("pair-tour1-komoot")).totals()
        #expect(abs(komoot.movingTime - bosch.movingTime) < 20)
        #expect(abs(komoot.distance - bosch.distance) < 20)
        #expect(komoot.ascent.map { $0 >= 100 && $0 <= 125 } == true)   // 114 at 3 m, against 147 from Bosch
    }

    @Test("Heights: one spike is smoothed away; noise on flat ground adds nothing at 3 m")
    func heights() {
        let spike = track(seconds: 60, metresPerSecond: { _ in 5 }, height: { $0 == 30 ? 340 : 300 }).totals()
        #expect(spike.ascent == 0)
        #expect(spike.descent == 0)

        var seed: UInt64 = 42
        func noise() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return (Double(seed >> 33) / Double(1 << 31) - 0.5) * 3 // ±1.5 m
        }
        let flat = track(seconds: 3600, metresPerSecond: { _ in 5 }, height: { _ in 300 + noise() }).totals()
        #expect((flat.ascent ?? 999) < 40)

        let climb = track(seconds: 600, metresPerSecond: { _ in 5 }, height: { 300 + Double($0) * 0.1 + noise() }).totals()
        #expect(abs((climb.ascent ?? 0) - 60) < 15)                  // 60 m real climb
        #expect((climb.descent ?? 0) < 20)
    }

    @Test("No heights, no ascent; one height alone is none either")
    func noHeights() {
        let t = track(seconds: 30, metresPerSecond: { _ in 5 }).totals()
        #expect(t.ascent == nil)
        #expect(t.descent == nil)
        let one = track(seconds: 30, metresPerSecond: { _ in 5 }, height: { $0 == 3 ? 300 : nil }).totals()
        #expect(one.ascent == nil)
    }

    @Test("The maximum speed comes from a stretch of 5 s, not from one fast step")
    func maxSpeed() {
        // 5 m/s with one step of 60 m (a GPS skip that stayed in the data).
        let t = track(seconds: 60) { $0 == 30 ? 60 : 5 }.totals()
        let top = t.maxSpeed ?? 0
        #expect(top > 5)
        #expect(top < 20)                                           // (60 + 4 × 5) / 5 s = 16 m/s, not 60
        let short = track(seconds: 3, metresPerSecond: { _ in 4 }).totals()
        #expect(abs((short.maxSpeed ?? 0) - 4) < 0.01)              // shorter than the window: the whole part
    }

    @Test("Parts: pauses do not count, heights are counted per part")
    func parts() throws {
        let data = Data("""
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1"><trk><trkseg>\
        \((0...60).map { "<trkpt lat=\"\(50 + 0.00005 * Double($0))\" lon=\"9\"><ele>\(300 + $0 / 2)</ele><time>\(GPXWriter.timestamp(start.addingTimeInterval(Double($0))))</time></trkpt>" }.joined())\
        </trkseg><trkseg>\
        \((0...60).map { "<trkpt lat=\"\(50.1 + 0.00005 * Double($0))\" lon=\"9\"><ele>\(400 - $0 / 2)</ele><time>\(GPXWriter.timestamp(start.addingTimeInterval(600 + Double($0))))</time></trkpt>" }.joined())\
        </trkseg></trk></gpx>
        """.utf8)
        let track = try GPXRideImporter().parseTrack(data)
        let t = track.totals()
        #expect(track.parts.count == 2)
        #expect(abs(t.movingTime - 120) < 0.01)
        // 30 m up in the first part, 30 m down in the second; the last step below 3 m is not counted.
        #expect(abs((t.ascent ?? 0) - 30) <= 3)
        #expect(abs((t.descent ?? 0) - 30) <= 3)
    }

    @Test("The ride built from a GPX file carries the computed totals and is marked estimated")
    func rideSummary() throws {
        let ride = try GPXRideImporter(timeZone: utc).parse(GPXFixture.data("pair-tour1-bosch-flow"))
        let s = ride.summary
        #expect(ride.summaryEstimated)
        #expect(abs(s.timerTime - 2719) < 1)
        #expect(s.elapsedTime > 3300)
        #expect(abs(s.distance - 17_271) < 5)
        #expect(abs((s.averageSpeed ?? 0) - s.distance / s.timerTime) < 1e-9)
        #expect(s.maxSpeed != nil)
        #expect(s.totalAscent == 147)
        #expect(s.totalDescent == 149)
        #expect(s.averagePower == nil)

        var fine = GPXSummaryParameters()
        fine.ascentThreshold = 1
        let custom = try GPXRideImporter(timeZone: utc, summaryParameters: fine).parse(GPXFixture.data("pair-tour1-bosch-flow"))
        #expect(custom.summary.totalAscent == 166)
    }
}
