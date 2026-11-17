import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// The sport switch (B-288, B-289): which sports there are, which one is shown, and what counts
/// in its totals. All rides here are made up.
@MainActor
@Suite("Sport choice")
struct SportChoiceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func bike(_ name: String, _ kind: BikeKind, archived: Bool = false) -> Bike {
        let bike = Bike(name: name)
        bike.kind = kind
        bike.isArchived = archived
        context.insert(bike)
        return bike
    }

    private func ride(on bike: Bike?, kind: BikeKind? = nil) -> Ride {
        let ride = Ride(name: "Tour", startDate: Date(timeIntervalSince1970: 1_800_000_000))
        ride.distance = 10_000
        context.insert(ride)
        ride.bike = bike
        ride.sportRawValue = kind?.rawValue
        return ride
    }

    @Test("Only cycling: no switch; a new library is cycling too")
    func onlyCycling() {
        #expect(SportChoice.available(deviceKinds: [String](), rideSports: [Sport]()) == [.cycling])
        let sports = SportChoice.available(deviceKinds: ["bike", "gravel"], rideSports: [.cycling])
        #expect(sports == [.cycling])
        #expect(!SportChoice.showsSwitch(available: sports))
    }

    @Test("A device or a ride of a second sport brings the switch, in a fixed order")
    func secondSport() {
        #expect(SportChoice.available(deviceKinds: ["car", "bike"], rideSports: [Sport]()) == [.cycling, .vehicle])
        #expect(SportChoice.available(deviceKinds: ["bike"], rideSports: [.vehicle]) == [.cycling, .vehicle])
        #expect(SportChoice.available(deviceKinds: ["runningShoe", "motorcycle"], rideSports: [.cycling]) == [.cycling, .vehicle, .running])
        #expect(SportChoice.showsSwitch(available: [.cycling, .vehicle]))
        // Unknown raw values from newer versions count as a bicycle.
        #expect(SportChoice.available(deviceKinds: ["hovercraft"], rideSports: [Sport]()) == [.cycling])
    }

    @Test("The stored sport wins while it is there, else the first sport there is")
    func resolved() {
        #expect(SportChoice.resolved(.vehicle, available: [.cycling, .vehicle]) == .vehicle)
        #expect(SportChoice.resolved(.running, available: [.cycling, .vehicle]) == .cycling)
        #expect(SportChoice.resolved(nil, available: [.cycling, .vehicle]) == .cycling)
        // Only car rides: the car is shown, not an empty cycling area.
        #expect(SportChoice.resolved(.cycling, available: [.vehicle]) == .vehicle)
    }

    @Test("Archived devices and rides in the trash or the sample bring no sport")
    func libraryAvailable() {
        let nadja = bike("Nadja", .bike)
        let old = bike("Old car", .car, archived: true)
        _ = ride(on: nadja)
        let trashed = ride(on: nil, kind: .motorcycle)
        trashed.deletedAt = .now
        #expect(SportChoice.available(bikes: [nadja, old], rides: [trashed]) == [.cycling])
        let car = ride(on: old)
        #expect(SportChoice.available(bikes: [nadja, old], rides: [car]) == [.cycling, .vehicle])
        let hired = ride(on: nil, kind: .car)
        #expect(SportChoice.available(bikes: [nadja], rides: [hired]) == [.cycling, .vehicle])
    }

    @Test("Each sport counts only its own rides, also without a device")
    func totals() {
        let nadja = bike("Nadja", .bike)
        let nugget = bike("Nugget", .car)
        let onBike = ride(on: nadja)
        let inCar = ride(on: nugget)
        let rentalCar = ride(on: nil, kind: .car)
        let hiredBike = ride(on: nil, kind: .bike)
        #expect(onBike.countsInTotals(sport: .cycling) && hiredBike.countsInTotals(sport: .cycling))
        #expect(!inCar.countsInTotals(sport: .cycling) && !rentalCar.countsInTotals(sport: .cycling))
        #expect(inCar.countsInTotals(sport: .vehicle) && rentalCar.countsInTotals(sport: .vehicle))
        #expect(!onBike.countsInTotals(sport: .vehicle))
        #expect(inCar.countsInTotals(sport: .vehicle, bikeFilter: .bike(nugget.id)))
        #expect(!rentalCar.countsInTotals(sport: .vehicle, bikeFilter: .bike(nugget.id)))
        onBike.deletedAt = .now
        #expect(!onBike.countsInTotals(sport: .cycling))
    }

    @Test("The device filter keeps only devices of the shown sport")
    func filterWithinSport() {
        let nadja = bike("Nadja", .bike)
        let cube = bike("Cube", .mountain)
        let nugget = bike("Nugget", .car)
        let bikes = [nadja, cube, nugget]
        #expect(BikeFilter.bike(nadja.id).resolved(sport: .cycling, bikes: bikes) == .bike(nadja.id))
        // A car chosen while cycling is shown: all bikes.
        #expect(BikeFilter.bike(nugget.id).resolved(sport: .cycling, bikes: bikes) == .all)
        // Only one vehicle: nothing to filter.
        #expect(BikeFilter.bike(nugget.id).resolved(sport: .vehicle, bikes: bikes) == .all)
        let bulli = bike("Bulli", .car, archived: true)
        #expect(BikeFilter.bike(bulli.id).resolved(sport: .vehicle, bikes: bikes + [bulli]) == .bike(bulli.id))
    }

    @Test("The map shows only the sport; rides picked by hand stay")
    func map() {
        let nugget = bike("Nugget", .car)
        let onBike = ride(on: nil)
        let inCar = ride(on: nugget)
        #expect(onBike.isOnMap(MapFilter(sport: .cycling)) && !inCar.isOnMap(MapFilter(sport: .cycling)))
        #expect(inCar.isOnMap(MapFilter(sport: .vehicle)) && !onBike.isOnMap(MapFilter(sport: .vehicle)))
        #expect(onBike.isOnMap(MapFilter()) && inCar.isOnMap(MapFilter()))
        #expect(inCar.isOnMap(MapFilter(selectedIDs: [inCar.id], sport: .cycling)))
    }
}
