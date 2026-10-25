import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// Reference test B-005: the summary must match the FIT `session` exactly (NFR-04),
/// which is what the Bosch Flow app shows for this ride.
@Suite("FIT ride importer – sample ride „Reinheim Rundfahrt“")
struct FITRideImporterTests {
    let ride: ParsedRide

    init() throws {
        ride = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
    }

    @Test("Summary equals the Bosch session values")
    func summary() {
        let s = ride.summary
        #expect(s.timerTime == 2916)          // 00:48:36
        #expect(s.elapsedTime == 3364)        // 00:56:04
        #expect(s.distance == 19_543)         // 19.5 km
        #expect(s.averageSpeed == 6.703)      // 24.1 km/h
        #expect(s.maxSpeed == 15.142)         // 54.5 km/h
        #expect(s.averagePower == 135)
        #expect(s.maxPower == 460)
        #expect(s.averageCadence == 60)
        #expect(s.maxCadence == 82)
        #expect(s.totalAscent == 166)
        #expect(s.totalDescent == 169)
    }

    @Test("Start time is 2026-09-20 12:12:13 UTC (anonymized: four weeks earlier)")
    func startDate() {
        #expect(ride.startDate == Date(timeIntervalSince1970: 1_789_906_333))
    }

    @Test("Cleared serial number reads as nil, parser version is kept")
    func metadata() {
        #expect(ride.deviceSerialNumber == nil)
        #expect(ride.parserVersion == FITRideImporter.parserVersion)
    }

    @Test("Position and sensor streams are merged into one sample per second")
    func mergedSamples() {
        let times = ride.samples.map(\.time)
        #expect(times == times.sorted())
        #expect(Set(times).count == times.count)
        #expect(ride.samples.count > 2900 && ride.samples.count < 3400)

        // The anonymized fixture has no positions on the first and last 500 m (V-05).
        let withBoth = ride.samples.filter { $0.latitude != nil && $0.power != nil }
        #expect(withBoth.count > 2600)

        let firstIndex = ride.samples.firstIndex { $0.latitude != nil }
        let distanceAtFirst = firstIndex.flatMap { ride.samples[...$0].lazy.compactMap(\.distance).last }
        #expect(distanceAtFirst.map { $0 >= 480 && $0 < 600 } == true)
    }

    @Test("Distance increases monotonically to the session distance")
    func distance() {
        let distances = ride.samples.compactMap(\.distance)
        #expect(distances == distances.sorted())
        #expect(distances.last == 19_543)
    }

    @Test("Cadence is held for display but only measured values are flagged")
    func cadenceHold() {
        let measured = ride.samples.filter(\.cadenceMeasured)
        let shown = ride.samples.filter { $0.cadence != nil }
        #expect(measured.count > 900 && measured.count < 1100)
        #expect(shown.count > 2 * measured.count)
        #expect(measured.compactMap(\.cadence).max() == 82)
    }

    @Test("Derived metrics match the values shown in the Flow app")
    func metrics() {
        let metrics = RideMetrics(ride: ride)
        #expect(metrics.pausedTime == 448)
        #expect(abs(metrics.workKilojoules - 319.7) < 0.5)
        #expect(metrics.minAltitude.map { abs($0 - 151.4) < 1 } == true)
        #expect(metrics.maxAltitude.map { abs($0 - 263) < 1 } == true)

        let kcal = CalorieModel.fromWork.kilocalories(workKilojoules: metrics.workKilojoules, rideTime: ride.summary.timerTime, on: ride.startDate)
        #expect(abs(kcal - 360) < 4)                      // 360 kcal in the Flow app (V-01)
        #expect(abs(metrics.co2SavedKilograms() - 3.1) < 0.05)
    }
}
