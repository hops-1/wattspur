import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

@Suite("Ride track for the coupling of charts and map")
struct RideTrackTests {
    /// Heading east at 10 m/s, one sample per second for 100 s; power equals the time.
    private func samples(from start: Int = 0, to end: Int = 100, timeOffset: Double = 0) -> [RideSample] {
        (start...end).map { t in
            RideSample(time: Double(t) + timeOffset, latitude: 51.8, longitude: 10.5 + Double(t) * 10 / 70_000,
                       altitude: 200 + Double(t), distance: Double(t) * 10, speed: 10, power: t)
        }
    }

    @Test("A distance finds the nearest sample with its values")
    func byDistance() throws {
        let track = RideTrack(samples: samples())
        let fix = try #require(track.fix(atDistanceKm: 0.5))
        #expect(fix.time == 50)
        #expect(fix.power == 50)
        #expect(fix.speedKmh == 36)
        #expect(fix.altitude == 250)
        #expect(try #require(track.fix(atDistanceKm: 0.504)).time == 50)
        #expect(try #require(track.fix(atDistanceKm: 0.506)).time == 51)
        #expect(track.fix(atDistanceKm: 5) == nil)
        #expect(track.fix(atDistanceKm: -1) == nil)
    }

    @Test("A time finds the nearest sample; a pause gives nothing")
    func byTime() throws {
        // 0…100 s, a pause, then 500…600 s.
        let track = RideTrack(samples: samples() + samples(from: 0, to: 100, timeOffset: 500))
        #expect(try #require(track.fix(atTime: 42.4)).time == 42)
        #expect(try #require(track.fix(atTime: 550)).time == 550)
        #expect(track.fix(atTime: 300) == nil)
        #expect(track.fix(atTime: 700) == nil)
        #expect(try #require(track.fix(atTime: 103)).time == 100)
    }

    @Test("A position finds the nearest sample and how far away it is")
    func byPosition() throws {
        let track = RideTrack(samples: samples())
        // 3 m north of the sample at 30 s.
        let metresPerDegree = 111_320.0
        let found = try #require(track.fix(nearestToLatitude: 51.8 + 3 / metresPerDegree,
                                           longitude: 10.5 + 30.0 * 10 / 70_000))
        #expect(found.fix.time == 30)
        #expect(abs(found.metres - 3) < 0.5)
        let far = try #require(track.fix(nearestToLatitude: 51.9, longitude: 10.5))
        #expect(far.metres > 10_000)
    }

    @Test("Samples without distance or position are skipped by those searches")
    func gaps() throws {
        let some = [RideSample(time: 0, latitude: 51.8, longitude: 10.5, distance: 0),
                    RideSample(time: 1, power: 5),
                    RideSample(time: 2, latitude: 51.8, longitude: 10.6, distance: 20)]
        let track = RideTrack(samples: some)
        #expect(try #require(track.fix(atDistanceKm: 0.01)).time == 0)
        #expect(try #require(track.fix(nearestToLatitude: 51.8, longitude: 10.59)).fix.time == 2)
        #expect(try #require(track.fix(atTime: 1)).power == 5)
        #expect(RideTrack(samples: []).fix(atTime: 0) == nil)
        #expect(RideTrack(samples: []).fix(atDistanceKm: 0) == nil)
        #expect(RideTrack(samples: []).fix(nearestToLatitude: 0, longitude: 0) == nil)
        #expect(RideTrack(samples: []).isEmpty)
    }
}
