import Foundation
import SwiftData
import Testing
@testable import WattspurCore
@testable import WattspurKit
import TestFixtures

@MainActor
@Suite("Curviness in the library")
struct CurvatureLibraryTests {
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

    @Test("An import calculates the curviness; the figures and the sort key carry it")
    func importSetsIt() throws {
        library.importFile(data: try Fixture.data("reinheim-rundfahrt"), fileName: "A.fit")
        let ride = try #require(try rides().first)
        let perKm = try #require(ride.curvaturePerKm)
        #expect(perKm > 0)
        #expect(ride.curvatureVersion == CurvatureAnalyzer.version)
        #expect(!ride.needsCurvature)
        #expect(ride.figures.curvaturePerKm == perKm)
        #expect(ride.sortKey.curvaturePerKm == perKm)
    }

    @Test("Rides from before this feature get the value in the background, once")
    func backfill() async throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        for week in 1...3 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: week).anonymize(data),
                               fileName: "W\(week).fit")
        }
        let all = try rides()
        let expected = try #require(all[0].curvaturePerKm)
        for ride in all { ride.curvaturePerKm = nil; ride.curvatureVersion = 0 }

        var steps: [Int] = []
        let count = await library.prepareCurvature(batchSize: 1) { done, _ in steps.append(done) }
        #expect(count == 3)
        #expect(steps == [0, 1, 2, 3, 3])
        for ride in all { #expect(ride.curvaturePerKm == expected && !ride.needsCurvature) }
        #expect(await library.prepareCurvature() == 0)
    }

    @Test("A merged ride gets its own value")
    func merged() throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        for week in 1...2 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: week).anonymize(data),
                               fileName: "W\(week).fit")
        }
        let merged = try library.merge(try rides(), name: "Zwei")
        #expect(merged.curvaturePerKm != nil)
        #expect(!merged.needsCurvature)
    }
}
