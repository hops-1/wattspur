import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@MainActor
@Suite("Ride library")
struct RideLibraryTests {
    let container: ModelContainer
    let library: RideLibrary
    let fixture: Data
    let fixtureName = "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit"

    init() throws {
        let schema = Schema(WattspurSchema.models)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        fixture = try Fixture.data("reinheim-rundfahrt")
    }

    private func allRides() throws -> [Ride] {
        try container.mainContext.fetch(FetchDescriptor<Ride>())
    }

    @Test("Imports a ride with name, Bosch ID, summary, samples and original file")
    func importsRide() throws {
        let result = library.importFile(data: fixture, fileName: fixtureName)
        guard case .imported(let id) = result.outcome else {
            Issue.record("Expected import, got \(result.outcome)")
            return
        }
        let ride = try #require(library.ride(withID: id))
        #expect(ride.name == "Reinheim Rundfahrt")
        #expect(ride.sourceIdentifier == "5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57")
        #expect(ride.sourceFormat == "fit")
        #expect(ride.timerTime == 2916)
        #expect(ride.distance == 19_543)
        #expect(ride.averagePower == 135)
        #expect(ride.workKilojoules > 315)
        #expect(ride.samples.count > 2900)
        #expect(ride.sourceFile?.data == fixture)
        #expect(ride.rider != nil)
        #expect(ride.bike != nil)
        #expect(ride.bike?.serialNumber == nil)
        #expect(ride.deviceSerialNumber == nil) // anonymized fixture (V-05)
    }

    @Test("A second import of the same ride is reported as duplicate")
    func detectsDuplicateByBoschID() throws {
        library.importFile(data: fixture, fileName: fixtureName)
        let second = library.importFile(data: fixture, fileName: fixtureName)
        guard case .duplicate = second.outcome else {
            Issue.record("Expected duplicate, got \(second.outcome)")
            return
        }
        #expect(try allRides().count == 1)
    }

    @Test("Duplicates are also found without a Bosch ID in the file name")
    func detectsDuplicateByStartAndDistance() throws {
        library.importFile(data: fixture, fileName: fixtureName)
        let second = library.importFile(data: fixture, fileName: "renamed.fit")
        guard case .duplicate = second.outcome else {
            Issue.record("Expected duplicate, got \(second.outcome)")
            return
        }
    }

    @Test("Update refreshes values but keeps the local name")
    func updateKeepsName() throws {
        let result = library.importFile(data: fixture, fileName: fixtureName)
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Import failed")
            return
        }
        library.rename(ride, to: "Feierabendrunde")
        ride.distance = 0
        try library.update(ride, with: fixture, fileName: fixtureName)
        #expect(ride.name == "Feierabendrunde")
        #expect(ride.distance == 19_543)
    }

    @Test("Rides from an older parser are re-parsed from the original file, keeping the name")
    func reparsesOutdatedRides() throws {
        let result = library.importFile(data: fixture, fileName: fixtureName)
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Import failed")
            return
        }
        library.rename(ride, to: "Test Fahrt")
        ride.parserVersion = 1
        ride.workKilojoules = 0
        #expect(library.reparseOutdatedRides() == 1)
        #expect(ride.parserVersion == FITRideImporter.parserVersion)
        #expect(abs(ride.workKilojoules - 319.7) < 0.5)
        #expect(ride.name == "Test Fahrt")
        #expect(library.reparseOutdatedRides() == 0)
    }

    @Test("Unsupported and broken files are reported, not imported")
    func rejectsBadFiles() throws {
        let tcx = library.importFile(data: Data("<TrainingCenterDatabase/>".utf8), fileName: "tour.tcx")
        guard case .unsupported = tcx.outcome else {
            Issue.record("Expected unsupported")
            return
        }
        // GPX is read since 1.6: an empty one is broken, not unsupported.
        let gpx = library.importFile(data: Data("<gpx/>".utf8), fileName: "tour.gpx")
        guard case .failed(.gpx(.noTrackPoints)) = gpx.outcome else {
            Issue.record("Expected failure, got \(gpx.outcome)")
            return
        }
        let broken = library.importFile(data: fixture.prefix(500), fileName: "broken.fit")
        guard case .failed = broken.outcome else {
            Issue.record("Expected failure")
            return
        }
        #expect(try allRides().isEmpty)
    }

    @Test("Several rides go to the trash together")
    func trashSeveral() throws {
        let sample = try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: -1).anonymize(fixture)
        library.importFile(data: fixture, fileName: fixtureName)
        library.importFile(data: sample, fileName: "Second.fit")
        let rides = try allRides()
        #expect(rides.count == 2)
        library.moveToTrash(rides)
        #expect(try allRides().allSatisfy(\.isInTrash))
    }

    @Test("Trash: move, restore and purge after 30 days")
    func trash() throws {
        let result = library.importFile(data: fixture, fileName: fixtureName)
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Import failed")
            return
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        library.moveToTrash(ride, at: now)
        #expect(ride.isInTrash)
        library.restore(ride)
        #expect(!ride.isInTrash)

        library.moveToTrash(ride, at: now)
        library.purgeTrash(olderThan: 30, now: now.addingTimeInterval(29 * 86_400))
        #expect(try allRides().count == 1)
        library.purgeTrash(olderThan: 30, now: now.addingTimeInterval(31 * 86_400))
        #expect(try allRides().isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<SourceFile>()).isEmpty)
    }

    @Test("All rides go to one bike although every export has a different serial number")
    func assignsDefaultBike() throws {
        let library = RideLibrary(context: container.mainContext, importers: [StubImporter()])
        for (index, serial) in [500_100_200, 1_204_337_610, 3_991_005_172].enumerated() {
            let result = library.importFile(data: StubImporter.file(start: index, serial: serial), fileName: "ride\(index).stub")
            guard case .imported = result.outcome else {
                Issue.record("Expected import, got \(result.outcome)")
                return
            }
        }
        let bikes = try container.mainContext.fetch(FetchDescriptor<Bike>())
        #expect(bikes.count == 1)
        #expect(bikes.first?.rides?.count == 3)
        #expect(Set(try allRides().compactMap(\.deviceSerialNumber)) == [500_100_200, 1_204_337_610, 3_991_005_172])
    }

    @Test("Re-parsing and updating give a ride without bike the default bike")
    func reparseAssignsDefaultBike() throws {
        let result = library.importFile(data: fixture, fileName: fixtureName)
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Import failed")
            return
        }
        let bike = try #require(ride.bike)
        ride.bike = nil
        ride.parserVersion = 1
        #expect(library.reparseOutdatedRides() == 1)
        #expect(ride.bike === bike)

        ride.bike = nil
        try library.update(ride, with: fixture, fileName: fixtureName)
        #expect(ride.bike === bike)
    }

    @Test("Surplus bikes from earlier versions are merged into one, keeping the serial numbers on the rides")
    func mergesBikes() throws {
        let context = container.mainContext
        var rides: [Ride] = []
        for (index, serial) in [Int64(11), 22, 33].enumerated() {
            let ride = Ride(name: "Ride \(index)", startDate: Date(timeIntervalSince1970: Double(index) * 86_400))
            ride.bike = Bike(serialNumber: serial)
            context.insert(ride)
            rides.append(ride)
        }
        let unassigned = Ride(name: "Without bike", startDate: .now)
        context.insert(unassigned)
        try context.save()

        #expect(library.mergeBikes() == 2)
        let bikes = try context.fetch(FetchDescriptor<Bike>())
        let bike = try #require(bikes.first)
        #expect(bikes.count == 1)
        #expect(bike.serialNumber == nil)
        #expect(bike.rides?.count == 4)
        #expect(rides.map(\.deviceSerialNumber) == [11, 22, 33])
        #expect(unassigned.bike === bike)
        #expect(library.mergeBikes() == 0)
    }

    @Test("Merging keeps a bike the user has named")
    func mergeKeepsNamedBike() throws {
        let context = container.mainContext
        let named = Bike(name: "Cube")
        let other = Bike(serialNumber: 42)
        for bike in [other, other, named] {
            let ride = Ride(name: "Ride", startDate: .now)
            ride.bike = bike
            context.insert(ride)
        }
        try context.save()

        #expect(library.mergeBikes() == 1)
        #expect(try context.fetch(FetchDescriptor<Bike>()).map(\.name) == ["Cube"])
        #expect(library.defaultBike() === named)
    }

    @Test("File names are split into title and Bosch ride ID", arguments: [
        ("Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit", "Reinheim Rundfahrt", "5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57"),
        ("Fahrt Roßdorf bis Reinheim-5E1F0C2A-7B3D-4C8E-9A61-2F4D8B0C3E57.fit", "Fahrt Roßdorf bis Reinheim", "5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57"),
        ("Morgenrunde.fit", "Morgenrunde", nil),
    ])
    func parsesFileNames(input: String, title: String, id: String?) {
        let parsed = RideLibrary.parseFileName(input)
        #expect(parsed.title == title)
        #expect(parsed.sourceIdentifier == id)
    }
}

