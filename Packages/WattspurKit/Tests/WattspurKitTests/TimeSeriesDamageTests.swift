import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// A time series that cannot be read (B-268, R-32): it is counted for the diagnostic report, and
/// the maintenance does not reckon stored values anew from an empty list.
@MainActor
@Suite("Damaged time series", .serialized)
struct TimeSeriesDamageTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        TimeSeriesDamage.reset()
    }

    /// A ride with stored values from an earlier version and a time series that is garbage.
    private func damagedRide() -> Ride {
        let ride = Ride(name: "Kaputt", startDate: Date(timeIntervalSince1970: 1_800_000_000))
        ride.samplesData = Data("not a property list".utf8)
        ride.bestPower1Min = 250
        ride.peakPowerVersion = 0
        ride.curvaturePerKm = 12
        ride.steepestClimb = 9
        ride.trackFiguresVersion = 0
        ride.overviewRouteData = Data([1, 2, 3])
        ride.overviewRouteVersion = 0
        container.mainContext.insert(ride)
        return ride
    }

    @Test("An unreadable time series is told apart from none, and noted once")
    func detects() {
        let ride = damagedRide()
        #expect(ride.readableSamples == nil)
        #expect(ride.hasDamagedSamples)
        #expect(ride.samples.isEmpty)
        _ = ride.samples
        #expect(TimeSeriesDamage.count == 1)
        #expect(TimeSeriesDamage.contains(ride.id))

        let empty = Ride(name: "Ohne GPS", startDate: .now)
        container.mainContext.insert(empty)
        #expect(empty.readableSamples == [])
        #expect(!empty.hasDamagedSamples)
        #expect(TimeSeriesDamage.count == 1)
    }

    @Test("The maintenance keeps the stored values of a damaged ride")
    func keepsValues() async {
        let ride = damagedRide()
        await library.prepareOverviewRoutes()
        await library.preparePeakPower()
        await library.prepareTrackFigures()
        #expect(ride.bestPower1Min == 250)
        #expect(ride.curvaturePerKm == 12)
        #expect(ride.steepestClimb == 9)
        #expect(ride.overviewRouteData == Data([1, 2, 3]))
        #expect(TimeSeriesDamage.contains(ride.id))
    }

    @Test("The diagnostic report names how many rides have an unreadable time series")
    func report() {
        let report = DiagnosticReport(appVersion: "1.8.11", build: "1", commit: "abc", rideCount: 3, trashedRideCount: 0,
                                      ridesByParserVersion: [:], importLog: [], damagedTimeSeries: 2)
        #expect(report.text.contains("Rides with an unreadable time series (met since launch): 2"))
    }
}
