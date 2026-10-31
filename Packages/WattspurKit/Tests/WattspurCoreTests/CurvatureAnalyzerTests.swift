import Foundation
import Testing
@testable import WattspurCore

@Suite("Curvature of a track (B-180)")
struct CurvatureAnalyzerTests {
    private let metresPerDegree = 111_320.0
    private let baseLatitude = 51.8
    private let baseLongitude = 10.5

    /// One sample per second along the given points, in metres east and north of the start.
    private func samples(_ points: [(x: Double, y: Double)], from time: Double = 0) -> [RideSample] {
        let cosine = cos(baseLatitude * .pi / 180)
        return points.enumerated().map { i, p in
            RideSample(time: time + Double(i),
                       latitude: baseLatitude + p.y / metresPerDegree,
                       longitude: baseLongitude + p.x / (metresPerDegree * cosine))
        }
    }

    /// A straight line heading east, one point every `step` metres.
    private func line(length: Double, step: Double = 5) -> [(x: Double, y: Double)] {
        stride(from: 0, through: length, by: step).map { ($0, 0) }
    }

    /// `laps` laps of a circle with the given radius, one point every `step` metres.
    private func circle(radius: Double, laps: Double, step: Double = 5) -> [(x: Double, y: Double)] {
        let count = Int(laps * 2 * .pi * radius / step)
        return (0...count).map { i in
            let angle = Double(i) * step / radius
            return (radius * sin(angle), radius * (1 - cos(angle)))
        }
    }

