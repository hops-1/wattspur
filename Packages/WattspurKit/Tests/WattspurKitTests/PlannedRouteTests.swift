import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

/// Planned tours in the library (B-372): import, the question “Ride or planned tour?”, trash, sync
/// duplicates and the watched folder. Invented files only.
@MainActor
@Suite("Planned tours")
final class PlannedRouteTests {
    let container: ModelContainer
    let library: RideLibrary
    let folder: URL

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
        _ = library.prepareBikes()
        folder = FileManager.default.temporaryDirectory.appending(path: "PlannedRouteTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

    /// A track without times, 10 points 50 m apart going north, and a loop when asked.
    private static func untimed(loop: Bool = false, name: String = "Zum Aussichtsturm") -> Data {
        var points = (0..<10).map { (50 + Double($0) * 50 / 111_320, 9.0) }
        if loop { points += points.reversed().map { ($0.0, 9.0005) } }
        let body = points.enumerated().map { "<trkpt lat=\"\($1.0)\" lon=\"\($1.1)\"><ele>\(300 + $0)</ele></trkpt>" }.joined()
        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Planer" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>\(name)</name><trkseg>\(body)</trkseg></trk></gpx>
        """.utf8)
    }

    /// Estimated times from a planner that is not komoot: 8 s steps, 40 m apart.
    private static let estimated: Data = {
        let start = Date(timeIntervalSince1970: 1_780_732_800)
        let body = (0..<30).map { i in
            "<trkpt lat=\"\(50 + Double(i) * 40 / 111_320)\" lon=\"9.0\"><ele>300</ele><time>\(GPXWriter.timestamp(start.addingTimeInterval(Double(i) * 8)))</time></trkpt>"
        }.joined()
        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Planer" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>Geschätzt</name><trkseg>\(body)</trkseg></trk></gpx>
        """.utf8)
    }()

    private func file(_ name: String, _ data: Data) throws -> URL {
        let parent = folder.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let url = parent.appending(path: name)
        try data.write(to: url)
        return url
    }

    private var rideCount: Int { (try? container.mainContext.fetchCount(FetchDescriptor<Ride>())) ?? -1 }

    // MARK: - Import

    @Test("A GPX file without times becomes a planned tour with its figures, the original file and a log line")
    func importsTour() throws {
        let data = Self.untimed()
        let result = library.importFile(data: data, fileName: "Turm.gpx")
        let id = try #require(result.outcome.plannedRouteID)
        guard case .plannedTour = result.outcome else { Issue.record("Expected a new tour"); return }
        library.record(result, source: .manual)

        let route = try #require(library.plannedRoute(withID: id))
        #expect(route.name == "Zum Aussichtsturm")
        #expect(route.originalName == "Zum Aussichtsturm")
        #expect(route.source == .gpx)
        #expect(route.pointCount == 10)
        #expect(route.points.count == 10)
        #expect(abs(route.distance - 450) < 1)
        #expect(route.ascent == 6)
        #expect(!route.isLoop)
        #expect(route.sourceFileName == "Turm.gpx")
        #expect(route.sourceData == data)
        #expect(route.parserVersion == PlannedTourReader.parserVersion)
        #expect(route.tour.points == route.points)
        #expect(rideCount == 0)

        let record = try #require(library.importRecords().first)
        #expect(record.outcome == .imported)
        #expect(record.isPlannedTour)
        #expect(record.rideID == nil)
        #expect(!record.isPlannedRoute)
        #expect(ImportLogEntry(result: result).outcome == "planned tour")
    }

    @Test("A route (rte) and a loop come in as tours; without a name the file names it")
    func routeAndLoop() throws {
        let route = try GPXFixture.data("route-and-waypoints-only")
        let a = try #require(library.importFile(data: route, fileName: "Route.gpx").outcome.plannedRouteID)
        #expect(library.plannedRoute(withID: a)?.name == "Geplante Route")
        let b = try #require(library.importFile(data: Self.untimed(loop: true, name: ""), fileName: "Hin und zurück.gpx").outcome.plannedRouteID)
        let loop = try #require(library.plannedRoute(withID: b))
        #expect(loop.isLoop)
        #expect(loop.name == "Hin und zurück")
        let ids = Set(library.plannedRoutes().map(\.id))
        #expect(ids == [a, b])
    }

