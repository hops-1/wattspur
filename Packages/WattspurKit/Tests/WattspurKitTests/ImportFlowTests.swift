import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

/// The decisions of the manual import, now in the Kit so the iPhone can use them too (B-188).
@MainActor
@Suite("Manual import steps")
final class ImportFlowTests {
    let container: ModelContainer
    let library: RideLibrary
    let flow = ImportFlow()
    let folder: URL

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
        _ = library.prepareBikes()
        folder = FileManager.default.temporaryDirectory.appending(path: "ImportFlowTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // The temporary folder goes with the suite (R-10).
    deinit { try? FileManager.default.removeItem(at: folder) }

    private func file(_ name: String, _ data: Data) throws -> URL {
        let url = folder.appending(path: name)
        try data.write(to: url)
        return url
    }

    private var fit: URL {
        get throws { try file("Beispielrunde-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit", GPXFixture.fitData("pair-tour1-bosch-flow")) }
    }

    private var gpx: URL {
        get throws { try file("Beispielrunde.gpx", GPXFixture.data("pair-tour1-bosch-flow")) }
    }

    @Test("A FIT file is imported at once, written down and reported")
    func importsFIT() throws {
        var recorded: [String] = []
        var imported: [UUID] = []
        flow.onImported = { imported += $0 }
        flow.start([try fit], library: library) { result, _ in recorded.append(result.fileName) }
        #expect(imported.count == 1)
        #expect(recorded.count == 1)
        #expect(flow.bikeQuestion == nil)
        let report = try #require(flow.report)
        #expect(report.hasNews)
        #expect(report.importedCount == 1)
    }

    @Test("A GPX file asks for the bike once there are two, and goes to the chosen one")
    func asksForBike() throws {
        let cargo = library.makeBike(name: "Lastenrad", kind: .cargo)
        let url = try gpx
        flow.start([url], library: library) { _, _ in }
        let question = try #require(flow.bikeQuestion)
        #expect(question.gpxURLs == [url])
        var imported: [UUID] = []
        flow.onImported = { imported += $0 }
        flow.confirm(question, bike: cargo, library: library) { _, _ in }
        #expect(flow.bikeQuestion == nil)
        let id = try #require(imported.first)
        #expect(library.ride(withID: id)?.bike?.id == cargo.id)
    }

    @Test("A second import while the first asks waits for the answer, then runs (R-46)")
    func secondImportWaits() throws {
        let cargo = library.makeBike(name: "Lastenrad", kind: .cargo)
        let first = try gpx
        flow.start([first], library: library) { _, _ in }
        let question = try #require(flow.bikeQuestion)
        var imported: [UUID] = []
        flow.onImported = { imported += $0 }
        flow.start([try fit], library: library) { _, _ in }
        #expect(flow.bikeQuestion?.id == question.id)
        #expect(imported.isEmpty)
        flow.confirm(question, bike: cargo, library: library) { _, _ in }
        #expect(imported.count == 2)
        #expect(library.ride(withID: imported[0])?.bike?.id == cargo.id)
    }

    @Test("With one bike a GPX file needs no question")
    func oneBike() throws {
        flow.start([try gpx], library: library) { _, _ in }
        #expect(flow.bikeQuestion == nil)
        #expect(flow.report != nil)
    }

    @Test("The Bosch FIT for a ride that is there as GPX asks what to do, and can take the Bosch values")
    func fitForGPX() throws {
        flow.start([try gpx], library: library) { _, _ in }
        flow.report = nil
        flow.start([try fit], library: library) { _, _ in }
        let comparison = try #require(flow.comparisons.first)
        #expect(comparison.kind == .fitForGPX)
        flow.update(comparison, library: library)
        #expect(flow.comparisons.isEmpty)
        let ride = try #require(library.ride(withID: comparison.rideID))
        #expect(ride.sourceFormat == "fit")
        #expect(ride.timerTime == 2916)
    }

    @Test("Skipping a comparison leaves the library as it was")
    func skip() throws {
        flow.start([try gpx], library: library) { _, _ in }
        flow.start([try fit], library: library) { _, _ in }
        #expect(!flow.comparisons.isEmpty)
        flow.skip()
        #expect(flow.comparisons.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<Ride>()).count == 1)
    }
}
