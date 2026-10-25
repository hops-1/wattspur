import Foundation
import SwiftData
import Testing
@testable import WattspurKit

@Suite("Comparing rides: values, best value, average, deviation")
struct RideComparisonTests {
    /// The reference ride (B-005) with the work measured from its records.
    let reference = ComparisonFigures(
        timerTime: 2916, elapsedTime: 3364, distance: 19_543, averageSpeed: 6.703, maxSpeed: 15.142,
        totalAscent: 166, totalDescent: 169, minAltitude: 150, maxAltitude: 230,
        averagePower: 135, maxPower: 460, averageCadence: 60, maxCadence: 82, workKilojoules: 319.687
    )
    /// A longer, slower ride with more pauses.
    let long = ComparisonFigures(
        timerTime: 5340, elapsedTime: 7020, distance: 33_100, averageSpeed: 6.2, maxSpeed: 13.3,
        totalAscent: 410, totalDescent: 405, minAltitude: 98, maxAltitude: 312,
        averagePower: 121, maxPower: 430, averageCadence: 58, maxCadence: 84, workKilojoules: 540
    )
    /// A ride without power, cadence or altitude data.
    let bare = ComparisonFigures(timerTime: 600, elapsedTime: 600, distance: 3_000, averageSpeed: 5)

    @Test("Every row reads the right value in base units")
    func values() throws {
        let r = reference
        #expect(ComparisonMetric.rideTime.value(of: r) == 2916)
        #expect(ComparisonMetric.totalTime.value(of: r) == 3364)
        #expect(ComparisonMetric.pausedTime.value(of: r) == 448)
        #expect(ComparisonMetric.distance.value(of: r) == 19_543)
        #expect(ComparisonMetric.averageSpeed.value(of: r) == 6.703)
        #expect(ComparisonMetric.ascent.value(of: r) == 166)
        #expect(ComparisonMetric.averagePower.value(of: r) == 135)
        #expect(ComparisonMetric.work.value(of: r) == 319.687)
        let flowKcal: Double = 319.687 * 0.97 + 64.0 * 2916.0 / 3600.0
        #expect(abs(try #require(ComparisonMetric.calories.value(of: r)) - flowKcal) < 1e-9)
        #expect(abs(try #require(ComparisonMetric.co2Saved.value(of: r)) - 19.543 * 0.159) < 1e-9)
    }

    @Test("Per-kilometre values and power over ride time (CMP-03)")
    func derived() throws {
        let r = reference
        let flowKcal: Double = 319.687 * 0.97 + 64.0 * 2916.0 / 3600.0
        #expect(abs(try #require(ComparisonMetric.caloriesPerKilometre.value(of: r)) - flowKcal / 19.543) < 1e-9)
        #expect(abs(try #require(ComparisonMetric.ascentPerKilometre.value(of: r)) - 166 / 19.543) < 1e-9)
        #expect(abs(try #require(ComparisonMetric.workPerKilometre.value(of: r)) - 319.687 / 19.543) < 1e-9)
        #expect(abs(try #require(ComparisonMetric.averagePowerOverRideTime.value(of: r)) - 319_687 / 2916) < 1e-9)
    }

    @Test("Coasting share from work ÷ Bosch average power; close to the count from the samples")
    func coastingShare() throws {
        let share = try #require(ComparisonMetric.coastingShare.value(of: reference))
        #expect(abs(share - (1 - 319_687.0 / 135 / 2916)) < 1e-9)
        #expect(abs(share - 0.188) < 0.001)
        // A merged ride passes the pedalling time of its parts.
        var merged = reference
        merged.pedallingTimeOverride = 2000
        #expect(abs(try #require(ComparisonMetric.coastingShare.value(of: merged)) - (1 - 2000.0 / 2916)) < 1e-9)
    }

    @Test("Missing data gives no value instead of zero")
    func missing() {
        #expect(ComparisonMetric.averagePower.value(of: bare) == nil)
        #expect(ComparisonMetric.coastingShare.value(of: bare) == nil)
        #expect(ComparisonMetric.averagePowerOverRideTime.value(of: bare) == nil)
        #expect(ComparisonMetric.ascentPerKilometre.value(of: bare) == nil)
        #expect(ComparisonMetric.minAltitude.value(of: bare) == nil)
        #expect(ComparisonMetric.workPerKilometre.value(of: ComparisonFigures(timerTime: 0, elapsedTime: 0, distance: 0)) == nil)
    }

    @Test("Only average speed, average power, power over ride time and pauses have a direction")
    func directions() {
        let directed = ComparisonMetric.allCases.filter { $0.direction != .neutral }
        #expect(Set(directed) == [.averageSpeed, .averagePower, .averagePowerOverRideTime, .pausedTime])
        #expect(ComparisonMetric.pausedTime.direction == .lowerIsBetter)
        #expect(ComparisonMetric.averageSpeed.direction == .higherIsBetter)
    }

    @Test("Groups list every metric once, in table order")
    func groups() {
        let all = ComparisonGroup.allCases.flatMap(\.metrics)
        #expect(all == ComparisonMetric.allCases)
        #expect(ComparisonGroup.speed.metrics == [.averageSpeed, .maxSpeed])
    }