    @Test("The same tour again is a duplicate, and comes back from the trash")
    func duplicate() throws {
        let data = Self.untimed()
        let id = try #require(library.importFile(data: data, fileName: "Turm.gpx").outcome.plannedRouteID)
        let route = try #require(library.plannedRoute(withID: id))
        library.moveToTrash([route])
        #expect(library.plannedRoutes().isEmpty)
        #expect(library.plannedRoutes(includingTrash: true).count == 1)

        let again = library.importFile(data: data, fileName: "Turm (1).gpx")
        guard case .plannedTourDuplicate(let existing) = again.outcome else { Issue.record("Expected a duplicate"); return }
        #expect(existing == id)
        #expect(again.restoredFromTrash)
        #expect(!route.isInTrash)
        #expect(library.plannedRoutes(includingTrash: true).count == 1)
        library.record(again, source: .manual)
        #expect(library.importRecords().first?.outcome == .duplicate)
        #expect(library.importRecords().first?.isPlannedTour == true)
    }

    @Test("A komoot tour with estimated times is a tour without asking; asked as a ride it is a ride")
    func komootAutomaticOrRide() throws {
        let data = try GPXFixture.data("komoot-planned-tour")
        let tour = library.importFile(data: data, fileName: "Erfundene Runde.gpx")
        let id = try #require(tour.outcome.plannedRouteID)
        #expect(library.plannedRoute(withID: id)?.source == .komoot)
        #expect(rideCount == 0)

        let ride = library.importFile(data: data, fileName: "Erfundene Runde.gpx", as: .ride)
        guard case .imported = ride.outcome else { Issue.record("Expected a ride, got \(ride.outcome)"); return }
        #expect(rideCount == 1)
        // A file with real times becomes a tour only when asked.
        let forced = library.importFile(data: Self.estimated, fileName: "Geschätzt.gpx", as: .plannedTour)
        #expect(forced.outcome.plannedRouteID != nil)
    }

    @Test("Ride files stay rides, unchanged: a FIT, a ride GPX, a ridden komoot tour and estimated times not from komoot")
    func ridesStayRides() throws {
        for (name, data) in [("Beispielrunde-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit", try GPXFixture.fitData("pair-tour1-bosch-flow")),
                             ("Tour2.gpx", try GPXFixture.data("pair-tour2-bosch-flow")),
                             ("Komoot gefahren.gpx", try GPXFixture.data("pair-tour1-komoot")),
                             ("Geschätzt.gpx", Self.estimated)] {
            let result = library.importFile(data: data, fileName: name, detectDuplicates: false)
            guard case .imported = result.outcome else { Issue.record("\(name): \(result.outcome)"); continue }
        }
        #expect(rideCount == 4)
        #expect(library.plannedRoutes().isEmpty)
        // The ride from a GPX is the same as straight from the ride importer.
        let parsed = try GPXRideImporter().parse(try GPXFixture.data("pair-tour2-bosch-flow"))
        let ride = try #require(try container.mainContext.fetch(FetchDescriptor<Ride>()).first { $0.sourceFile?.fileName == "Tour2.gpx" })
        #expect(ride.distance == parsed.summary.distance)
        #expect(ride.startDate == parsed.startDate)
        #expect(ride.plannedRouteID == nil)
    }

    @Test("A recording of the iPhone is always a ride")
    func recordingIsRide() throws {
        let result = library.importFile(data: Self.estimated, fileName: "Aufnahme.gpx", as: .ride)
        guard case .imported = result.outcome else { Issue.record("\(result.outcome)"); return }
    }

