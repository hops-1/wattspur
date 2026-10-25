import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@Suite("Bike statistics")
struct BikeStatisticsTests {
    private let day: TimeInterval = 86_400

    @Test("Counts rides, adds the start value and finds the first and last ride")
    func totals() {
        let stats = BikeStatistics(
            rides: [(Date(timeIntervalSince1970: 3 * day), 10_000), (Date(timeIntervalSince1970: day), 4_500), (Date(timeIntervalSince1970: 2 * day), 500)],
            startKilometers: 400)
        #expect(stats.rideCount == 3)
        #expect(stats.ridesDistance == 15_000)
        #expect(stats.startDistance == 400_000)
        #expect(stats.totalDistance == 415_000)
        #expect(stats.firstRide == Date(timeIntervalSince1970: day))
        #expect(stats.lastRide == Date(timeIntervalSince1970: 3 * day))
    }

    @Test("A bike without rides has only its start value and no dates")
    func empty() {
        let stats = BikeStatistics(rides: [], startKilometers: 12.5)
        #expect(stats.rideCount == 0)
        #expect(stats.totalDistance == 12_500)
        #expect(stats.firstRide == nil)
        #expect(stats.lastRide == nil)
    }

    @Test("A negative start value counts as zero")
    func negativeStart() {
        #expect(BikeStatistics(rides: [(.now, 1_000)], startKilometers: -50).totalDistance == 1_000)
    }
}