    /// Repeatable noise between -amplitude and +amplitude.
    private func noise(_ points: [(x: Double, y: Double)], amplitude: Double) -> [(x: Double, y: Double)] {
        var state: UInt64 = 42
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 33) / Double(1 << 31) * 2 - 1
        }
        return points.map { ($0.x + next() * amplitude, $0.y + next() * amplitude) }
    }

    @Test("A straight road has no curvature")
    func straight() throws {
        let result = CurvatureAnalyzer.analyze(samples(line(length: 3000)))
        #expect(result.curvature == 0)
        #expect(try #require(result.perKm) == 0)
        #expect(result.length > 2900)
        #expect(result.pieces.count == 1 && result.pieces[0].kind == .straight)
    }

    @Test("GPS jitter does not invent curves on a straight road")
    func jitter() throws {
        let result = CurvatureAnalyzer.analyze(samples(noise(line(length: 3000), amplitude: 1.5)))
        #expect(result.tightShare < 0.02)
        #expect(try #require(result.perKm) < 40)
        #expect(Curviness(perKm: try #require(result.perKm)) == .straight)
    }

    @Test("A circle of 25 m radius is a tight curve all the way")
    func tightCircle() throws {
        let result = CurvatureAnalyzer.analyze(samples(circle(radius: 25, laps: 8)))
        #expect(result.tightShare > 0.97)
        #expect(try #require(result.perKm) > 1_900)
        #expect(result.pieces.allSatisfy { $0.kind == .tight })
        #expect(Curviness(perKm: try #require(result.perKm)) == .veryCurvy)
    }

    @Test("A circle of 100 m radius is a gentle curve, weighing half as much")
    func gentleCircle() throws {
        let result = CurvatureAnalyzer.analyze(samples(circle(radius: 100, laps: 2)))
        #expect(result.tightLength == 0)
        #expect(result.gentleLength / result.length > 0.97)
        #expect(abs(try #require(result.perKm) - 1000) < 40)
    }

    @Test("A circle of 250 m radius counts as straight")
    func wideCircle() throws {
        let result = CurvatureAnalyzer.analyze(samples(circle(radius: 250, laps: 1)))
        #expect(result.curvature == 0)
    }

    @Test("A serpentine road is mostly tight curves")
    func serpentine() throws {
        // Bends of 15 m amplitude over 100 m: the bends have a radius of about 17 m.
        let points = stride(from: 0.0, through: 2000, by: 5).map { x in (x, 15 * sin(2 * .pi * x / 100)) }
        let result = CurvatureAnalyzer.analyze(samples(points))
        #expect(result.tightShare > 0.2)
        #expect(try #require(result.perKm) > 500)
        #expect(Set(result.pieces.map(\.kind)).contains(.tight))
    }

    @Test("A pause adds no length and no curvature")
    func standstill() throws {
        var points = line(length: 1500)
        // 200 s at the same spot, jittering by 1 m.
        let spot = points[points.count / 2]
        let waiting = noise(Array(repeating: spot, count: 200), amplitude: 1)
        points.insert(contentsOf: waiting, at: points.count / 2)
        let with = CurvatureAnalyzer.analyze(samples(points))
        let without = CurvatureAnalyzer.analyze(samples(line(length: 1500)))
        #expect(abs(with.length - without.length) < 30)
        #expect(with.tightLength == 0)
    }

    @Test("A gap in the track ends a run instead of drawing a curve across it")
    func gap() throws {
        // Two straight roads heading east, 500 m apart sideways, like the seam of a merged ride.
        let first = line(length: 1000)
        let second = line(length: 1000).map { ($0.x, $0.y + 500) }
        let result = CurvatureAnalyzer.analyze(samples(first + second))
        #expect(result.curvature == 0)
        #expect(result.length > 1800 && result.length < 2000)
        #expect(result.pieces.count == 2)
    }

    @Test("Without positions or with a very short track there is nothing")
    func nothing() {
        #expect(CurvatureAnalyzer.analyze([]) == CurvatureAnalyzer.Result())
        #expect(CurvatureAnalyzer.analyze([RideSample(time: 0, power: 100)]) == CurvatureAnalyzer.Result())
        let short = CurvatureAnalyzer.analyze(samples(line(length: 50)))
        #expect(short.length == 0 && short.perKm == nil)
        // Under a kilometre that counts there is no figure per kilometre.
        #expect(CurvatureAnalyzer.analyze(samples(circle(radius: 25, laps: 3))).perKm == nil)
    }

    @Test("The kinds follow the radius")
    func kinds() {
        #expect(CurvatureAnalyzer.Kind.of(radius: 10) == .tight)
        #expect(CurvatureAnalyzer.Kind.of(radius: 29.9) == .tight)
        #expect(CurvatureAnalyzer.Kind.of(radius: 30) == .gentle)
        #expect(CurvatureAnalyzer.Kind.of(radius: 174) == .gentle)
        #expect(CurvatureAnalyzer.Kind.of(radius: 175) == .straight)
        #expect(CurvatureAnalyzer.Kind.of(radius: .infinity) == .straight)
        #expect(CurvatureAnalyzer.Kind.tight.weight == 2 && CurvatureAnalyzer.Kind.gentle.weight == 1)
    }

    @Test("The words follow the curvature per kilometre")
    func words() {
        #expect(Curviness(perKm: 0) == .straight)
        #expect(Curviness(perKm: 59.9) == .straight)
        #expect(Curviness(perKm: 60) == .curvy)
        #expect(Curviness(perKm: 199.9) == .curvy)
        #expect(Curviness(perKm: 200) == .veryCurvy)
    }

    @Test("The record counts from 10 km on and only with curves")
    func record() {
        func figures(distance: Double, curves: Double?) -> RideFigures {
            RideFigures(startDate: Date(timeIntervalSince1970: 0), distance: distance, timerTime: 3000, curvaturePerKm: curves)
        }
        #expect(RecordKind.mostCurves.value(of: figures(distance: 25_000, curves: 310)) == 310)
        #expect(RecordKind.mostCurves.value(of: figures(distance: 9_900, curves: 310)) == nil)
        #expect(RecordKind.mostCurves.value(of: figures(distance: 25_000, curves: 0)) == nil)
        #expect(RecordKind.mostCurves.value(of: figures(distance: 25_000, curves: nil)) == nil)
        #expect(RecordKind.mostCurves.isRideRecord)
    }

    @Test("The radius of a circle through three points")
    func radius() {
        let r = CurvatureAnalyzer.circumradius((0, 0), (10, 10), (20, 0))
        // Through (0,0), (10,10), (20,0): centre (10,0), radius 10.
        #expect(abs(r - 10) < 1e-9)
        #expect(CurvatureAnalyzer.circumradius((0, 0), (10, 0), (20, 0)) == .infinity)
    }
}