    @Test("Best value: higher or lower wins, neutral rows and ties have none")
    func best() {
        let c = RideComparison(rides: [reference, long, bare], baseline: [])
        #expect(c.bestIndices(.averageSpeed) == [0])
        #expect(c.bestIndices(.pausedTime) == [2]) // no pause at all
        #expect(c.bestIndices(.averagePower) == [0]) // the bare ride has no value and is skipped
        #expect(c.bestIndices(.distance).isEmpty) // neutral
        #expect(RideComparison(rides: [reference, reference], baseline: []).bestIndices(.averageSpeed).isEmpty)
        #expect(RideComparison(rides: [reference, bare], baseline: []).bestIndices(.averagePower).isEmpty)
        var twin = long
        twin.averageSpeed = reference.averageSpeed
        #expect(RideComparison(rides: [reference, twin, long], baseline: []).bestIndices(.averageSpeed) == [0, 1])
    }

    @Test("Average: mean per ride, ride averages weighted by time, per-km values by distance")
    func averages() throws {
        let rides = [reference, long, bare]
        // Plain mean per ride (expected values as typed constants: long literal
        // arithmetic inside #expect is too slow to type-check on CI)
        let meanDistance: Double = (19_543 + 33_100 + 3_000) / 3
        #expect(ComparisonMetric.distance.average(over: rides) == meanDistance)
        // Rides without the value are skipped
        let meanAscent: Double = (166 + 410) / 2
        #expect(ComparisonMetric.ascent.average(over: rides) == meanAscent)
        // Weighted by ride time, as in the analysis
        let speedSum: Double = 6.703 * 2916 + 6.2 * 5340 + 5 * 600
        let speedTime: Double = 2916 + 5340 + 600
        let speed = try #require(ComparisonMetric.averageSpeed.average(over: rides))
        #expect(abs(speed - speedSum / speedTime) < 1e-9)
        let powerSum: Double = 135 * 2916 + 121 * 5340
        let powerTime: Double = 2916 + 5340
        let power = try #require(ComparisonMetric.averagePower.average(over: rides))
        #expect(abs(power - powerSum / powerTime) < 1e-9)
        // Weighted by distance: total ascent ÷ total distance
        let expectedPerKm: Double = 576 / 52.643
        let perKm = try #require(ComparisonMetric.ascentPerKilometre.average(over: rides))
        #expect(abs(perKm - expectedPerKm) < 1e-9)
        #expect(ComparisonMetric.distance.average(over: []) == nil)
    }

    @Test("Deviation from the average in base units and percent (CMP-04)")
    func deviation() throws {
        let c = RideComparison(rides: [reference, long], baseline: [reference, long])
        let d = try #require(c.deviation(.distance, ride: 0))
        let mean = (19_543.0 + 33_100) / 2
        #expect(abs(d.absolute - (19_543 - mean)) < 1e-9)
        #expect(abs(try #require(d.relative) - (19_543 - mean) / mean) < 1e-9)
        #expect(c.deviation(.distance, ride: 5) == nil)
        #expect(RideComparison(rides: [bare], baseline: [reference]).deviation(.averagePower, ride: 0) == nil)
        // An average of zero has no percentage.
        let flat = ComparisonFigures(timerTime: 100, elapsedTime: 100, distance: 1000, totalAscent: 0)
        let zero = try #require(RideComparison(rides: [reference], baseline: [flat]).deviation(.ascent, ride: 0))
        #expect(zero.absolute == 166)
        #expect(zero.relative == nil)
    }

    @Test("2 to 4 rides can be compared (CMP-01)")
    func count() {
        #expect(!RideComparison.canCompare(count: 1))
        #expect(RideComparison.canCompare(count: 2))
        #expect(RideComparison.canCompare(count: 4))
        #expect(!RideComparison.canCompare(count: 5))
    }
}

@MainActor
@Suite("Comparing rides – stored rides")
struct RideComparisonLibraryTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        let first = try Fixture.data("reinheim-rundfahrt")
        library.importFile(data: first, fileName: "Reinheim Rundfahrt.fit")
        let second = try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: 1).anonymize(first)
        library.importFile(data: second, fileName: "Heimweg.fit")
    }

    private func rides() throws -> [Ride] {
        try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
    }

    @Test("A ride's figures match its stored Bosch values")
    func figures() throws {
        let ride = try #require(try rides().first)
        let f = ride.comparisonFigures
        #expect(f.timerTime == 2916)
        #expect(f.distance == 19_543)
        #expect(f.averagePower == 135)
        #expect(f.workKilojoules == ride.workKilojoules)
        #expect(f.pedallingTimeOverride == nil)
    }

    @Test("A merged ride takes its pedalling time from the parts; parts and the sample ride do not count")
    func merged() throws {
        let (a, b) = try { let r = try rides(); return (r[0], r[1]) }()
        let pedalling = try #require(a.comparisonFigures.pedallingTime) + (try #require(b.comparisonFigures.pedallingTime))
        let merged = try library.merge([a, b], name: "Both")
        #expect(merged.comparisonFigures.pedallingTimeOverride == pedalling)
        #expect(merged.countsInStatistics)
        #expect(!a.countsInStatistics)
        merged.isSample = true
        #expect(!merged.countsInStatistics)
        merged.isSample = false
        merged.deletedAt = .now
        #expect(!merged.countsInStatistics)
    }
}