@MainActor
@Suite("Bikes and profile")
struct BikeTests {
    let container: ModelContainer
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        RideLibrary.defaultBikeName = "Mein eBike"
    }

    private func ride(_ name: String, day: Int, distance: Double, bike: Bike?) -> Ride {
        let ride = Ride(name: name, startDate: Date(timeIntervalSince1970: Double(day) * 86_400))
        ride.distance = distance
        ride.bike = bike
        context.insert(ride)
        return ride
    }

    @Test("New bikes and the rider start with the values CloudKit needs")
    func defaults() {
        let bike = Bike()
        #expect(bike.kind == .bike)
        #expect(bike.isEbike)
        #expect(bike.color == .blue)
        #expect(bike.startKilometers == 0)
        #expect(!bike.isArchived)
        #expect(bike.photoData == nil && bike.batteryWh == nil && bike.purchaseDate == nil)
        let rider = Rider()
        #expect(rider.sex == .unspecified)
        #expect(rider.weightKg == nil && rider.heightCm == nil && rider.birthYear == nil)
        #expect(rider.activeBikeID == nil)
    }

    @Test("Unknown raw values fall back to the defaults")
    func rawValueFallback() {
        let bike = Bike()
        bike.kindRawValue = "tandem"
        bike.colorRawValue = "mauve"
        #expect(bike.kind == .bike)
        #expect(bike.color == .blue)
        let rider = Rider()
        rider.sexRawValue = "x"
        #expect(rider.sex == .unspecified)
    }

    @Test("All profile and bike data survive a save")
    func storesAllFields() throws {
        let rider = library.defaultRider()
        rider.weightKg = 78.5
        rider.heightCm = 182
        rider.birthYear = 1988
        rider.sex = .female
        rider.photoData = Data([1, 2, 3])
        let bike = library.makeBike(name: "Gravel", kind: .gravel, color: .orange)
        bike.isEbike = false
        bike.photoData = Data([9, 8])
        bike.manufacturer = "Canyon"
        bike.model = "Grizl"
        bike.driveUnit = "Bosch Performance Line SX"
        bike.batteryWh = 400
        bike.weightKg = 17.2
        bike.purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        bike.startKilometers = 250
        try context.save()

        let fetchedRider = try #require(try context.fetch(FetchDescriptor<Rider>()).first)
        #expect(fetchedRider.weightKg == 78.5 && fetchedRider.heightCm == 182 && fetchedRider.birthYear == 1988)
        #expect(fetchedRider.sex == .female)
        #expect(fetchedRider.photoData == Data([1, 2, 3]))
        let fetched = try #require(try context.fetch(FetchDescriptor<Bike>()).first { $0.name == "Gravel" })
        #expect(fetched.kind == .gravel && fetched.color == .orange && !fetched.isEbike)
        #expect(fetched.photoData == Data([9, 8]))
        #expect([fetched.manufacturer, fetched.model, fetched.driveUnit] == ["Canyon", "Grizl", "Bosch Performance Line SX"])
        #expect(fetched.batteryWh == 400 && fetched.weightKg == 17.2 && fetched.startKilometers == 250)
        #expect(fetched.rider === fetchedRider)
        #expect(fetchedRider.bikes?.contains { $0 === fetched } == true)
    }

    @Test("The first active bike is created as \"Mein eBike\" and belongs to the rider")
    func firstBike() throws {
        let bike = library.activeBike()
        #expect(bike.name == "Mein eBike")
        #expect(bike.rider === library.defaultRider())
        #expect(library.defaultRider().activeBikeID == bike.id)
        #expect(library.activeBike() === bike)
        #expect(try context.fetch(FetchDescriptor<Bike>()).count == 1)
    }

    @Test("Bikes get positions after the existing ones; an empty name becomes the default")
    func makeBikeOrder() {
        let first = library.makeBike(name: "  ")
        let second = library.makeBike(name: "Gravel", kind: .gravel, color: .orange)
        let third = library.makeBike(name: "E-MTB", kind: .mountain, color: .teal)
        #expect(first.name == "Mein eBike")
        #expect([first, second, third].map(\.sortOrder) == [0, 1, 2])
        #expect(library.bikes().map(\.name) == ["Mein eBike", "Gravel", "E-MTB"])
    }

    @Test("Imported rides go to the active bike")
    func importGoesToActiveBike() throws {
        let fixture = try Fixture.data("reinheim-rundfahrt")
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        library.setActiveBike(gravel)
        let result = library.importFile(data: fixture, fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        guard case .imported(let id) = result.outcome else {
            Issue.record("Import failed")
            return
        }
        #expect(library.ride(withID: id)?.bike === gravel)
        #expect(first.rides?.isEmpty == true)
    }

    @Test("An archived bike cannot be set active")
    func archivedNotActive() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        try library.archive(gravel)
        library.setActiveBike(gravel)
        #expect(library.activeBike() === first)
    }

    @Test("Archiving the active bike hands over to the next one; its rides stay")
    func archiveActive() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        let kept = ride("Tour", day: 1, distance: 5_000, bike: first)
        try library.archive(first)
        #expect(first.isArchived)
        #expect(kept.bike === first)
        #expect(library.activeBike() === gravel)
        #expect(library.bikes(includingArchived: false).map(\.name) == ["Gravel"])
        #expect(library.bikes().count == 2)
    }

    @Test("The last open bike cannot be archived")
    func lastBike() throws {
        let only = library.activeBike()
        #expect(throws: RideLibrary.ArchiveError.lastBike) { try library.archive(only) }
        #expect(!only.isArchived)
    }

    @Test("A restored bike is open again but not active")
    func unarchive() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        try library.archive(gravel)
        library.unarchive(gravel)
        #expect(!gravel.isArchived)
        #expect(library.activeBike() === first)
        #expect(library.bikes(includingArchived: false).count == 2)
    }

    @Test("Statistics skip rides in the trash, the sample ride and parts of merged rides")
    func statisticsFilters() throws {
        let bike = library.activeBike()
        bike.startKilometers = 100
        _ = ride("A", day: 1, distance: 10_000, bike: bike)
        _ = ride("B", day: 5, distance: 20_000, bike: bike)
        let trashed = ride("Trash", day: 9, distance: 7_000, bike: bike)
        trashed.deletedAt = .now
        let sample = ride("Sample", day: 8, distance: 6_000, bike: bike)
        sample.isSample = true
        let merged = ride("Merged", day: 3, distance: 30_000, bike: bike)
        for (index, part) in [ride("Part 1", day: 3, distance: 12_000, bike: bike), ride("Part 2", day: 3, distance: 18_000, bike: bike)].enumerated() {
            part.mergedInto = merged
            part.startDate = merged.startDate.addingTimeInterval(Double(index) * 3_600)
        }
        try context.save()

        let stats = library.statistics(for: bike)
        #expect(stats.rideCount == 3)
        #expect(stats.ridesDistance == 60_000)
        #expect(stats.totalDistance == 160_000)
        #expect(stats.firstRide == Date(timeIntervalSince1970: 86_400))
        #expect(stats.lastRide == Date(timeIntervalSince1970: 5 * 86_400))
    }

    @Test("Each bike counts only its own rides")
    func statisticsPerBike() {
        let a = library.activeBike()
        let b = library.makeBike(name: "Gravel")
        _ = ride("A1", day: 1, distance: 1_000, bike: a)
        _ = ride("B1", day: 2, distance: 2_000, bike: b)
        _ = ride("B2", day: 3, distance: 3_000, bike: b)
        #expect(a.statistics.rideCount == 1)
        #expect(b.statistics.rideCount == 2)
        #expect(b.statistics.ridesDistance == 5_000)
    }

    @Test("A library from before 1.5 gets one named bike for the rider; all rides stay on it")
    func migratesOldLibrary() throws {
        let old = Bike()  // as an earlier version made it: unnamed, no rider, no position, no active bike
        let rider = Rider()
        context.insert(old)
        context.insert(rider)
        let rides = (0..<3).map { ride("Ride \($0)", day: $0, distance: 1_000, bike: old) }
        try context.save()

        #expect(library.prepareBikes())
        let bikes = try context.fetch(FetchDescriptor<Bike>())
        #expect(bikes.count == 1)
        #expect(old.name == "Mein eBike")
        #expect(old.rider === rider)
        #expect(rider.activeBikeID == old.id)
        #expect(rides.allSatisfy { $0.bike === old })
        #expect(old.statistics.rideCount == 3)
        #expect(!library.prepareBikes())
    }

    @Test("An empty library gets its first bike at launch")
    func migratesEmptyLibrary() throws {
        #expect(library.prepareBikes())
        #expect(library.bikes().map(\.name) == ["Mein eBike"])
        #expect(!library.prepareBikes())
    }

    @Test("Migration keeps a name the user chose and uses the localized default for the rest")
    func migrationNames() throws {
        RideLibrary.defaultBikeName = "My eBike"
        defer { RideLibrary.defaultBikeName = "Mein eBike" }
        let named = Bike(name: "Cube")
        let unnamed = Bike(name: " ")
        context.insert(named)
        context.insert(unnamed)
        try context.save()
        library.prepareBikes()
        #expect(Set(library.bikes().map(\.name)) == ["Cube", "My eBike"])
    }

    @Test("Bikes without a position keep their creation order")
    func migrationOrder() throws {
        let older = Bike(name: "Old")
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        let newer = Bike(name: "New")
        newer.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(newer)
        context.insert(older)
        try context.save()
        library.prepareBikes()
        #expect(library.bikes().map(\.name) == ["Old", "New"])
        #expect(Set(library.bikes().map(\.sortOrder)).count == 2)
    }

    @Test("Merging leftovers of earlier versions leaves bikes made in the profile alone")
    func mergeKeepsProfileBikes() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        let legacy = Bike(serialNumber: 99)
        context.insert(legacy)
        let legacyRide = ride("Legacy", day: 1, distance: 1_000, bike: legacy)
        try context.save()

        #expect(library.mergeBikes() == 1)
        #expect(Set(library.bikes().map(\.name)) == ["Mein eBike", "Gravel"])
        #expect(legacyRide.bike === first)
        #expect(legacyRide.deviceSerialNumber == 99)
        #expect(gravel.rides?.isEmpty == true)
        #expect(library.mergeBikes() == 0)
    }

    @Test("Rides without a bike go to the active bike")
    func orphansGoToActiveBike() throws {
        _ = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        library.setActiveBike(gravel)
        let orphan = ride("Orphan", day: 1, distance: 1_000, bike: nil)
        try context.save()
        library.mergeBikes()
        #expect(orphan.bike === gravel)
    }
}

