import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Rides on a motorcycle: shown, but not in the totals, records and the CO₂ saved.
@MainActor
@Suite("Motorcycle rides")
struct MotorcycleTests {
    let container: ModelContainer
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    private func ride(on bike: Bike, km: Double) -> Ride {
        let ride = Ride(name: "Tour", startDate: Date(timeIntervalSince1970: 1_800_000_000))
        ride.distance = km * 1000
        ride.timerTime = 3600
        context.insert(ride)
        ride.bike = bike
        return ride
    }

    @Test("A motorcycle ride counts only where the filter shows that bike")
    func counting() {
        let ebike = library.makeBike(name: "Cube")
        let moto = library.makeBike(name: "Honda", kind: .motorcycle)
        let onEbike = ride(on: ebike, km: 20)
        let onMoto = ride(on: moto, km: 100)
        #expect(onEbike.countsInTotals && onMoto.countsInStatistics && !onMoto.countsInTotals)
        #expect(!onMoto.countsInTotals(bikeFilter: .all))
        #expect(onMoto.countsInTotals(bikeFilter: .bike(moto.id)))
        #expect(!onEbike.countsInTotals(bikeFilter: .bike(moto.id)))
        #expect(onEbike.countsInTotals(bikeFilter: .all))
    }

    @Test("A motorcycle saves no CO₂, in the sums and in the comparison")
    func co2() {
        let ebike = library.makeBike(name: "Cube")
        let moto = library.makeBike(name: "Honda", kind: .motorcycle)
        let figures = [ride(on: ebike, km: 10).figures, ride(on: moto, km: 100).figures]
        let aggregate = RideAggregate(figures, co2PerKilometre: 0.1)
        #expect(abs(aggregate.co2SavedKilograms - 1) < 0.001)
        #expect(aggregate.distance == 110_000)
        #expect(ComparisonMetric.co2Saved.value(of: ride(on: moto, km: 5).comparisonFigures) == nil)
        #expect(ComparisonMetric.co2Saved.value(of: ride(on: ebike, km: 5).comparisonFigures) != nil)
    }

    @Test("The iPhone's week and month leave motorcycle rides out")
    func phoneTotals() {
        let ebike = RideExchange.Bike(id: UUID(), name: "Cube", kind: "bike", color: "blue", isEbike: true, isArchived: false)
        let moto = RideExchange.Bike(id: UUID(), name: "Honda", kind: "motorcycle", color: "pink", isEbike: false, isArchived: false)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func ride(_ bike: RideExchange.Bike?, km: Double) -> RideExchange.Ride {
            RideExchange.Ride(id: UUID(), name: "Tour", startDate: now.addingTimeInterval(-3600), bikeID: bike?.id, source: "gpx",
                              timerTime: 3600, elapsedTime: 3600, distance: km * 1000)
        }
        let library = RideExchange.Library(generatedAt: now, generator: "test", bikes: [ebike, moto],
                                           rides: [ride(ebike, km: 20), ride(moto, km: 100), ride(nil, km: 5)])
        #expect(library.countedRides.count == 2)
        #expect(library.totals(now: now).weekDistance == 25_000)
        #expect(library.isMotorized(bikeID: moto.id) && !library.isMotorized(bikeID: ebike.id) && !library.isMotorized(bikeID: nil))
    }
}
