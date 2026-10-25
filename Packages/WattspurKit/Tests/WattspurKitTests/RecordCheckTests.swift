import Foundation
import SwiftData
import Testing
@testable import WattspurKit

@MainActor
@Suite("New records after an import")
struct RecordCheckTests {
    let container: ModelContainer
    let library: RideLibrary
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    @discardableResult
    private func ride(day: Int, km: Double, speed: Double, sample: Bool = false, importedAt: Date? = nil) -> Ride {
        let ride = Ride(name: "Day \(day)", startDate: start.addingTimeInterval(Double(day) * 86_400 * 3))
        ride.distance = km * 1000
        ride.timerTime = km * 1000 / speed
        ride.averageSpeed = speed
        ride.isSample = sample
        ride.timeZoneIdentifier = "Europe/Berlin"
        container.mainContext.insert(ride)
        if let importedAt {
            let entry = ImportRecord(fileName: "\(ride.name).fit", outcome: .imported, source: .folder, date: importedAt)
            entry.rideID = ride.id
            container.mainContext.insert(entry)
        }
        return ride
    }

    @Test("A faster imported ride breaks the speed record and notes it in the import log")
    func breaksRecord() throws {
        ride(day: 0, km: 30, speed: 6.0)
        let checked = start.addingTimeInterval(100 * 86_400)
        let fast = ride(day: 1, km: 20, speed: 7.5, importedAt: checked.addingTimeInterval(60))
        // Not counted: the sample ride and a ride imported before the last check.
        ride(day: 2, km: 50, speed: 9, sample: true, importedAt: checked.addingTimeInterval(120))
        ride(day: 3, km: 10, speed: 5, importedAt: checked.addingTimeInterval(-60))

        let breaks = library.newRecords(importedAfter: checked)
        let expectedPrevious: Double = 6.0
        #expect(breaks.map(\.kind) == [.highestAverageSpeed])
        #expect(breaks.first?.rideID == fast.id)
        #expect(breaks.first?.previousValue == expectedPrevious)

        let entries = try container.mainContext.fetch(FetchDescriptor<ImportRecord>())
        let entry = try #require(entries.first { $0.rideID == fast.id })
        #expect(entry.recordKinds == [.highestAverageSpeed])
        #expect(library.latestImportDate() == checked.addingTimeInterval(120))
    }

    @Test("Nothing new without imports after the date")
    func nothingNew() {
        ride(day: 0, km: 30, speed: 6.0)
        #expect(library.newRecords(importedAfter: start).isEmpty)
        #expect(library.latestImportDate() == nil)
    }
}
