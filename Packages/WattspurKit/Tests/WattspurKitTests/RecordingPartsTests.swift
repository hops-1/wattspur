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

    /// A Bosch ride as the FIT import makes it, with points from `from` for `seconds`, 5 % longer than
    /// the GPS. `lead` seconds: the start in the file lies that long before the first point, as on
    /// 7.11.2026 (start 11:00, first point 12:14), and the elapsed time counts from there.
    @discardableResult
    private func boschRide(from offset: Int, seconds: Int, name: String, lead: Int = 0) -> Ride {
        let ride = Ride(name: name, startDate: start.addingTimeInterval(Double(offset - lead)))
        ride.sourceFormat = RideSource.fit.rawValue
        ride.elapsedTime = Double(seconds + lead)
        ride.timerTime = Double(seconds)
        ride.distance = Double(seconds) * 6 * 1.05
        ride.averagePower = 150
        ride.setSamples((lead...(lead + seconds)).map { RideSample(time: Double($0), latitude: 49.8, longitude: 8.8, power: 150) })
        container.mainContext.insert(ride)
        return ride
    }

    private var legs: [(start: Int, seconds: Int)] { [(0, 600), (1500, 600), (3000, 600)] }

    private var env: LibraryEnvironment {
        LibraryEnvironment(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()],
                           undoManager: nil, defaultBikeName: "Mein eBike")
    }

    private var parts: RecordingPartsService { RecordingPartsService(env) }

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

    @Test("A Bosch start long before the first point still counts by the points (7.11.2026)")
    func startBeforeFirstPoint() throws {
        _ = library.importFile(data: recording(legs: legs), fileName: "Harzrunde.gpx")
        let first = boschRide(from: 10, seconds: 590, name: "Tour 1", lead: 4440)
        boschRide(from: 1510, seconds: 590, name: "Tour 2")
        boschRide(from: 3010, seconds: 590, name: "Tour 3")

        let merged = try #require(parts.joinParts(around: first))
        #expect(merged.sortedParts.count == 3)
        #expect(merged.samples.contains { $0.lean == 12 })
    }

    @Test("Bosch rides merged before count as parts, also when a part of them comes again")
    func mergedBefore() throws {
        let recorded = library.importFile(data: recording(legs: legs), fileName: "Harzrunde.gpx")
        let recordingID = try #require(id(recorded))
        let first = boschRide(from: 10, seconds: 590, name: "Tour 1", lead: 4440)
        let second = boschRide(from: 1510, seconds: 590, name: "Tour 2")
        let third = boschRide(from: 3010, seconds: 590, name: "Tour 3")
        let earlier = try MergeService(env).merge([second, third], name: "Rückweg")
        #expect(earlier.isMerged)

        let merged = try #require(parts.joinParts(around: third))
        #expect(merged.name == "Harzrunde")
        #expect(Set(merged.sortedParts.map(\.id)) == Set([first.id, second.id, third.id]))
        #expect(merged.samples.contains { $0.lean == 12 })
        #expect(library.ride(withID: recordingID)?.deletedAt != nil)
    }

    // MARK: One Bosch ride over several recordings (11.11.2026)

    /// A recording of one leg north at 6 m/s from `offset` for `seconds`, with a lean angle of 12°.
    private func recording(at offset: Int, seconds: Int, name: String) -> Data {
        var recording = RideRecording(startDate: start.addingTimeInterval(Double(offset)))
        for second in 0...seconds {
            recording.add(RideRecording.Fix(date: start.addingTimeInterval(Double(offset + second)),
                                            latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8, altitude: 150,
                                            horizontalAccuracy: 5, speed: 6,
                                            motion: MotionValues(lean: 12, acceleration: 0, roughness: 0.1)))
        }
        return GPXWriter.document(name: name, segments: recording.gpxSegments, creator: GPXWriter.iPhoneCreator)
    }

    /// One Bosch ride over the `legs` (start and length in seconds), with the wheel distance in its
    /// points, 5 % longer than the GPS, as Bosch Flow saved the way to work and home on 11.11.2026.
    @discardableResult
    private func boschDay(legs: [(start: Int, seconds: Int)], name: String = "Reinheim Rundfahrt") -> Ride {
        var samples: [RideSample] = []
        var metres = 0.0
        for leg in legs {
            for second in leg.start...(leg.start + leg.seconds) {
                samples.append(RideSample(time: Double(second), latitude: 49.8, longitude: 8.8, distance: metres, power: 150))
                metres += 6 * 1.05
            }
        }
        let ride = Ride(name: name, startDate: start)
        ride.sourceFormat = RideSource.fit.rawValue
        ride.sourceIdentifier = "5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57"
        ride.elapsedTime = samples.last?.time ?? 0
        ride.timerTime = Double(samples.count)
        ride.distance = metres
        ride.averagePower = 150
        ride.setSamples(samples)
        ride.sourceFile = SourceFile(fileName: "\(name)-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit", data: Data([1, 2, 3]))
        container.mainContext.insert(ride)
        return ride
    }

    private var day: [(start: Int, seconds: Int)] { [(30, 1900), (33_000, 1800)] }

    private func importDayRecordings() throws -> (UUID, UUID) {
        let morning = try #require(id(library.importFile(data: recording(at: 0, seconds: 1960, name: "ZEISS Pendelstrecke"),
                                                         fileName: "Morgen.gpx")))
        let evening = try #require(id(library.importFile(data: recording(at: 32_980, seconds: 1840, name: "Zeiss"),
                                                         fileName: "Abend.gpx")))
        return (morning, evening)
    }

    @Test("A Bosch ride over two recordings becomes two rides with the Bosch values, the names and the lean angle")
    func splits() throws {
        let (morningID, eveningID) = try importDayRecordings()
        let bosch = boschDay(legs: day)
        let boschID = bosch.id

        let pieces = try #require(parts.splitAcrossRecordings(bosch))
        #expect(pieces.map(\.name) == ["ZEISS Pendelstrecke", "Zeiss"])
        #expect(pieces.allSatisfy { $0.source == .fit && $0.attachedSourceFormat == RideSource.gpx.rawValue })
        #expect(pieces.allSatisfy { $0.samples.contains { $0.lean == 12 } && $0.samples.allSatisfy { $0.power == 150 } })
        #expect(abs(pieces[0].distance - 1900 * 6 * 1.05) < 10)
        #expect(abs(pieces[1].distance - 1800 * 6 * 1.05) < 10)
        #expect(abs(pieces[1].startDate.timeIntervalSince(start) - 33_000) < 1)
        #expect(pieces.allSatisfy { $0.sourceFile?.fileName.hasSuffix(".fit") == true })
        #expect(library.ride(withID: morningID)?.deletedAt != nil)
        #expect(library.ride(withID: eveningID)?.deletedAt != nil)
        #expect(library.ride(withID: boschID) == nil)
    }

    @Test("When the second recording comes last, its import splits the Bosch ride already there")
    func splitsWhenRecordingLast() throws {
        _ = try #require(id(library.importFile(data: recording(at: 0, seconds: 1960, name: "ZEISS Pendelstrecke"),
                                               fileName: "Morgen.gpx")))
        let bosch = boschDay(legs: day)
        let boschID = bosch.id
        let result = library.importFile(data: recording(at: 32_980, seconds: 1840, name: "Zeiss"), fileName: "Abend.gpx")
        guard case .attached(let pieceID) = result.outcome else {
            Issue.record("expected the evening recording to get the Bosch values, got \(result.outcome)")
            return
        }
        #expect(library.ride(withID: pieceID)?.name == "Zeiss")
        #expect(library.ride(withID: boschID) == nil)
    }

    @Test("A Bosch ride far longer than the recordings stays whole")
    func noSplitWhenDistanceDiffers() throws {
        _ = try importDayRecordings()
        let bosch = boschDay(legs: [(30, 1900), (10_000, 3000), (33_000, 1800)])
        #expect(parts.splitAcrossRecordings(bosch) == nil)
        #expect(bosch.deletedAt == nil)
    }

    @Test("A Bosch ride over one recording is not split")
    func noSplitForOneRecording() throws {
        _ = try #require(id(library.importFile(data: recording(at: 0, seconds: 1960, name: "ZEISS Pendelstrecke"),
                                               fileName: "Morgen.gpx")))
        let bosch = boschDay(legs: [(30, 1900)])
        #expect(parts.splitAcrossRecordings(bosch) == nil)
    }
}