@MainActor
@Suite("Assigning rides to bikes")
struct BikeAssignTests {
    let container: ModelContainer
    let undo = UndoManager()
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        undo.groupsByEvent = false
        library = RideLibrary(context: container.mainContext, undoManager: undo)
        RideLibrary.defaultBikeName = "Mein eBike"
    }

    /// One group per user action, as the app's event loop makes them.
    private func step(_ body: () -> Void) {
        undo.beginUndoGrouping()
        defer { undo.endUndoGrouping() }
        body()
    }

    private func ride(_ name: String, day: Int, bike: Bike?) -> Ride {
        let ride = Ride(name: name, startDate: Date(timeIntervalSince1970: Double(day) * 86_400))
        ride.distance = 5_000
        ride.timerTime = 600
        ride.elapsedTime = 600
        ride.bike = bike
        context.insert(ride)
        return ride
    }

    @Test("Several rides move to another bike in one step")
    func assignsRides() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        let rides = [ride("A", day: 1, bike: first), ride("B", day: 2, bike: first), ride("C", day: 3, bike: gravel)]
        var changed = 0
        step { changed = library.assign(rides, to: gravel) }
        #expect(changed == 2)
        #expect(rides.allSatisfy { $0.bike === gravel })
        #expect(first.rides?.isEmpty == true)
        #expect(gravel.statistics.rideCount == 3)
    }

    @Test("⌘Z puts every ride back on its own bike, redo assigns again")
    func undoAndRedo() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        let cargo = library.makeBike(name: "E-MTB")
        let a = ride("A", day: 1, bike: first)
        let b = ride("B", day: 2, bike: cargo)
        step { library.assign([a, b], to: gravel) }
        #expect(a.bike === gravel && b.bike === gravel)
        undo.undo()
        #expect(a.bike === first)
        #expect(b.bike === cargo)
        undo.redo()
        #expect(a.bike === gravel && b.bike === gravel)
    }

    @Test("Assigning to the bike the rides already have changes nothing")
    func noChange() throws {
        let first = library.activeBike()
        let a = ride("A", day: 1, bike: first)
        var changed = -1
        step { changed = library.assign([a], to: first) }
        #expect(changed == 0)
        #expect(a.bike === first)
    }

    @Test("A merged ride takes its parts along, so splitting it keeps the bike")
    func mergedRideTakesParts() throws {
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        let merged = ride("Merged", day: 1, bike: first)
        let parts = [ride("Part 1", day: 1, bike: first), ride("Part 2", day: 1, bike: first)]
        for part in parts { part.mergedInto = merged }
        step { library.assign([merged], to: gravel) }
        #expect(merged.bike === gravel)
        #expect(parts.allSatisfy { $0.bike === gravel })
        undo.undo()
        #expect(merged.bike === first)
        #expect(parts.allSatisfy { $0.bike === first })
    }

    @Test("Assigning to an archived bike is possible: its rides stay in the filters")
    func archivedTarget() throws {
        let first = library.activeBike()
        let old = library.makeBike(name: "Old")
        try library.archive(old)
        let a = ride("A", day: 1, bike: first)
        step { library.assign([a], to: old) }
        #expect(a.bike === old)
    }

    @Test("Rides merged from two bikes belong to the bike of the first part")
    func mergeTakesFirstPartsBike() throws {
        let fixtureA = try Fixture.data("reinheim-rundfahrt")
        let first = library.activeBike()
        let gravel = library.makeBike(name: "Gravel")
        library.importFile(data: fixtureA, fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        let early = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
        // A second ride a few minutes later, on another bike.
        let later = Ride(name: "Later", startDate: early.startDate.addingTimeInterval(early.elapsedTime + 600))
        later.timerTime = 300
        later.elapsedTime = 300
        later.samplesData = early.samplesData
        later.bike = gravel
        context.insert(later)
        try context.save()
        #expect(early.bike === first)

        var merged: Ride?
        step { merged = try? library.merge([later, early], name: "Both") }
        #expect(merged?.bike === first)
        #expect(later.bike === gravel)
    }
}

