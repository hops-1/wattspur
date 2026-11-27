import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// Planned tours on the iPhone and iPad (B-373): read with the library, renamed, trashed, restored,
/// deleted and shared. Invented files only.
@MainActor
@Suite("Planned tours on the iPhone")
struct PhonePlannedTourTests {
    let container: ModelContainer
    let database: PhoneDatabase

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
    }

    /// A track without times going north from 50.0/`longitude`, 200 points 50 m apart.
    private static func tour(name: String, longitude: Double = 9) -> Data {
        let body = (0..<200).map { "<trkpt lat=\"\(50 + Double($0) * 50 / 111_195)\" lon=\"\(longitude)\"><ele>\(300 + $0 / 2)</ele></trkpt>" }.joined()
        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Planer" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>\(name)</name><trkseg>\(body)</trkseg></trk></gpx>
        """.utf8)
    }

    private func importTour(_ name: String, longitude: Double = 9, at date: Date) throws -> UUID {
        let result = database.library.importFile(data: Self.tour(name: name, longitude: longitude), fileName: "\(name).gpx")
        let id = try #require(result.outcome.plannedRouteID)
        database.library.plannedRoute(withID: id)?.createdAt = date
        try database.context.save()
        return id
    }

    @Test("The reading lists the tours newest first with a thinned preview, trashed ones apart")
    func reading() async throws {
        let older = try importTour("Zum Stausee", at: Date(timeIntervalSince1970: 1_800_000_000))
        let newer = try importTour("Über den Pass", longitude: 9.1, at: Date(timeIntervalSince1970: 1_800_100_000))
        let trashed = try importTour("Alte Runde", longitude: 9.2, at: Date(timeIntervalSince1970: 1_800_050_000))
        database.movePlannedTourToTrash(id: trashed, at: Date(timeIntervalSince1970: 1_800_200_000))

        let reading = try LibraryReading.read(in: database.context, generator: "Test")
        #expect(reading.plannedTours.map(\.id) == [newer, older])
        #expect(reading.trashedTours.map(\.id) == [trashed])
        let first = try #require(reading.plannedTours.first)
        #expect(first.name == "Über den Pass")
        #expect(first.pointCount == 200)
        #expect(first.preview.count == PlannedTour.previewPointCount)
        #expect(abs(first.distance - 199 * 50) < 2)
        #expect(first.ascent != nil)

        // The same off the main thread.
        let background = LibraryReader(modelContainer: container)
        try database.context.save()
        let read = try await background.read(generator: "Test")
        #expect(read.plannedTours.map(\.id) == [newer, older])
    }

    @Test("Rename, trash, restore and delete for good")
    func changes() throws {
        let id = try importTour("Zum Stausee", at: .now)
        #expect(database.renamePlannedTour(id: id, to: "Seerunde"))
        #expect(!database.renamePlannedTour(id: id, to: "   "))
        #expect(database.library.plannedRoute(withID: id)?.name == "Seerunde")

        // Only a tour in the trash can be deleted for good.
        database.deletePlannedTourPermanently(id: id)
        #expect(database.library.plannedRoute(withID: id) != nil)

        database.movePlannedTourToTrash(id: id)
        #expect(database.library.plannedRoutes().isEmpty)
        database.restorePlannedTour(id: id)
        #expect(database.library.plannedRoutes().map(\.id) == [id])

        database.movePlannedTourToTrash(id: id)
        database.deletePlannedTourPermanently(id: id)
        #expect(database.library.plannedRoute(withID: id) == nil)
    }

    @Test("The detail has the whole line and the profile; sharing gives the original file under the new name")
    func detailAndShare() throws {
        let id = try importTour("Zum Stausee", at: .now)
        let detail = try #require(database.plannedTourDetail(id: id))
        #expect(detail.points.count == 200)
        #expect(detail.profile.count == 200)
        #expect(detail.altitudes == 300...399)
        database.renamePlannedTour(id: id, to: "Seerunde: lang")
        let shared = try #require(database.plannedTourGPX(id: id))
        #expect(shared.fileName == "Seerunde- lang.gpx")
        #expect(shared.data == Self.tour(name: "Zum Stausee"))
        #expect(database.plannedTourDetail(id: UUID()) == nil)
    }
}