    // MARK: - Rename and trash

    @Test("Rename, trash and restore with undo; the trash is emptied after 30 days")
    func renameAndTrash() throws {
        let undo = UndoManager()
        let library = library.using(undo)
        let id = try #require(library.importFile(data: Self.untimed(), fileName: "Turm.gpx").outcome.plannedRouteID)
        let route = try #require(library.plannedRoute(withID: id))
        library.rename(route, to: "  Turm am Sonntag ")
        #expect(route.name == "Turm am Sonntag")
        library.rename(route, to: " ")
        #expect(route.name == "Turm am Sonntag")
        undo.undo()
        #expect(route.name == "Zum Aussichtsturm")

        let then = Date(timeIntervalSince1970: 1_790_000_000)
        library.moveToTrash([route], at: then)
        #expect(route.isInTrash)
        undo.undo()
        #expect(!route.isInTrash)
        library.moveToTrash([route], at: then)
        library.restore([route])
        #expect(!route.isInTrash)

        library.moveToTrash([route], at: then)
        library.purgeTrash(now: then.addingTimeInterval(29 * 86_400))
        #expect(library.plannedRoute(withID: id) != nil)
        library.purgeTrash(now: then.addingTimeInterval(31 * 86_400))
        #expect(library.plannedRoute(withID: id) == nil)
    }

    // MARK: - Sync

    @Test("The same tour from two devices is merged: the oldest stays, takes the new name, leaves the trash and the ride")
    func syncDuplicates() throws {
        let context = container.mainContext
        let tour = try PlannedTourReader().read(Self.untimed())
        let older = PlannedRoute(name: "Zum Aussichtsturm", tour: tour)
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        older.deletedAt = Date(timeIntervalSince1970: 2_000)
        let newer = PlannedRoute(name: "Zum Aussichtsturm", tour: tour)
        newer.createdAt = Date(timeIntervalSince1970: 1_500)
        newer.name = "Turm mit Kindern"
        let other = PlannedRoute(name: "Andere", tour: try PlannedTourReader().read(Self.untimed(loop: true)))
        let ride = Ride(name: "Gefahren", startDate: .now)
        ride.plannedRouteID = newer.id
        [older, newer, other].forEach(context.insert)
        context.insert(ride)

        let report = library.mergeSyncDuplicates()
        #expect(report.plannedRoutes == 1)
        #expect(!report.isEmpty)
        let left = library.plannedRoutes(includingTrash: true)
        #expect(left.count == 2)
        #expect(left.contains { $0.id == older.id })
        #expect(older.name == "Turm mit Kindern")
        #expect(!older.isInTrash)
        #expect(ride.plannedRouteID == older.id)
        #expect(library.mergeSyncDuplicates().isEmpty)
    }

    // MARK: - Import flow

    @Test("A komoot file asks “Ride or planned tour?” with the tour preselected; as a tour it is saved and reported")
    func flowAsksKomoot() throws {
        let flow = ImportFlow()
        let url = try file("Erfundene Runde.gpx", GPXFixture.data("komoot-planned-tour"))
        var recorded: [ImportResult] = []
        flow.start([url], library: library) { result, _ in recorded.append(result) }
        let question = try #require(flow.tourQuestion)
        #expect(question.suggestsTour)
        #expect(question.tour.name == "Erfundene Runde")
        #expect(question.fileName == "Erfundene Runde.gpx")
        #expect(flow.isAsking)
        #expect(recorded.isEmpty)

        flow.answer(question, asTour: true)
        #expect(flow.tourQuestion == nil)
        #expect(!flow.isBusy)
        #expect(library.plannedRoutes().count == 1)
        #expect(rideCount == 0)
        #expect(recorded.count == 1)
        let report = try #require(flow.report)
        #expect(report.plannedTourCount == 1)
        #expect(report.importedCount == 0)
        #expect(flow.takeSummary().plannedTours == 1)
    }