@MainActor
@Suite("First bike and body data")
struct FirstBikeTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        RideLibrary.defaultBikeName = "Mein eBike"
    }

    @Test("The first bike gets the chosen name and color; it stays the only one and the active one")
    func configuresFirstBike() throws {
        library.prepareBikes()
        let bike = library.configureActiveBike(name: "  Stadtflitzer ", color: .teal)
        #expect(bike.name == "Stadtflitzer")
        #expect(bike.color == .teal)
        #expect(try container.mainContext.fetch(FetchDescriptor<Bike>()).count == 1)
        #expect(library.activeBike() === bike)
    }

    @Test("A blank name keeps the name that is there")
    func blankNameKept() {
        library.prepareBikes()
        let bike = library.configureActiveBike(name: "   ", color: .pink)
        #expect(bike.name == "Mein eBike")
        #expect(bike.color == .pink)
    }

    @Test("Without a bike yet, one is made first")
    func createsBike() throws {
        let bike = library.configureActiveBike(name: "Gravel", color: .orange)
        #expect(bike.name == "Gravel")
        #expect(try container.mainContext.fetch(FetchDescriptor<Bike>()).count == 1)
    }

    @Test("Body data are stored; implausible values and nothing are dropped")
    func bodyData() {
        library.setBodyData(weightKg: 78.5, heightCm: 182, birthYear: 1988, sex: .male)
        let rider = library.defaultRider()
        #expect(rider.weightKg == 78.5 && rider.heightCm == 182 && rider.birthYear == 1988 && rider.sex == .male)
        #expect(rider.bodyProfile.isComplete)

        library.setBodyData(weightKg: 7, heightCm: nil, birthYear: 2999, sex: .unspecified)
        #expect(rider.weightKg == nil && rider.heightCm == nil && rider.birthYear == nil)
        #expect(rider.sex == .unspecified)
        #expect(!rider.bodyProfile.isComplete)
    }
}
