import Foundation
import Testing
@testable import WattspurKit

@Suite("Ride series for charts and map")
struct RideSeriesTests {
    let ride: ParsedRide

    init() throws {
        ride = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
    }

    @Test("Chart points cover the whole distance in equal bins")
    func chartPoints() {
        let points = RideSeries.chartPoints(from: ride.samples, bins: 200)
        #expect(points.count == 200)
        #expect(points.map(\.distanceKm) == points.map(\.distanceKm).sorted())
        #expect((points.last?.distanceKm ?? 0) > 19.4 && (points.last?.distanceKm ?? 0) < 19.6)
        #expect(points.allSatisfy { $0.altitude != nil && $0.speedKmh != nil && $0.power != nil })
    }

    @Test("Averaged values stay in plausible ranges")
    func ranges() {
        let points = RideSeries.chartPoints(from: ride.samples)
        let altitudes = points.compactMap(\.altitude)
        #expect((altitudes.min() ?? 0) > 145 && (altitudes.max() ?? 0) < 270)
        #expect((points.compactMap(\.speedKmh).max() ?? 0) <= 54.6)
        #expect((points.compactMap(\.power).max() ?? 0) <= 460)
    }

    @Test("The route is thinned out but keeps start and end")
    func route() {
        let route = RideSeries.route(from: ride.samples, maxPoints: 500)
        #expect(route.count == 500)
        let all = RideSeries.route(from: ride.samples, maxPoints: .max)
        #expect(route.first == all.first)
        #expect(route.last == all.last)
    }

    @Test("Steepest gradient over 100 m: plausible for the sample ride, exact for a ramp")
    func steepestGradient() throws {
        let grade = try #require(RideSeries.steepestGradient(from: ride.samples))
        #expect(grade > 0.02 && grade < 0.2)
        // 0 m … 1000 m flat, then 6 % up for 500 m, sampled every 10 m.
        let ramp = (0...150).map { i -> RideSample in
            let d = Double(i) * 10
            return RideSample(time: Double(i), altitude: d <= 1000 ? 100 : 100 + (d - 1000) * 0.06, distance: d)
        }
        let rampGrade = try #require(RideSeries.steepestGradient(from: ramp))
        #expect(abs(rampGrade - 0.06) < 1e-9)
        #expect(RideSeries.steepestGradient(from: Array(ramp.prefix(5))) == nil) // shorter than 100 m
        #expect(RideSeries.steepestGradient(from: []) == nil)
    }

    @Test("Empty input gives empty series")
    func empty() {
        #expect(RideSeries.chartPoints(from: []).isEmpty)
        #expect(RideSeries.route(from: []).isEmpty)
    }
}

@Suite("Chart points over time")
struct TimeAxisTests {
    /// One sample per second with a steady 25 km/h and the distance that goes with it.
    private func samples(_ range: ClosedRange<Int>, power: Int = 100) -> [RideSample] {
        range.map { t in
            let metresPerSecond: Double = 25.0 / 3.6
            return RideSample(time: Double(t), altitude: 100, distance: Double(t) * metresPerSecond,
                              speed: metresPerSecond, power: power)
        }
    }

    @Test("Bins cover the time from the start; the time is in seconds")
    func coversTime() {
        let points = RideSeries.chartPoints(from: samples(0...1000), axis: .time, bins: 100)
        #expect(points.count == 100)
        #expect(points.map(\.seconds) == points.map(\.seconds).sorted())
        let lastSeconds: Double = points.last?.seconds ?? 0
        #expect(abs(lastSeconds - 995.0) < 0.001)
        #expect(Set(points.map(\.segment)) == [0])
        let lastSpeed: Double = points.last?.speedKmh ?? 0
        #expect(abs(lastSpeed - 25.0) < 0.001)
        // Kilometres follow along, for the join lines and the coupling later.
        let expectedKm: Double = 995.0 * 25.0 / 3.6 / 1000.0
        #expect(abs((points.last?.distanceKm ?? 0) - expectedKm) < 0.05)
    }

    @Test("A pause leaves the bins inside it out and starts a new segment")
    func pause() {
        // 0…500 s, nothing for 500…1500 s, then 1500…2000 s.
        let all = samples(0...500) + samples(1500...2000, power: 300)
        let points = RideSeries.chartPoints(from: all, axis: .time, bins: 200)
        #expect(!points.isEmpty)
        let width = 2000.0 / 200
        #expect(!points.contains { $0.seconds > 500 + width && $0.seconds < 1500 - width })
        #expect(Set(points.map(\.segment)) == [0, 1])
        #expect(points.filter { $0.segment == 0 }.allSatisfy { $0.power == 100 })
        #expect(points.filter { $0.segment == 1 }.allSatisfy { $0.power == 300 })
        let firstSecond = points.first { $0.segment == 1 }
        #expect((firstSecond?.seconds ?? 0) > 1400)
    }

    @Test("A short break between samples does not break the line")
    func shortBreak() {
        let all = samples(0...300) + samples(310...600)
        let points = RideSeries.chartPoints(from: all, axis: .time, bins: 100)
        #expect(Set(points.map(\.segment)) == [0])
    }

    @Test("The distance axis is unchanged and has one segment")
    func distanceAxis() {
        let all = samples(0...1000)
        #expect(RideSeries.chartPoints(from: all, axis: .distance) == RideSeries.chartPoints(from: all))
    }

    @Test("Very short rides get fewer bins and no holes")
    func shortRide() {
        let points = RideSeries.chartPoints(from: samples(0...20), axis: .time, bins: 400)
        #expect(points.count == 5)
        #expect(Set(points.map(\.segment)) == [0])
        #expect(RideSeries.chartPoints(from: [], axis: .time).isEmpty)
        #expect(RideSeries.chartPoints(from: samples(0...0), axis: .time).isEmpty)
    }
}
