import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// The library read in one go and off the main thread (B-381): the same values as the single
/// reads of `PhoneDatabase` that `PhoneLibrary.reload()` used before.
@MainActor
@Suite("Library reading")
struct LibraryReadingTests {
    let container: ModelContainer
    let database: PhoneDatabase
    let now = Date(timeIntervalSince1970: 1_800_500_000)

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
    }

    private func save(start: TimeInterval, bikeID: UUID? = nil) throws -> UUID {
        var recording = RideRecording(startDate: Date(timeIntervalSince1970: start))
        for second in 0...120 {
            recording.add(RideRecording.Fix(date: Date(timeIntervalSince1970: start + Double(second)),
                                            latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8,
                                            altitude: 150, horizontalAccuracy: 5, speed: 6))
        }
        let gpx = GPXWriter.document(name: "Runde", segments: recording.gpxSegments, description: nil,
                                     creator: GPXWriter.iPhoneCreator, bikeID: bikeID)
        guard case .imported(let id) = database.saveRecording(gpx: gpx, fileName: "Runde \(start).gpx").outcome else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return id
    }

    /// A library with a bike more, a trashed ride, a merged ride, a goal and a rider.
    private func fill() throws -> (merged: UUID, cargo: UUID) {
        let cargo = database.library.makeBike(name: "Lastenrad", kind: .cargo)
        _ = try save(start: 1_800_000_000, bikeID: cargo.id)
        let first = try save(start: 1_800_100_000)
        let second = try save(start: 1_800_100_400)
        let trashed = try save(start: 1_800_200_000)
        database.moveToTrash(rideID: trashed, at: now)
        let merged = try database.merge([first, second], name: "Ganze Runde")
        database.addGoal(metric: .distance, period: .week, target: 100_000)
        database.updateRider(RiderDetails(name: "Testfahrer"))
        try database.context.save()
        return (merged, cargo.id)
    }

    private func expectSameAsSingleReads(_ reading: LibraryReading) throws {
        #expect(reading.state == (try database.snapshot(generator: "Test", now: now)))
        #expect(reading.trash == database.trash())
        #expect(reading.mergedRideIDs == database.mergedRideIDs())
        #expect(reading.partCounts == Dictionary(uniqueKeysWithValues: database.mergedRideIDs().map { ($0, database.partCount(rideID: $0)) }))
        #expect(reading.rider == database.riderDetails())
        #expect(reading.statsRides == database.statsRides())
        #expect(reading.goals == database.goals())
        #expect(reading.freeGoalCombinations.map { "\($0.period)-\($0.metric)" }
                == database.freeGoalCombinations().map { "\($0.period)-\($0.metric)" })
        #expect(reading.activeDeviceID == database.activeDeviceID())
        for bike in reading.state.bikes {
            #expect(reading.listedRideCounts[bike.id] == database.listedRideCount(deviceID: bike.id))
        }
    }

    @Test("One reading gives what the single reads gave")
    func sameAsBefore() throws {
        let (merged, cargo) = try fill()
        let reading = try LibraryReading.read(in: database.context, generator: "Test", now: now)
        try expectSameAsSingleReads(reading)
        #expect(reading.state.rides.count == 2)
        #expect(reading.trash.count == 1)
        #expect(reading.partCounts == [merged: 2])
        #expect(reading.listedRideCounts[cargo] == 1)
        #expect(reading.goals.count == 1)
        #expect(reading.rider?.name == "Testfahrer")
    }

    @Test("The reader with its own context sees what the iPhone saved, off the main thread")
    func readerOffMain() async throws {
        _ = try fill()
        let reader = LibraryReader(modelContainer: container)
        let reading = try await reader.read(generator: "Test", now: now)
        try expectSameAsSingleReads(reading)

        // A ride saved later is in the next reading.
        _ = try save(start: 1_800_300_000)
        try database.context.save()
        let next = try await reader.read(generator: "Test", now: now)
        #expect(next.state.rides.count == reading.state.rides.count + 1)
    }

    @Test("An empty library reads as empty")
    func empty() throws {
        let reading = try LibraryReading.read(in: database.context, generator: "Test", now: now)
        #expect(reading.state.rides.isEmpty)
        #expect(reading.trash.isEmpty)
        #expect(reading.partCounts.isEmpty)
        #expect(reading.goals.isEmpty)
        #expect(reading.state.bikes.count == 1)
    }
}
