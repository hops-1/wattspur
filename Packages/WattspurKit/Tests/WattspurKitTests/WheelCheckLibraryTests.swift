import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

/// B-237: the hint on the wheel circumference from the Bosch rides of a bike.
@MainActor
@Suite("Wheel check of a bike")
struct WheelCheckLibraryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let tour: ParsedRide

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        tour = try FITRideImporter().parse(GPXFixture.fitData("pair-tour1-bosch-flow"))
    }

    @discardableResult
    private func ride(_ bike: Bike, day: Int, format: String = "fit") -> Ride {
        let ride = Ride(name: "Tour \(day)", startDate: Date(timeIntervalSince1970: Double(day) * 86_400))
        ride.sourceFormat = format
        ride.setSamples(tour.samples)
        ride.bike = bike
        context.insert(ride)
        return ride
    }

    @Test("Three Bosch rides of the tour show the difference of about 7 %")
    func hint() throws {
        let bike = Bike()
        context.insert(bike)
        for day in 1...3 { ride(bike, day: day) }
        let hint = try #require(bike.wheelCheckHint())
        #expect((0.05...0.09).contains(hint))
    }

    @Test("GPX rides, the trash and samples do not count")
    func onlyBoschRides() {
        let bike = Bike()
        context.insert(bike)
        ride(bike, day: 1)
        ride(bike, day: 2, format: "gpx")
        ride(bike, day: 3).deletedAt = .now
        ride(bike, day: 4).isSample = true
        #expect(bike.wheelCheckHint() == nil)
        ride(bike, day: 5)
        ride(bike, day: 6)
        #expect(bike.wheelCheckHint() != nil)
    }
}
