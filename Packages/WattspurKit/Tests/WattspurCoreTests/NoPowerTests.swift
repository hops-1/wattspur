import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// Rides from files without power, like most GPX files (B-146): sums, averages, records, goals and the
/// comparison work with what is there and say how many rides that is.
@Suite("Calculations without power")
struct NoPowerTests {
    private let calendar = GoalPeriod.calendar(from: Calendar(identifier: .gregorian))
    private let base = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21

    private func bosch(_ day: Int, km: Double = 20, hours: Double = 1, ascent: Int? = 200, power: Int = 150, kJ: Double = 540) -> RideFigures {
        RideFigures(startDate: base.addingTimeInterval(Double(day) * 86_400), distance: km * 1000, timerTime: hours * 3600,
                    totalAscent: ascent, workKilojoules: kJ, averageSpeed: km / hours / 3.6, averagePower: power, averageCadence: 70)
    }

    private func gpx(_ day: Int, km: Double = 30, hours: Double = 2, ascent: Int? = nil) -> RideFigures {
        RideFigures(startDate: base.addingTimeInterval(Double(day) * 86_400), distance: km * 1000, timerTime: hours * 3600,
                    totalAscent: ascent, averageSpeed: km / hours / 3.6)
    }

    // MARK: - Sums and averages

    @Test("Work and calories add up the rides that have power; the others add nothing")
    func sums() {
        let withPower = RideAggregate([bosch(0), bosch(1)])
        let mixed = RideAggregate([bosch(0), bosch(1), gpx(2)])
        #expect(mixed.workKilojoules == withPower.workKilojoules)
        #expect(mixed.kilocalories == withPower.kilocalories)
        #expect(mixed.powerCoverage == ValueCoverage(have: 2, total: 3))
        #expect(mixed.powerCoverage.isPartial)
        // Distance and time count all rides, and so does the CO₂ from the distance.
        #expect(mixed.distance == 70_000)
        #expect(mixed.timerTime == 4 * 3600)
        #expect(mixed.co2SavedKilograms == 70 * RideMetrics.defaultCO2PerKilometre)
    }

    @Test("Without any power there is no calorie figure, but the distance and CO₂ stay")
    func noPowerAtAll() {
        let aggregate = RideAggregate([gpx(0), gpx(1)])
        #expect(aggregate.powerCoverage.isNone)
        #expect(aggregate.workKilojoulesIfKnown == nil)
        #expect(aggregate.kilocaloriesIfKnown == nil)
        #expect(aggregate.averagePower == nil)
        #expect(aggregate.distance == 60_000)
        #expect(aggregate.co2SavedKilograms > 0)
    }

    @Test("No rides: nothing is missing, so nothing is marked")
    func empty() {
        let aggregate = RideAggregate([])
        #expect(aggregate.powerCoverage.total == 0)
        #expect(!aggregate.powerCoverage.isNone && !aggregate.powerCoverage.isPartial)
        #expect(aggregate.kilocaloriesIfKnown == 0)
    }

    @Test("The average power is weighted over the rides that have it")
    func averagePower() {
        let aggregate = RideAggregate([bosch(0, hours: 1, power: 100), bosch(1, hours: 3, power: 200), gpx(2, hours: 10)])
        let expected = (100.0 * 1 + 200.0 * 3) / 4
        #expect(abs((aggregate.averagePower ?? 0) - expected) < 1e-9)
    }

    @Test("Rides without elevation count nothing for the ascent and are counted apart")
    func ascent() {
        let aggregate = RideAggregate([bosch(0, ascent: 300), gpx(1), gpx(2, ascent: 120)])
        #expect(aggregate.ascent == 420)
        #expect(aggregate.ascentCoverage == ValueCoverage(have: 2, total: 3))
        #expect(RideAggregate([gpx(0)]).ascentIfKnown == nil)
        #expect(RideAggregate([gpx(0), bosch(1)]).ascentIfKnown == 200)
    }

    @Test("The trend leaves out rides without the value")
    func trend() {
        let points = RideAnalysis.trend([bosch(0, power: 120), gpx(1), bosch(2, power: 140)], metric: .averagePower)
        #expect(points.map(\.value) == [120, 140])
    }

