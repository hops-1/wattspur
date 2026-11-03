import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// B-237: wheel distance against GPS distance, as a hint on the wheel circumference.
@Suite("Wheel check")
struct WheelCheckTests {
    /// A straight ride to the north at 7 m/s, one sample per second; the wheel measures `factor` times the GPS.
    static func ride(seconds: Int, factor: Double = 1) -> [RideSample] {
        let metresPerDegree = 6_371_000.0 * .pi / 180
        return (0...seconds).map { t in
            RideSample(time: Double(t), latitude: 49.8 + 7 * Double(t) / metresPerDegree, longitude: 8.8,
                       distance: 7 * Double(t) * factor)
        }
    }

    @Test("A wheel 3 % too large shows 3 %")
    func threePercent() throws {
        let sum = WheelCheck.measure(Self.ride(seconds: 1000, factor: 1.03))
        #expect(abs(sum.gps - 7000) < 1)
        let deviation = try #require(WheelCheck.deviation(Array(repeating: sum, count: 3)))
        #expect(abs(deviation - 0.03) < 0.0005)
        #expect(WheelCheck.hint(Array(repeating: sum, count: 3)) != nil)
    }

    @Test("Below 2 % there is no hint")
    func belowThreshold() {
        let sums = Array(repeating: WheelCheck.measure(Self.ride(seconds: 1000, factor: 1.015)), count: 3)
        #expect(WheelCheck.deviation(sums) != nil)
        #expect(WheelCheck.hint(sums) == nil)
        let smaller = Array(repeating: WheelCheck.measure(Self.ride(seconds: 1000, factor: 0.97)), count: 3)
        #expect(WheelCheck.hint(smaller).map { $0 < -0.02 } == true)
    }

    @Test("Too few rides or too little GPS give no value")
    func notEnoughData() {
        let sum = WheelCheck.measure(Self.ride(seconds: 1000, factor: 1.05))
        #expect(WheelCheck.deviation([sum, sum]) == nil)
        let short = WheelCheck.measure(Self.ride(seconds: 200, factor: 1.05))
        #expect(WheelCheck.deviation([short, short, short]) == nil)   // 1.4 km each
        #expect(WheelCheck.deviation([sum, sum, short]) == nil)       // 14 km usable
    }

    @Test("Gaps, standing and GPS jumps are left out; a sample without GPS is skipped")
    func badSections() {
        var samples = Self.ride(seconds: 200)
        samples[45].latitude = nil                    // skipped, the section 40–50 still counts
        samples[25].latitude! += 0.01                 // jump of about 1 km: section 20–30 is out
        samples.removeSubrange(100..<110)             // gap of 11 s: starts again at 110
        let end = samples.last!
        samples += (1...20).map { RideSample(time: end.time + Double($0), latitude: end.latitude,
                                             longitude: end.longitude, distance: end.distance) }  // standing
        let sum = WheelCheck.measure(samples)
        // Sections of 10 s from 0 to 90 without 20–30, and from 110 to 200: 17 × 70 m.
        #expect(abs(sum.wheel - 17 * 70) < 0.001)
        #expect(abs(sum.gps / sum.wheel - 1) < 0.001)
    }

    @Test("Phone GPS with uneven steps and missing points still counts")
    func unevenPhoneGPS() {
        var samples = Self.ride(seconds: 1000, factor: 1.03)
        for i in samples.indices where i % 2 == 1 { samples[i].latitude! -= 3 / (6_371_000.0 * .pi / 180) }  // 4 m, 10 m, 4 m …
        for i in samples.indices where i % 7 == 3 { samples[i].latitude = nil }
        let sum = WheelCheck.measure(samples)
        #expect(sum.wheel > 0.9 * 7210)
        #expect(abs(sum.wheel / sum.gps - 1.03) < 0.01)
    }

    @Test("Bosch Flow tours: almost the whole ride counts")
    func fixtures() throws {
        for name in ["pair-tour1-bosch-flow", "pair-tour2-bosch-flow"] {
            let ride = try FITRideImporter().parse(GPXFixture.fitData(name))
            let sum = WheelCheck.measure(ride.samples)
            #expect(sum.gps > 0.8 * ride.summary.distance, "\(name)")
            // The bike of the two tours measures about 7 % more at the wheel than GPS.
            #expect((1.05...1.09).contains(sum.wheel / sum.gps), "\(name)")
        }
        let reinheim = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
        #expect(WheelCheck.measure(reinheim.samples).gps > 10_000)
    }
}
