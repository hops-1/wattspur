import Foundation
import SwiftData
import Testing
@testable import WattspurKit

@MainActor
@Suite("Goals in the library")
struct GoalLibraryTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    private func goals() throws -> [Goal] {
        try container.mainContext.fetch(FetchDescriptor<Goal>())
    }

    @Test("A goal is added, changed and deleted through the library")
    func addUpdateDelete() throws {
        let goal = library.addGoal(metric: .distance, period: .week, target: 100_000)
        #expect(try goals().count == 1)

        library.update(goal, metric: .rides, period: .month, target: 12)
        let stored = try #require(try goals().first)
        #expect(stored.metric == .rides)
        #expect(stored.period == .month)
        #expect(stored.target == 12)

        library.delete(goal)
        #expect(try goals().isEmpty)
    }

    @Test("Rides without a time zone are found until one is set")
    func ridesWithoutTimeZone() throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        library.importFile(data: data, fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        let ride = try #require(library.ridesWithoutTimeZone().first)
        ride.timeZoneIdentifier = "Europe/Berlin"
        library.save()
        #expect(library.ridesWithoutTimeZone().isEmpty)
    }
}
