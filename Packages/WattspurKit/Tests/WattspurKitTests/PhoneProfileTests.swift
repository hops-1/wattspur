import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// The profile on the iPhone (B-299): totals and records per sport, the devices by sport, and the
/// rider edited on the iPhone. All rides here are made up.
@MainActor
@Suite("Profile on the iPhone")
struct PhoneProfileTests {
    let container: ModelContainer
    let database: PhoneDatabase
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
        library = RideLibrary(context: container.mainContext)
    }

    @discardableResult
    private func ride(_ name: String, on bike: Bike?, kind: BikeKind? = nil, km: Double, minutes: Double,
                      maxKmh: Double?, day: Double) -> Ride {
        let ride = Ride(name: name, startDate: Date(timeIntervalSince1970: 1_800_000_000 + day * 86_400))
        ride.distance = km * 1000
        ride.timerTime = minutes * 60
        ride.elapsedTime = minutes * 60
        ride.maxSpeed = maxKmh.map { $0 / 3.6 }
        context.insert(ride)
        ride.bike = bike
        ride.sportRawValue = kind?.rawValue
        return ride
    }

    @Test("Each sport has its own totals and records; a car never lands in cycling")
    func totalsPerSport() throws {
        let cube = library.makeBike(name: "Cube")
        let gravel = library.makeBike(name: "Grizl", kind: .gravel)
        let nugget = library.makeBike(name: "Nugget", kind: .car)
        let shoes = library.makeBike(name: "Pegasus", kind: .runningShoe)
        let long = ride("Lang", on: gravel, km: 82.5, minutes: 240, maxKmh: 48, day: 0)
        ride("Kurz", on: cube, km: 12, minutes: 35, maxKmh: 31, day: 1)
        ride("Ohne Gerät", on: nil, km: 5.5, minutes: 20, maxKmh: nil, day: 2)
        let autobahn = ride("Autobahn", on: nugget, km: 210, minutes: 120, maxKmh: 160, day: 3)
        ride("Leihwagen", on: nil, kind: .car, km: 30, minutes: 30, maxKmh: 120, day: 4)
        ride("Lauf", on: shoes, km: 10, minutes: 55, maxKmh: 14, day: 5)
        try context.save()

        let totals = try database.snapshot(generator: "test").sportTotals()
        #expect(totals.map(\.sport) == [.cycling, .vehicle, .running])
        let cycling = try #require(totals.first)
        #expect(cycling.rides == 3)
        #expect(abs(cycling.distance - 100_000) < 0.1)
        #expect(cycling.rideTime == 295 * 60)
        #expect(cycling.longest == SportTotals.Best(rideID: long.id, value: 82_500))
        #expect(abs((cycling.fastest?.value ?? 0) - 48 / 3.6) < 0.001)
        let vehicles = totals[1]
        #expect(vehicles.rides == 2 && abs(vehicles.distance - 240_000) < 0.1)
        #expect(vehicles.longest?.rideID == autobahn.id && abs((vehicles.fastest?.value ?? 0) - 160 / 3.6) < 0.001)
        #expect(totals[2].rides == 1 && totals[2].fastest != nil)
    }

    @Test("Without rides the profile still shows cycling, with zeros")
    func empty() throws {
        let totals = try database.snapshot(generator: "test").sportTotals()
        #expect(totals == [SportTotals(sport: .cycling, rides: [])])
        #expect(totals[0].distance == 0 && totals[0].longest == nil && totals[0].fastest == nil)
    }

    @Test("Trashed rides and rides without a distance do not count")
    func onlyListed() throws {
        let cube = library.makeBike(name: "Cube")
        ride("Gelöscht", on: cube, km: 500, minutes: 600, maxKmh: 90, day: 0).deletedAt = .now
        ride("Null", on: cube, km: 0, minutes: 1, maxKmh: 0, day: 1)
        try context.save()
        let cycling = try #require(try database.snapshot(generator: "test").sportTotals().first)
        #expect(cycling.rides == 1 && cycling.distance == 0)
        #expect(cycling.longest == nil && cycling.fastest == nil)
    }

    @Test("The devices are grouped by sport, archived ones last, each with its rides")
    func devices() throws {
        let zebra = library.makeBike(name: "Zebra")
        let alt = library.makeBike(name: "Altrad")
        alt.isArchived = true
        let nugget = library.makeBike(name: "Nugget", kind: .car)
        library.makeBike(name: "Honda", kind: .motorcycle)
        ride("Fahrt", on: zebra, km: 10, minutes: 30, maxKmh: 25, day: 0)
        ride("Fahrt 2", on: zebra, km: 15, minutes: 40, maxKmh: 25, day: 1)
        try context.save()

        let state = try database.snapshot(generator: "test")
        let groups = state.devicesBySport()
        #expect(groups.map(\.sport) == [.cycling, .vehicle])
        // "Mein eBike" is the bike the iPhone makes for a new library.
        #expect(groups[0].devices.map(\.name) == ["Mein eBike", "Zebra", "Altrad"])
        #expect(groups[1].devices.map(\.name) == ["Honda", "Nugget"])
        let usage = state.usage(of: zebra.id)
        #expect(usage.rides == 2 && abs(usage.distance - 25_000) < 0.1)
        #expect(state.usage(of: nugget.id).rides == 0)
    }

    @Test("The rider edited on the iPhone is the one the Mac edits; out-of-range numbers are not stored")
    func editRider() throws {
        // The iPhone makes a rider with the library; editing changes that one.
        let photo = Data([0xFF, 0xD8, 0xFF])
        database.updateRider(RiderDetails(name: "  Alex  ", photoData: photo,
                                          body: BodyProfile(weightKg: 78.5, heightCm: 181, birthYear: 1975, sex: .female)))
        let saved = try #require(database.riderDetails())
        #expect(saved.name == "Alex" && saved.photoData == photo)
        #expect(saved.body == BodyProfile(weightKg: 78.5, heightCm: 181, birthYear: 1975, sex: .female))
        #expect(try context.fetchCount(FetchDescriptor<Rider>()) == 1)
        // The Mac's rider is the same object; a second edit changes it, nothing new is made.
        #expect(library.defaultRider().name == "Alex")

        database.updateRider(RiderDetails(name: "Alex", photoData: nil,
                                          body: BodyProfile(weightKg: 7, heightCm: 500, birthYear: 1850, sex: .unspecified)))
        let changed = try #require(database.riderDetails())
        #expect(changed.photoData == nil)
        #expect(changed.body == BodyProfile(weightKg: nil, heightCm: nil, birthYear: nil, sex: .unspecified))
        #expect(try context.fetchCount(FetchDescriptor<Rider>()) == 1)
    }

    @Test("With two riders before the sync merged them, the oldest is edited")
    func oldestRider() throws {
        let older = Rider(name: "Alt")
        older.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Rider(name: "Neu")
        newer.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(newer)
        context.insert(older)
        try context.save()
        database.updateRider(RiderDetails(name: "Geändert"))
        #expect(older.name == "Geändert" && newer.name == "Neu")
    }
}
