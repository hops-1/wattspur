import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@MainActor
@Suite("State for the iPhone")
struct PhoneStateWriterTests {
    let container: ModelContainer
    let library: RideLibrary
    let folder: URL

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("wattspur-phone-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    var writer: PhoneStateWriter { PhoneStateWriter(context: container.mainContext) }
    var routesFolder: URL { folder.appending(path: "iPhone/Routen") }

    func readLibrary() throws -> RideExchange.Library {
        try RideExchange.library(from: Data(contentsOf: folder.appending(path: "iPhone/Stand.json")))
    }

    func routeFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: routesFolder.path).sorted()
    }

    @discardableResult
    func importRide() throws -> Ride {
        let result = library.importFile(data: try Fixture.data("reinheim-rundfahrt"), fileName: "Reinheim.fit")
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return ride
    }

    @Test("Writes the rides with their figures, the bikes and one route file per ride")
    func writesState() throws {
        let ride = try importRide()
        let result = try writer.write(to: folder, generator: "Wattspur test", now: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(result == .init(rides: 1, routesWritten: 1, routesRemoved: 0))
        let state = try readLibrary()
        #expect(state.generator == "Wattspur test")
        #expect(state.bikes.map(\.id) == [ride.bike?.id].compactMap { $0 })
        let exchanged = try #require(state.rides.first)
        #expect(exchanged.id == ride.id)
        #expect(exchanged.distance == ride.distance)
        #expect(exchanged.totalAscent == ride.totalAscent)
        #expect(exchanged.bikeID == ride.bike?.id)
        #expect(exchanged.source == "fit")

        let file = try #require(exchanged.routeFile)
        #expect(try routeFiles() == [file])
        let route = try RideExchange.route(from: Data(contentsOf: routesFolder.appending(path: file)))
        #expect(route.rideID == ride.id)
        // About 19.5 km at one point per 20 m.
        #expect((800...1000).contains(route.pointCount))
        // The profile runs on the ride's own distance; the sample loses GPS shortly before the end.
        #expect(abs(route.segments[0].distance.last! - ride.distance) / ride.distance < 0.03)
    }

    @Test("A second run keeps the route files; a trashed ride's route is removed")
    func updates() throws {
        let ride = try importRide()
        try writer.write(to: folder, generator: "t")
        #expect(try writer.write(to: folder, generator: "t").routesWritten == 0)

        library.moveToTrash(ride)
        let result = try writer.write(to: folder, generator: "t")
        #expect(result == .init(rides: 0, routesWritten: 0, routesRemoved: 1))
        #expect(try readLibrary().rides.isEmpty)
        #expect(try routeFiles().isEmpty)
    }

    @Test("A changed ride gets a new route file")
    func changedRide() throws {
        let ride = try importRide()
        let before = try #require(try writer.write(to: folder, generator: "t") == .init(rides: 1, routesWritten: 1) ? readLibrary().rides.first?.routeFile : nil)
        ride.distance += 1
        try writer.write(to: folder, generator: "t")
        let after = try #require(try readLibrary().rides.first?.routeFile)
        #expect(after != before)
        #expect(try routeFiles() == [after])
    }

    @Test("Sample rides are left out")
    func skipsSamples() throws {
        _ = library.importSample(data: try Fixture.data("reinheim-rundfahrt"), name: "Beispielfahrt")
        #expect(try writer.write(to: folder, generator: "t").rides == 0)
    }

    @Test("The folder import does not look into the iPhone folder")
    func importIgnoresState() async throws {
        try importRide()
        try writer.write(to: folder, generator: "t")
        let summary = await FolderImport(library: library, folder: folder).run()
        #expect(summary == FolderImport.Summary())
    }
}
