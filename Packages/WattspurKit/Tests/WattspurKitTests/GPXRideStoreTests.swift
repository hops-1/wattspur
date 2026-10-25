import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

/// B-141: GPX rides in the store – source, "estimated" flag, original points, heart rate and temperature.
@MainActor
@Suite("GPX rides in the library")
struct GPXRideStoreTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
    }

    private func importRide(_ fixture: String, as fileName: String? = nil) throws -> Ride {
        let result = library.importFile(data: try GPXFixture.data(fixture), fileName: fileName ?? fixture + ".gpx")
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Expected import, got \(result.outcome)")
            throw CancellationError()
        }
        return ride
    }

    @Test("A GPX ride is stored with source gpx, the estimated flag, the track name and its original file")
    func storesGPXRide() throws {
        let ride = try importRide("strava-style-power-hr-cad")
        #expect(ride.sourceFormat == "gpx")
        #expect(ride.source == .gpx)
        #expect(ride.summaryEstimatedFromGPS)
        #expect(ride.name == "Morgenrunde & Café")
        #expect(ride.parserVersion == GPXRideImporter.parserVersion)
        #expect(ride.sourceFile?.fileName == "strava-style-power-hr-cad.gpx")
        #expect(ride.sourceFile?.data == (try GPXFixture.data("strava-style-power-hr-cad")))
        #expect(ride.timerTime == 59)
        #expect(abs(ride.distance - 324.5) < 1)
        #expect(ride.workKilojoules > 7 && ride.workKilojoules < 9)
        #expect(ride.bike != nil)
        #expect(ride.deviceSerialNumber == nil)
    }

    @Test("Heart rate, temperature and power come back from the stored time series")
    func storesHeartRateAndTemperature() throws {
        let ride = try importRide("garmin-tpx-v1-hr-cad-temp")
        let samples = ride.samples
        #expect(samples.count == 60)
        #expect(samples[0].heartRate == 110)
        #expect(samples[0].temperature == 21.0)
        #expect(samples[0].cadence == 80)
        #expect(samples.allSatisfy { $0.power == nil })
    }

    @Test("The original points are kept, not resampled to one per second")
    func keepsOriginalPoints() throws {
        var points = ""
        let times: [Double] = [0, 2.5, 7, 7.5, 12, 20, 21]
        for (i, t) in times.enumerated() {
            let when = GPXWriter.timestamp(Date(timeIntervalSince1970: 1_780_732_800 + t.rounded(.down)))
            let fraction = t == t.rounded(.down) ? "" : ".5"
            points += "<trkpt lat=\"\(50 + 0.0001 * Double(i))\" lon=\"9\"><time>\(when.dropLast())\(fraction)Z</time></trkpt>"
        }
        let gpx = "<gpx version=\"1.1\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg>\(points)</trkseg></trk></gpx>"
        let result = library.importFile(data: Data(gpx.utf8), fileName: "irregular.gpx")
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Expected import")
            return
        }
        #expect(ride.samples.map(\.time) == times)
        #expect(ride.name == "irregular")
    }

    @Test("Re-importing the same GPX file is a duplicate")
    func duplicate() throws {
        _ = try importRide("strava-style-power-hr-cad")
        let again = library.importFile(data: try GPXFixture.data("strava-style-power-hr-cad"), fileName: "Kopie.gpx")
        guard case .duplicate = again.outcome else {
            Issue.record("Expected duplicate, got \(again.outcome)")
            return
        }
    }

    @Test("An older GPX parser version is re-parsed from the original file, keeping the name")
    func reparse() throws {
        let ride = try importRide("garmin-tpx-v1-hr-cad-temp")
        library.rename(ride, to: "Meine Runde")
        ride.parserVersion = 0
        ride.samplesData = nil
        #expect(library.reparseOutdatedRides() == 1)
        #expect(ride.parserVersion == GPXRideImporter.parserVersion)
        #expect(ride.samples.count == 60)
        #expect(ride.name == "Meine Runde")
        #expect(ride.summaryEstimatedFromGPS)
    }

    @Test("Updating a GPX ride from a Bosch FIT takes the Bosch values and clears the estimate")
    func fitReplacesEstimate() throws {
        let ride = try importRide("pair-tour1-bosch-flow", as: "pair-tour1.gpx")
        library.rename(ride, to: "Meine Tour")
        #expect(ride.summaryEstimatedFromGPS)
        let fit = try GPXFixture.fitData("pair-tour1-bosch-flow")
        try library.update(ride, with: fit, fileName: "Beispielrunde-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        #expect(ride.summaryEstimatedFromGPS == false)
        #expect(ride.timerTime == 2916)
        #expect(ride.distance > 19_000)
        #expect(ride.name == "Meine Tour")
    }

    @Test("Rides from FIT stay unmarked, and their samples carry no heart rate or temperature")
    func fitStaysUnmarked() throws {
        let fit = try Fixture.data("reinheim-rundfahrt")
        library.importFile(data: fit, fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        let ride = try #require(try container.mainContext.fetch(FetchDescriptor<Ride>()).first)
        #expect(ride.summaryEstimatedFromGPS == false)
        #expect(ride.source == .fit)
        #expect(ride.samples.allSatisfy { $0.heartRate == nil && $0.temperature == nil })
    }

    @Test("Samples without heart rate and temperature encode as before")
    func encodingUnchanged() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode([RideSample(time: 1, speed: 2, power: 3)])
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("heartRate"))
        #expect(!text.contains("temperature"))
        let withValues = try encoder.encode([RideSample(time: 1, heartRate: 120, temperature: 18.5)])
        let decoded = try PropertyListDecoder().decode([RideSample].self, from: withValues)
        #expect(decoded[0].heartRate == 120)
        #expect(decoded[0].temperature == 18.5)
    }

    @Test("The diagnostic report names the GPX parser version and counts GPX rides apart")
    func diagnostics() {
        let report = DiagnosticReport(appVersion: "1.6.0", build: "1", commit: "abc", parserVersion: 2, gpxParserVersion: 1,
                                      osVersion: "x", locale: "de_DE", rideCount: 5, trashedRideCount: 0,
                                      ridesByParserVersion: [2: 3], gpxRidesByParserVersion: [1: 2], importLog: [])
        #expect(report.text.contains("GPX parser version: 1"))
        #expect(report.text.contains("Rides by parser version: v2: 3"))
        #expect(report.text.contains("GPX rides by parser version: v1: 2"))
    }
}
