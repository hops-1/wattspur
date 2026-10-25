import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

@Suite("Joins of merged rides")
struct RideMergeJoinTests {
    private let zone = TimeZone(identifier: "Europe/Berlin")!
    /// 19 Oct 2026, 10:00 in Berlin.
    private let morning = Date(timeIntervalSince1970: 1_792_396_800)

    /// A ride heading due east along `latitude`, `metres` long, one sample per 10 s.
    private func part(start: TimeInterval, elapsed: TimeInterval = 600, metres: Double = 1000,
                      latitude: Double = 51.8, from longitude: Double = 10.5, gps: Bool = true) -> RideMerge.Part {
        let degreesPerMetre = 1 / (111_320 * cos(latitude * .pi / 180))
        let samples = stride(from: 0.0, through: elapsed, by: 10).map { t in
            let fraction = t / elapsed
            return RideSample(time: t, latitude: gps ? latitude : nil,
                              longitude: gps ? longitude + fraction * metres * degreesPerMetre : nil,
                              distance: fraction * metres)
        }
        return RideMerge.Part(
            startDate: morning.addingTimeInterval(start),
            summary: RideSummary(timerTime: elapsed, elapsedTime: elapsed, distance: metres),
            samples: samples, workKilojoules: 0)
    }

    private let degreesPerMetre = 1 / (111_320 * cos(51.8 * .pi / 180))

    @Test("Parts that meet give one join with one end, heading east")
    func meeting() throws {
        let a = part(start: 0)
        let b = part(start: 600, from: 10.5 + 1000 * degreesPerMetre)
        let joins = RideMerge.joins(of: [b, a], timeZone: zone)
        let join = try #require(joins.first)
        #expect(joins.count == 1)
        #expect(join.distance == 1000)
        #expect(join.time == 600)
        #expect(join.previousEndTime == 600)
        #expect(join.ends.count == 1)
        #expect(abs(join.ends[0].heading - 90) < 1)
    }

    @Test("A gap in space gives both ends; a pause on the same day shows in the times")
    func gap() throws {
        let a = part(start: 0)
        let b = part(start: 1800, latitude: 51.81, from: 10.51)
        let join = try #require(RideMerge.joins(of: [a, b], timeZone: zone).first)
        #expect(join.ends.count == 2)
        #expect(join.ends[0].latitude == 51.8)
        #expect(join.ends[1].latitude == 51.81)
        #expect(join.previousEndTime == 600)
        #expect(join.time == 1800)
    }

    @Test("Across days the time series runs on right away")
    func acrossDays() throws {
        let a = part(start: 0)
        let b = part(start: 86_400)
        let join = try #require(RideMerge.joins(of: [a, b], timeZone: zone).first)
        #expect(join.time == 600)
        #expect(join.distance == 1000)
    }

    @Test("The join agrees with the merged samples")
    func agreesWithMerge() throws {
        let a = part(start: 0), b = part(start: 1800, from: 10.52), c = part(start: 90_000, metres: 500)
        let joins = RideMerge.joins(of: [a, b, c], timeZone: zone)
        let merged = try RideMerge.merge([a, b, c], timeZone: zone)
        #expect(joins.count == 2)
        for join in joins {
            let next = try #require(merged.samples.first { $0.time >= join.time && $0.distance == join.distance })
            #expect(next.time == join.time)
        }
    }

    @Test("Without positions there is a join but no end; one side with GPS gives its end")
    func missingPositions() throws {
        let a = part(start: 0, gps: false), b = part(start: 600, gps: false)
        let none = try #require(RideMerge.joins(of: [a, b], timeZone: zone).first)
        #expect(none.ends.isEmpty)
        #expect(none.distance == 1000)
        let some = try #require(RideMerge.joins(of: [a, part(start: 600)], timeZone: zone).first)
        #expect(some.ends.count == 1)
    }

    @Test("One part has no joins")
    func single() {
        #expect(RideMerge.joins(of: [part(start: 0)], timeZone: zone).isEmpty)
        #expect(RideMerge.joins(of: [], timeZone: zone).isEmpty)
    }
}