    @Test("Answered “Ride”, the file is a ride and asks for the bike as usual; skipped, nothing happens")
    func flowAnswerRide() throws {
        let cargo = library.makeBike(name: "Lastenrad", kind: .cargo)
        let flow = ImportFlow()
        let url = try file("Geschätzt.gpx", Self.estimated)
        let skipped = try file("Erfundene Runde.gpx", GPXFixture.data("komoot-planned-tour"))
        flow.start([url, skipped], library: library) { _, _ in }
        let first = try #require(flow.tourQuestion)
        #expect(!first.suggestsTour)
        flow.answer(first, asTour: false)
        let second = try #require(flow.tourQuestion)
        #expect(second.url == skipped)
        // An old question is no answer to the open one.
        flow.skip(first)
        #expect(flow.tourQuestion?.id == second.id)
        flow.skip(second)
        #expect(flow.tourQuestion == nil)

        let bikeQuestion = try #require(flow.bikeQuestion)
        flow.confirm(bikeQuestion, bike: cargo, library: library) { _, _ in }
        #expect(rideCount == 1)
        #expect(library.plannedRoutes().isEmpty)
        let ride = try #require(try container.mainContext.fetch(FetchDescriptor<Ride>()).first)
        #expect(ride.bike?.id == cargo.id)
    }

    @Test("A tour without times needs no question, not even for the bike")
    func flowTourWithoutQuestion() throws {
        _ = library.makeBike(name: "Lastenrad", kind: .cargo)
        let flow = ImportFlow()
        flow.start([try file("Turm.gpx", Self.untimed())], library: library) { _, _ in }
        #expect(flow.tourQuestion == nil)
        #expect(flow.bikeQuestion == nil)
        #expect(library.plannedRoutes().count == 1)
        #expect(flow.report?.plannedTourCount == 1)
    }

    @Test("A second import waits until the tour question is answered")
    func flowWaits() async throws {
        let flow = ImportFlow()
        flow.start([try file("Erfundene Runde.gpx", GPXFixture.data("komoot-planned-tour"))], library: library) { _, _ in }
        flow.start([try file("Turm.gpx", Self.untimed())], library: library) { _, _ in }
        #expect(library.plannedRoutes().isEmpty)
        #expect(flow.isBusy)
        flow.answer(try #require(flow.tourQuestion), asTour: true)
        #expect(library.plannedRoutes().count == 2)
        #expect(!flow.isBusy)
    }

    @Test("On the iPhone, file by file: the tour counts in the summary")
    func flowStepsThroughFiles() async throws {
        let flow = ImportFlow()
        flow.stepsThroughFiles = true
        flow.start([try file("Turm.gpx", Self.untimed()), try file("Turm 2.gpx", Self.untimed())], library: library) { _, _ in }
        while flow.progress != nil { await Task.yield() }
        let summary = flow.takeSummary()
        #expect(summary.plannedTours == 1)
        #expect(summary.duplicates == 1)
    }

    // MARK: - Watched folder

    @Test("The watched folder asks nobody: a komoot tour becomes a tour and moves to “Imported”")
    func watchedFolder() async throws {
        let watched = folder.appending(path: "Watched")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        try GPXFixture.data("komoot-planned-tour").write(to: watched.appending(path: "Erfundene Runde.gpx"))
        try Self.untimed().write(to: watched.appending(path: "Turm.gpx"))
        try Self.untimed().write(to: watched.appending(path: "Turm noch einmal.gpx"))
        let folderImport = FolderImport(library: library, folder: watched, settleTime: 0)
        let summary = await folderImport.run()
        #expect(summary.plannedTours == 2)
        #expect(summary.duplicates == 1)
        #expect(summary.failed == 0)
        #expect(rideCount == 0)
        let moved = try FileManager.default.contentsOfDirectory(atPath: watched.appending(path: "Imported").path)
        #expect(moved.count == 3)
        #expect(library.importRecords().allSatisfy { $0.isPlannedTour && $0.source == .folder })
    }
}
