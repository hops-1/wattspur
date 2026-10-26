import Foundation
import SwiftData
import Testing
@testable import WattspurCore
@testable import WattspurKit
import TestFixtures

@MainActor
@Suite("Best minute in the library")
struct PeakPowerLibraryTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    private func rides() throws -> [Ride] {
        try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)])).filter { !$0.isSample }
    }

    @Test("An import calculates the best minute; it lies between the average and the peak")
    func importSetsIt() throws {
        library.importFile(data: try Fixture.data("reinheim-rundfahrt"), fileName: "A.fit")
        let ride = try #require(try rides().first)
        let best = try #require(ride.bestPower1Min)
        #expect(ride.peakPowerVersion == PeakPower.version)
        #expect(best > (ride.averagePower ?? 0))
        #expect(best <= (ride.maxPower ?? 0))
        #expect(!ride.needsPeakPower)
        #expect(ride.figures.bestPower1Min == best && ride.figures.maxPower == ride.maxPower)
    }

    @Test("Rides from before 1.7 get the value in the background, once")
    func backfill() async throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        for week in 1...3 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: week).anonymize(data),
                               fileName: "W\(week).fit")
        }
        let all = try rides()
        let expected = all[0].bestPower1Min
        for ride in all { ride.bestPower1Min = nil; ride.peakPowerVersion = 0 }

        var steps: [Int] = []
        let count = await library.preparePeakPower(batchSize: 1) { done, _ in steps.append(done) }
        #expect(count == 3)
        #expect(steps == [0, 1, 2, 3, 3])
        for ride in all { #expect(ride.bestPower1Min == expected && !ride.needsPeakPower) }
        #expect(await library.preparePeakPower() == 0)
    }

    @Test("A merged ride takes the best minute of its parts")
    func merged() throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        for week in 1...2 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: week).anonymize(data),
                               fileName: "W\(week).fit")
        }
        let parts = try rides()
        parts[0].setPeakPower(250)
        parts[1].setPeakPower(310)
        let merged = try library.merge(parts, name: "Zwei")
        #expect(merged.bestPower1Min == 310)
        #expect(!merged.needsPeakPower)
    }

    @Test("A ride without power values has no best minute but counts as calculated")
    func noPower() throws {
        library.importFile(data: try GPXFixture.data("pair-tour1-komoot"), fileName: "komoot.gpx")
        let ride = try #require(try rides().first)
        #expect(ride.bestPower1Min == nil)
        #expect(!ride.needsPeakPower)
    }
}
