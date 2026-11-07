import Foundation
import Testing
@testable import WattspurCore

@Suite("Lean, acceleration and sprint figures of a ride")
struct RideMotionTests {
    /// One sample a second with the speed (km/h) and lean given, 10 m further each.
    static func samples(kmh: [Double], lean: [Double?]? = nil, acceleration: [Double?]? = nil,
                        roughness: [Double?]? = nil, start: Double = 0) -> [RideSample] {
        kmh.indices.map { i in
            RideSample(time: start + Double(i), latitude: 49.8 + Double(i) * 0.0001, longitude: 8.8,
                       distance: Double(i) * 10, speed: kmh[i] / 3.6,
                       lean: lean?[i], acceleration: acceleration?[i], roughness: roughness?[i])
        }
    }

    @Test("Rides without lean angles have no motion figures")
    func noMotion() {
        #expect(RideMotion(samples: Self.samples(kmh: [10, 20, 30]), motorized: true) == nil)
    }

    @Test("Strongest lean to each side and strongest speeding up and braking")
    func extremes() throws {
        let motion = try #require(RideMotion(
            samples: Self.samples(kmh: [50, 60, 60, 50, 40],
                                  lean: [0, 32.5, -41.2, 12, 0],
                                  acceleration: [0.3, 0.1, nil, -0.75, -0.2]),
            motorized: true))
        #expect(motion.maxLeanLeft == 32.5)
        #expect(motion.maxLeanRight == 41.2)
        #expect(motion.strongestAcceleration == 0.3)
        #expect(motion.strongestBraking == 0.75)
        #expect(motion.sprint == nil)
    }

    @Test("Only one side or no braking")
    func oneSided() throws {
        let motion = try #require(RideMotion(samples: Self.samples(kmh: [20, 20], lean: [5, 8], acceleration: [0.1, 0.2]),
                                             motorized: false))
        #expect(motion.maxLeanRight == 0)
        #expect(motion.strongestBraking == nil)
    }

    @Test("0 to 100 km/h from the last standstill, crossing interpolated")
    func sprint() throws {
        // Standing, then 30 → 60 → 90 → 110: 100 km/h 3.5 s after the last standstill.
        let kmh: [Double] = [0, 0, 30, 60, 90, 110, 120, 90, 40, 0, 0, 40, 80, 105]
        let motion = try #require(RideMotion(samples: Self.samples(kmh: kmh, lean: kmh.map { _ in 0 }), motorized: true))
        // The second run is the best: 0 at 10 s, 100 between 12 (80) and 13 (105): 12.8 → 2.8 s.
        let sprint = try #require(motion.sprint)
        #expect(sprint.targetKmh == 100)
        #expect(abs(sprint.seconds - 2.8) < 0.001)
        let first = RideMotion.bestSprint(Array(Self.samples(kmh: kmh).prefix(9)), targetKmh: 100)
        #expect(abs((first?.seconds ?? 0) - 3.5) < 0.001)
    }

    @Test("A bicycle sprints to 25 km/h; a slow run or a gap is no sprint")
    func bicycle() throws {
        let motion = try #require(RideMotion(samples: Self.samples(kmh: [0, 8, 16, 22, 27], lean: [0, 0, 0, 0, 0]),
                                             motorized: false))
        #expect(motion.sprint?.targetKmh == 25)
        #expect(abs((motion.sprint?.seconds ?? 0) - 3.6) < 0.001)

        let slow = [0.0] + Array(repeating: 15.0, count: 40) + [30]
        #expect(RideMotion.bestSprint(Self.samples(kmh: slow), targetKmh: 25) == nil)
        let gap = Self.samples(kmh: [0, 10]) + Self.samples(kmh: [20, 30], start: 20)
        #expect(RideMotion.bestSprint(gap, targetKmh: 25) == nil)
    }

    @Test("The track splits where the lean band changes and at a pause")
    func stretches() {
        let samples = Self.samples(kmh: Array(repeating: 50, count: 6), lean: [2, 5, 15, 18, 45, 3])
            + Self.samples(kmh: [50, 50], lean: [1, 1], start: 60)
        let stretches = RideMotion.leanStretches(samples)
        #expect(stretches.map(\.band) == [.upright, .slight, .extreme, .upright])
        // Each piece ends where the next begins.
        #expect(stretches[0].latitude.count == 3)
        #expect(stretches[0].latitude.last == stretches[1].latitude.first)
        #expect(stretches[3].latitude.count == 2)
        #expect(RideMotion.leanStretches(Self.samples(kmh: [10, 10])).isEmpty)
    }

    @Test("Lean bands")
    func bands() {
        #expect(RideMotion.LeanBand(lean: -9.9) == .upright)
        #expect(RideMotion.LeanBand(lean: 10) == .slight)
        #expect(RideMotion.LeanBand(lean: -35) == .strong)
        #expect(RideMotion.LeanBand(lean: 62) == .extreme)
    }

    @Test("A chart slice keeps the strongest lean, not the mean")
    func chartLean() throws {
        let samples = Self.samples(kmh: Array(repeating: 50, count: 4), lean: [20, -30, 10, 5])
        let points = RideSeries.chartPoints(from: samples, bins: 1)
        #expect(try #require(points.first).lean == -30)
        #expect(ChartMeasure.available(in: points).contains(.lean))
        #expect(!ChartMeasure.available(in: RideSeries.chartPoints(from: Self.samples(kmh: [10, 20]))).contains(.lean))
        #expect(RideTrack(samples: samples).fix(atDistanceKm: 0.01)?.lean == -30)
    }

    @Test("Share of the distance on an uneven surface, and the track by surface")
    func surface() throws {
        // Steps of 10 m; the 2nd and 3rd step are uneven or rough, the 4th smooth.
        let samples = Self.samples(kmh: Array(repeating: 30, count: 5), lean: [0, 0, 0, 0, 0],
                                   roughness: [0.05, 0.3, 0.6, 0.05, nil])
        let motion = try #require(RideMotion(samples: samples, motorized: false))
        #expect(abs((motion.roughShare ?? 0) - 2.0 / 3) < 0.001)
        #expect(RideMotion.surfaceStretches(samples).map(\.band) == [.smooth, .uneven, .rough, .smooth])
        #expect(RideMotion.SurfaceBand(roughness: 0.199) == .smooth)
        #expect(RideMotion.SurfaceBand(roughness: 0.2) == .uneven)
        #expect(RideMotion.SurfaceBand(roughness: 0.449) == .uneven)
        #expect(RideMotion.SurfaceBand(roughness: 0.45) == .rough)

        let without = Self.samples(kmh: [30, 30], lean: [0, 0])
        #expect(try #require(RideMotion(samples: without, motorized: false)).roughShare == nil)
        #expect(RideMotion.surfaceStretches(without).isEmpty)
    }
}
