import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Sports as the base (B-284): cars and motorcycles are vehicles, running shoes are running. Only
/// cycling counts towards the cycling totals, records and the CO₂ saved, also for a ride without
/// a device. All rides here are made up.
@MainActor
@Suite("Sports")
struct SportTests {
    let container: ModelContainer
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    private func ride(on bike: Bike?, kind: BikeKind? = nil, km: Double, hour: Double = 0) -> Ride {
        let ride = Ride(name: "Tour", startDate: Date(timeIntervalSince1970: 1_800_000_000 + hour * 3600))
        ride.distance = km * 1000
        ride.timerTime = 1800
        ride.elapsedTime = 1800
        context.insert(ride)
        ride.bike = bike
        ride.sportRawValue = kind?.rawValue
        return ride
    }

    @Test("Each kind has its sport; the stored raw values stay as they are")
    func kinds() {
        #expect(BikeKind.allCases.filter { $0.sport == .cycling } == [.bike, .mountain, .road, .gravel, .cargo])
        #expect(BikeKind.car.sport == .vehicle && BikeKind.motorcycle.sport == .vehicle)
        #expect(BikeKind.runningShoe.sport == .running)
        #expect(BikeKind.car.isMotorized && !BikeKind.runningShoe.isMotorized && !BikeKind.cargo.isMotorized)
        #expect(BikeKind.car.rawValue == "car" && BikeKind.runningShoe.rawValue == "runningShoe")
        #expect(BikeKind.motorcycle.rawValue == "motorcycle")
        #expect(!BikeKind.selectable.contains(.runningShoe) && BikeKind.selectable.contains(.car))
    }

    @Test("The device's kind wins, then the ride's, then a bicycle; unknown values are a bicycle")
    func kindOfARide() {
        #expect(BikeKind.of(device: "car", ride: nil) == .car)
        #expect(BikeKind.of(device: "gravel", ride: "car") == .gravel)
        #expect(BikeKind.of(device: nil, ride: "motorcycle") == .motorcycle)
        #expect(BikeKind.of(device: nil, ride: nil) == .bike)
        #expect(BikeKind.of(device: "hovercraft", ride: "car") == .car)
        #expect(BikeKind.of(device: nil, ride: "hovercraft") == .bike)
    }

    @Test("Cars, motorcycles and running stay out of the cycling totals, also without a device")
    func totals() {
        let ebike = library.makeBike(name: "Cube")
        let car = library.makeBike(name: "Nugget", kind: .car)
        let onEbike = ride(on: ebike, km: 20)
        let inCar = ride(on: car, km: 100)
        let carWithoutDevice = ride(on: nil, kind: .car, km: 50)
        let motoWithoutDevice = ride(on: nil, kind: .motorcycle, km: 50)
        let withoutAnything = ride(on: nil, km: 5)
        #expect(onEbike.sport == .cycling && inCar.sport == .vehicle)
        #expect(carWithoutDevice.deviceKind == .car && motoWithoutDevice.isMotorized)
        #expect(onEbike.countsInTotals && withoutAnything.countsInTotals)
        #expect(!inCar.countsInTotals && !carWithoutDevice.countsInTotals && !motoWithoutDevice.countsInTotals)
        #expect(inCar.countsInStatistics && carWithoutDevice.countsInStatistics)
        // The filter on the car shows its own figures.
        #expect(inCar.countsInTotals(bikeFilter: .bike(car.id)) && !inCar.countsInTotals(bikeFilter: .all))
        #expect(!carWithoutDevice.countsInTotals(bikeFilter: .all))
    }

    @Test("Only cycling saves CO₂, in the sums and in the comparison")
    func co2() {
        let ebike = library.makeBike(name: "Cube")
        let car = library.makeBike(name: "Nugget", kind: .car)
        let shoes = library.makeBike(name: "Pegasus", kind: .runningShoe)
        let figures = [ride(on: ebike, km: 10).figures, ride(on: car, km: 100).figures,
                       ride(on: shoes, km: 10).figures, ride(on: nil, kind: .car, km: 30).figures]
        let aggregate = RideAggregate(figures, co2PerKilometre: 0.1)
        #expect(abs(aggregate.co2SavedKilograms - 1) < 0.001)
        #expect(ComparisonMetric.co2Saved.value(of: ride(on: car, km: 5).comparisonFigures) == nil)
        #expect(ComparisonMetric.co2Saved.value(of: ride(on: nil, kind: .car, km: 5).comparisonFigures) == nil)
        #expect(ComparisonMetric.co2Saved.value(of: ride(on: shoes, km: 5).comparisonFigures) == nil)
        #expect(ComparisonMetric.co2Saved.value(of: ride(on: ebike, km: 5).comparisonFigures) != nil)
    }

    @Test("The iPhone gets the kind of a ride without a device and counts only cycling")
    func exchange() throws {
        let ebike = library.makeBike(name: "Cube")
        let inCar = ride(on: nil, kind: .car, km: 40)
        let onEbike = ride(on: ebike, km: 20)
        let car = library.makeBike(name: "Nugget", kind: .car)
        let inOwnCar = ride(on: car, kind: .motorcycle, km: 60)
        let carRide = inCar.exchangeRide(routeFile: nil)
        #expect(carRide.kind == "car" && carRide.bikeID == nil)
        #expect(onEbike.exchangeRide(routeFile: nil).kind == nil)
        // With a device, the device's kind is the one that counts; the ride's own is not passed on.
        #expect(inOwnCar.exchangeRide(routeFile: nil).kind == nil)
        let bikes = [ebike, car].map { RideExchange.Bike(id: $0.id, name: $0.name, kind: $0.kindRawValue, color: $0.colorRawValue,
                                                          isEbike: $0.isEbike, isArchived: false) }
        let state = RideExchange.Library(generatedAt: .now, generator: "test", bikes: bikes,
                                         rides: [carRide, onEbike.exchangeRide(routeFile: nil), inOwnCar.exchangeRide(routeFile: nil)])
        #expect(state.countedRides.map(\.id) == [onEbike.id])
        #expect(state.kind(of: carRide) == .car)
    }

    @Test("A state written before the field reads as before")
    func oldState() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Alt","startDate":"2026-11-01T10:00:00Z","source":"gpx","estimated":false,
         "timerTime":60,"elapsedTime":60,"distance":1000}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let ride = try decoder.decode(RideExchange.Ride.self, from: Data(json.utf8))
        #expect(ride.kind == nil)
    }

    @Test("Merging keeps a car ride without a device as one")
    func merge() throws {
        let first = ride(on: nil, kind: .car, km: 10, hour: 0)
        let second = ride(on: nil, kind: .car, km: 10, hour: 1)
        try context.save()
        let merged = try library.merge([first, second], name: "Beide")
        #expect(merged.bike == nil && merged.deviceKind == .car && !merged.countsInTotals)
    }
}
