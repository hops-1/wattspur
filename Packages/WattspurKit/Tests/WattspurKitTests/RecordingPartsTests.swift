import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Several Bosch rides inside one iPhone recording (B-274): Bosch Flow cut a tour with long pauses
/// into rides, the iPhone recorded it as one.
@MainActor
@Suite("Bosch parts of an iPhone recording")
struct RecordingPartsTests {
    let container: ModelContainer
    let library: RideLibrary
    let start = Date(timeIntervalSince1970: 1_794_060_000)

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    /// A recording north at 6 m/s: riding `legs` (start and length in seconds), pausing in between,
    /// with a lean angle of 12° at every point.
    private func recording(legs: [(start: Int, seconds: Int)]) -> Data {
        var recording = RideRecording(startDate: start)
        var metres = 0.0
        for (index, leg) in legs.enumerated() {
            if index > 0 { recording.pause(); recording.resume() }
            for second in leg.start...(leg.start + leg.seconds) {
                recording.add(RideRecording.Fix(date: start.addingTimeInterval(Double(second)),
                                                latitude: 49.8 + metres / 111_195, longitude: 8.8, altitude: 150,
                                                horizontalAccuracy: 5, speed: 6,
                                                motion: MotionValues(lean: 12, acceleration: 0, roughness: 0.1)))
                metres += 6
            }
            metres -= 6
        }
        return GPXWriter.document(name: "Harzrunde", segments: recording.gpxSegments, creator: GPXWriter.iPhoneCreator)
    }

    /// A Bosch ride as the FIT import makes it, from `from` for `seconds`, 5 % longer than the GPS.
    @discardableResult
    private func boschRide(from offset: Int, seconds: Int, name: String) -> Ride {
        let ride = Ride(name: name, startDate: start.addingTimeInterval(Double(offset)))
        ride.sourceFormat = RideSource.fit.rawValue
        ride.elapsedTime = Double(seconds)
        ride.timerTime = Double(seconds)
        ride.distance = Double(seconds) * 6 * 1.05
        ride.averagePower = 150
        ride.setSamples((0...seconds).map { RideSample(time: Double($0), latitude: 49.8, longitude: 8.8, power: 150) })
        container.mainContext.insert(ride)
        return ride
    }

    private var legs: [(start: Int, seconds: Int)] { [(0, 600), (1500, 600), (3000, 600)] }

    private var parts: RecordingPartsService {
        RecordingPartsService(LibraryEnvironment(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()],
                                                 undoManager: nil, defaultBikeName: "Mein eBike"))
    }

    private func id(_ result: ImportResult) -> UUID? {
        if case .imported(let id) = result.outcome { return id }
        return nil
    }

    @Test("The Bosch parts become one ride with the recording's name and lean angle; the recording goes to the trash")
    func joins() throws {
        let recorded = library.importFile(data: recording(legs: legs), fileName: "Harzrunde.gpx")
        let recordingID = try #require(id(recorded))
        boschRide(from: 10, seconds: 590, name: "Tour 1")
        boschRide(from: 1510, seconds: 590, name: "Tour 2")
        let last = boschRide(from: 3010, seconds: 590, name: "Tour 3")

        let merged = try #require(parts.joinParts(around: last))
        #expect(merged.name == "Harzrunde")
        #expect(merged.isMerged)
        #expect(merged.sortedParts.count == 3)
        #expect(merged.samples.contains { $0.lean == 12 })
        #expect(merged.sortedParts.allSatisfy { $0.attachedSourceName == "Harzrunde.gpx" })
        #expect(library.ride(withID: recordingID)?.deletedAt != nil)
    }

    @Test("Parts that do not add up to the recording stay apart")
    func missingPart() throws {
        _ = library.importFile(data: recording(legs: legs), fileName: "Harzrunde.gpx")
        boschRide(from: 10, seconds: 590, name: "Tour 1")
        let second = boschRide(from: 1510, seconds: 590, name: "Tour 2")
        #expect(parts.joinParts(around: second) == nil)
        #expect(!second.isMerged && second.mergedInto == nil)
    }

    @Test("A Bosch ride outside the recording's time is no part of it")
    func outside() throws {
        _ = library.importFile(data: recording(legs: [(0, 600)]), fileName: "Kurz.gpx")
        let ride = boschRide(from: 4000, seconds: 600, name: "Später")
        #expect(parts.joinParts(around: ride) == nil)
    }

    @Test("When the recording comes last, its import joins the parts already there")
    func recordingLast() throws {
        boschRide(from: 10, seconds: 590, name: "Tour 1")
        boschRide(from: 1510, seconds: 590, name: "Tour 2")
        boschRide(from: 3010, seconds: 590, name: "Tour 3")
        let result = library.importFile(data: recording(legs: legs), fileName: "Harzrunde.gpx")
        let rideID = try #require(id(result))
        let ride = try #require(library.ride(withID: rideID))
        #expect(ride.isMerged)
        #expect(ride.name == "Harzrunde")
    }
}
