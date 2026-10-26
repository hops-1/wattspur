import Foundation
import SwiftData
import Testing
@testable import WattspurCore
@testable import WattspurKit
import TestFixtures

@MainActor
@Suite("Similar routes in the library")
struct RouteSimilarityLibraryTests {
    /// The sample ride, ridden again in three other weeks, once 10 km further north, once in the
    /// trash and once merged with another.
    @Test("Sample ride, trash and parts of a merged ride stay out; the same route is found")
    func library() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let library = RideLibrary(context: container.mainContext)
        let data = try Fixture.data("reinheim-rundfahrt")
        let sample = try #require(library.importSample(data: data, name: "Sample"))
        for week in 1...4 {
            library.importFile(data: try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: week).anonymize(data),
                               fileName: "W\(week).fit")
        }
        library.importFile(data: try FITAnonymizer(latitudeOffset: 0.1, longitudeOffset: 0, weeks: 5).anonymize(data),
                           fileName: "North.fit")
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
            .filter { !$0.isSample }
        try #require(rides.count == 5)
        let north = try #require(rides.first { $0.name.hasPrefix("North") })
        let weekly = rides.filter { $0.id != north.id }
        let merged = try library.merge([weekly[0], weekly[1]], name: "Zwei")
        library.moveToTrash(weekly[3])

        let all = try container.mainContext.fetch(FetchDescriptor<Ride>())
        let index = RouteIndex(all)
        // Counted: the merged ride, the third week and the ride in the north.
        #expect(index.count == 3)
        #expect(!index.contains(sample.id) && !index.contains(weekly[0].id) && !index.contains(weekly[3].id))
        #expect(index.contains(merged.id) && index.contains(weekly[2].id) && index.contains(north.id))

        let hits = index.similar(to: weekly[2].id)
        #expect(hits.map(\.id) == [merged.id])
        #expect((hits.first?.score ?? 0) > 0.99)
        #expect(index.similar(to: north.id).isEmpty)
    }

    @Test("A ride without GPS is left out")
    func noGPS() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ride = Ride(name: "Indoor", startDate: Date())
        container.mainContext.insert(ride)
        #expect(RouteIndex([ride]).count == 0)
    }
}