/// Turns "start;serial" into a ride, to simulate exports with changing serial numbers
/// without adding real ride files (NFR-12).
private struct StubImporter: RideImporter {
    let fileExtensions: Set<String> = ["stub"]
    let parserVersion = 1

    static func file(start: Int, serial: Int) -> Data {
        Data("\(start);\(serial)".utf8)
    }

    func parse(_ data: Data) throws(RideImportError) -> ParsedRide {
        let parts = String(decoding: data, as: UTF8.self).split(separator: ";").compactMap { UInt64($0) }
        guard parts.count == 2 else { throw .noRideData }
        return ParsedRide(
            startDate: Date(timeIntervalSince1970: 1_800_000_000 + Double(parts[0]) * 86_400),
            summary: RideSummary(timerTime: 600, elapsedTime: 600, distance: 3_000),
            samples: [],
            deviceSerialNumber: parts[1],
            parserVersion: parserVersion
        )
    }
}

@MainActor
@Suite("Sample ride")
struct SampleRideTests {
    let container: ModelContainer
    let library: RideLibrary
    let sample: Data

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        sample = try FITAnonymizer(latitudeOffset: 1, longitudeOffset: 1, weeks: -5)
            .anonymize(Fixture.data("reinheim-rundfahrt"))
    }

    @Test("The sample is imported once, marked and named")
    func importOnce() throws {
        let ride = try #require(library.importSample(data: sample, name: "Sample Ride"))
        #expect(ride.isSample)
        #expect(ride.name == "Sample Ride")
        #expect(library.importSample(data: sample, name: "Sample Ride")?.id == ride.id)
        #expect(library.sampleRides().count == 1)
    }

    @Test("It does not collide with the user's own copy of the same ride")
    func noDuplicateOfOriginal() throws {
        let original = library.importFile(data: try Fixture.data("reinheim-rundfahrt"),
                                          fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        guard case .imported = original.outcome else { Issue.record("\(original.outcome)"); return }
        #expect(library.importSample(data: sample, name: "Sample Ride") != nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Ride>()) == 2)
    }

    @Test("Removing deletes the sample for good, also from the trash")
    func remove() throws {
        let ride = try #require(library.importSample(data: sample, name: "Sample Ride"))
        library.moveToTrash(ride)
        #expect(library.importSample(data: sample, name: "Sample Ride")?.isInTrash == false)
        library.removeSamples()
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Ride>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SourceFile>()) == 0)
    }
}