    // MARK: - Records

    @Test("A ride without power or ascent holds no record for them, but can hold the longest ride")
    func records() {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        let own = HighlightRide(figures: bosch(0, km: 25, ascent: 250, power: 140), timeZone: zone)
        let file = HighlightRide(figures: gpx(1, km: 60, hours: 3), timeZone: zone)
        let records = RideRecords.records([own, file], calendar: calendar)
        func holder(_ kind: RecordKind) -> UUID? { records.first { $0.kind == kind }?.rideIDs.first }
        #expect(holder(.longestDistance) == file.id)
        #expect(holder(.longestDuration) == file.id)
        #expect(holder(.highestAveragePower) == own.id)
        #expect(holder(.mostAscent) == own.id)
        // Only the ride without values: no record exists for them at all.
        let alone = RideRecords.records([file], calendar: calendar)
        #expect(!alone.contains { $0.kind == .highestAveragePower || $0.kind == .mostAscent })
    }

    @Test("The year in review counts all rides and says for how many the ascent is known")
    func yearReview() {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        let rides = [HighlightRide(figures: bosch(0), timeZone: zone), HighlightRide(figures: gpx(1), timeZone: zone)]
        let year = calendar.component(.year, from: base)
        let review = YearReview(rides, year: year, calendar: calendar)
        #expect(review.aggregate.rideCount == 2)
        #expect(review.aggregate.ascentCoverage == ValueCoverage(have: 1, total: 2))
        #expect(review.aggregate.powerCoverage == ValueCoverage(have: 1, total: 2))
    }

    // MARK: - Goals

    @Test("An ascent goal counts the rides with elevation and tells how many rides that is")
    func goals() {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        let now = base.addingTimeInterval(2 * 86_400)
        let rides = [HighlightRide(figures: bosch(0, ascent: 300), timeZone: zone), HighlightRide(figures: gpx(1), timeZone: zone)]
        let progress = GoalProgress(metric: .ascent, period: .year, target: 1000, rides: rides, now: now, calendar: calendar)
        #expect(progress.current.value == 300)
        #expect(progress.ascentCoverage == ValueCoverage(have: 1, total: 2))
        let distance = GoalProgress(metric: .distance, period: .year, target: 1000, rides: rides, now: now, calendar: calendar)
        #expect(distance.current.value == 50_000)
    }

    // MARK: - Comparison

    @Test("In the comparison work and calories of a ride without power are empty, and do not pull the average to zero")
    func comparison() {
        func figures(power: Int?, work: Double) -> ComparisonFigures {
            ComparisonFigures(timerTime: 3600, elapsedTime: 3700, distance: 20_000, averagePower: power, workKilojoules: work, startDate: base)
        }
        let own = figures(power: 150, work: 540)
        let file = figures(power: nil, work: 0)
        let comparison = RideComparison(rides: [own, file], baseline: [own, own, file])
        #expect(comparison.values(.work) == [540, nil])
        #expect(comparison.values(.calories)[1] == nil && comparison.values(.calories)[0] != nil)
        #expect(comparison.values(.workPerKilometre)[1] == nil)
        #expect(comparison.values(.caloriesPerKilometre)[1] == nil)
        // Distance and the CO₂ come from the distance and exist for both.
        #expect(comparison.values(.co2Saved).allSatisfy { $0 != nil })
        #expect(comparison.averages[.work] == 540)
        #expect(comparison.coverage[.work] == ValueCoverage(have: 2, total: 3))
        #expect(comparison.coverage[.distance] == ValueCoverage(have: 3, total: 3))
        #expect(comparison.coverage[.distance]?.isComplete == true)
    }

    @Test("A ride without power takes no part in picking the best average power")
    func best() {
        func figures(power: Int?) -> ComparisonFigures {
            ComparisonFigures(timerTime: 3600, elapsedTime: 3600, distance: 20_000, averagePower: power, workKilojoules: power == nil ? 0 : 500)
        }
        let comparison = RideComparison(rides: [figures(power: 120), figures(power: nil), figures(power: 150)], baseline: [])
        #expect(comparison.bestIndices(.averagePower) == [2])
    }
}
