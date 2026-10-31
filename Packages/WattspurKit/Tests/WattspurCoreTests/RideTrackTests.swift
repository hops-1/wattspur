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

    /// A ride of `length` metres with a sample every `step` metres; the altitude comes from `altitude(metres)`.
    private func ride(length: Double = 1000, step: Double = 5, altitude: (Double) -> Double?) -> RideTrack {
        let count = Int(length / step)
        return RideTrack(samples: (0...count).map { i in
            let metres = Double(i) * step
            return RideSample(time: Double(i), altitude: altitude(metres), distance: metres)
        })
    }

    @Test("A ramp of 5 m over 100 m has a grade of 5 %")
    func gradeOfRamp() throws {
        // Flat for 400 m, then 5 % up for 100 m, then flat again.
        let track = ride { metres in 200 + 0.05 * min(max(metres - 400, 0), 100) }
        #expect(abs(try #require(track.grade(atDistanceKm: 0.45)) - 5) < 0.001)
        #expect(abs(try #require(track.grade(atDistanceKm: 0.42)) - 5 * 0.7) < 0.001)
        #expect(abs(try #require(track.grade(atDistanceKm: 0.2))) < 0.001)
        #expect(abs(try #require(track.grade(atDistanceKm: 0.8))) < 0.001)
        // A descent has the opposite sign.
        let down = ride { 300 - 0.03 * $0 }
        #expect(abs(try #require(down.grade(atDistanceKm: 0.5)) + 3) < 0.001)
    }

    @Test("The altitude is interpolated, so sparse samples give the same grade")
    func gradeInterpolates() throws {
        let sparse = ride(step: 40) { 200 + 0.04 * $0 }
        #expect(abs(try #require(sparse.grade(atDistanceKm: 0.51)) - 4) < 0.001)
    }

    @Test("At the ends of the ride the stretch is cut on one side")
    func gradeAtEnds() throws {
        let track = ride { 200 + 0.05 * $0 }
        // At the start only 0…50 m is there, which is still long enough.
        #expect(abs(try #require(track.grade(atDistanceKm: 0.05)) - 5) < 0.001)
        #expect(abs(try #require(track.grade(atDistanceKm: 0)) - 5) < 0.001)
        #expect(abs(try #require(track.grade(atDistanceKm: 1.0)) - 5) < 0.001)
        // A ride of 25 m is shorter than the smallest stretch.
        let short = ride(length: 25) { 200 + 0.05 * $0 }
        #expect(short.grade(atDistanceKm: 0.0125) == nil)
        // Far beyond the ride there is nothing.
        #expect(track.grade(atDistanceKm: 2) == nil)
        #expect(track.grade(atDistanceKm: -1) == nil)
    }

    @Test("Without altitude or without samples there is no grade")
    func gradeWithoutElevation() {
        #expect(ride { _ in nil }.grade(atDistanceKm: 0.5) == nil)
        #expect(RideTrack(samples: []).grade(atDistanceKm: 0) == nil)
    }

    @Test("Noisy altitudes keep the grade calm")
    func gradeWithNoise() throws {
        // 5 % up with the altitude jittering by ±0.5 m between neighbouring points.
        let track = ride(step: 4) { metres in 200 + 0.05 * metres + (Int(metres / 4).isMultiple(of: 2) ? 0.5 : -0.5) }
        let grades = try (20...80).map { try #require(track.grade(atDistanceKm: Double($0) * 0.01)) }
        #expect(grades.allSatisfy { abs($0 - 5) <= 1.01 })
        // Three neighbouring points would swing by ±25 %; here the grade moves by less than 1 point per step.
        let jumps = zip(grades, grades.dropFirst()).map { abs($1 - $0) }
        #expect(jumps.allSatisfy { $0 < 1.01 })
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
