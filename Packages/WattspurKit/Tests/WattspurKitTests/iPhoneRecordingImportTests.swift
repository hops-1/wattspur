import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Recordings of the iPhone app at the Mac (B-212, B-213): the GPX names its bike, and the Mac
/// takes it instead of the active bike or the one asked for.
@MainActor
@Suite("Recordings from the iPhone")
struct iPhoneRecordingImportTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    static func recording(bikeID: UUID?) -> Data {
        var recording = RideRecording(startDate: Date(timeIntervalSince1970: 1_800_000_000))
        for second in 0...120 {
            recording.add(RideRecording.Fix(date: Date(timeIntervalSince1970: 1_800_000_000 + Double(second)),
                                            latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8,
                                            altitude: 150, horizontalAccuracy: 5, speed: 6))
        }
        return GPXWriter.document(name: "Zur Arbeit", segments: recording.gpxSegments,
                                  description: "Bike: Lastenrad", creator: GPXWriter.iPhoneCreator, bikeID: bikeID)
    }

    @Test("The header names creator and bike")
    func header() {
        let id = UUID()
        let header = GPXRideImporter.header(of: Self.recording(bikeID: id))
        #expect(header.creator == "Wattspur iOS")
        #expect(header.bikeID == id)
        #expect(GPXRideImporter.header(of: Self.recording(bikeID: nil)).bikeID == nil)
        #expect(GPXRideImporter.header(of: Data("<gpx creator='komoot'>".utf8)).creator == "komoot")
    }

    @Test("The importer reads the bike, and the Mac assigns the ride to it")
    func assignsBike() throws {
        _ = library.defaultBike()
        let cargo = library.makeBike(name: "Lastenrad", kind: .cargo)
        let parsed = try GPXRideImporter().parse(Self.recording(bikeID: cargo.id))
        #expect(parsed.suggestedBikeID == cargo.id)
        #expect(parsed.suggestedName == "Zur Arbeit")

        let result = library.importFile(data: Self.recording(bikeID: cargo.id), fileName: "Zur Arbeit.gpx",
                                        bike: library.activeBike())
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("not imported: \(result.outcome)")
            return
        }
        #expect(ride.bike?.id == cargo.id)
        #expect(ride.isFromiPhone)
        #expect(abs(ride.distance - 720) < 20)
    }

    @Test("An unknown bike falls back to the bike asked for")
    func unknownBike() throws {
        let active = library.activeBike()
        let result = library.importFile(data: Self.recording(bikeID: UUID()), fileName: "a.gpx")
        guard case .imported(let id) = result.outcome else { Issue.record("not imported"); return }
        #expect(library.ride(withID: id)?.bike?.id == active.id)
    }
}
