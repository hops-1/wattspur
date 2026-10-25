import Foundation
import SwiftData
import Testing
@testable import WattspurKit

/// Text edits on a GPX fixture, to make the files of other sources and recording errors.
private enum Edit {
    static func text(_ name: String) throws -> String {
        String(decoding: try GPXFixture.data(name), as: UTF8.self)
    }

    /// Adds heart rate and temperature (Garmin TrackPointExtension) to every track point.
    static func addSensors(_ gpx: String) -> String {
        var index = 0
        var out = ""
        var rest = Substring(gpx.replacingOccurrences(of: "<gpx ", with: "<gpx xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\" "))
        while let end = rest.range(of: "</trkpt>") {
            out += rest[..<end.lowerBound]
            out += "<extensions><gpxtpx:TrackPointExtension><gpxtpx:atemp>18.5</gpxtpx:atemp><gpxtpx:hr>\(120 + index % 40)</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt>"
            rest = rest[end.upperBound...]
            index += 1
        }
        return out + rest
    }

    /// Only the first `count` track points.
    static func firstPoints(_ gpx: String, _ count: Int) -> String {
        var rest = Substring(gpx)
        var out = ""
        for _ in 0..<count {
            guard let end = rest.range(of: "</trkpt>") else { break }
            out += rest[..<end.upperBound]
            rest = rest[end.upperBound...]
        }
        return out + "</trkseg></trk></gpx>"
    }

    /// Every position moved north by `degrees`.
    static func shifted(_ gpx: String, by degrees: Double) -> String {
        var result = gpx
        let pattern = /lat="([0-9.\-]+)"/
        for match in gpx.matches(of: pattern).reversed() {
            let shifted = (Double(match.1) ?? 0) + degrees
            result.replaceSubrange(match.range, with: "lat=\"\(shifted)\"")
        }
        return result
    }
}

private let tour1UUID = "5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57"

@MainActor
@Suite("Same ride as FIT and GPX")
struct GPXDuplicateTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
    }

    private func rides() throws -> [Ride] {
        try container.mainContext.fetch(FetchDescriptor<Ride>())
    }

    @discardableResult
    private func importFIT(_ name: String = "pair-tour1-bosch-flow", as fileName: String? = nil, bike: Bike? = nil) throws -> ImportResult {
        library.importFile(data: try GPXFixture.fitData(name), fileName: fileName ?? "Beispielrunde-\(tour1UUID).fit", bike: bike)
    }

    @discardableResult
    private func importGPX(_ text: String, as fileName: String, bike: Bike? = nil) -> ImportResult {
        library.importFile(data: Data(text.utf8), fileName: fileName, bike: bike)
    }

    // MARK: - GPX for a Bosch ride

    @Test("A GPX for a Bosch ride is attached without asking: heart rate and temperature, source noted")
    func attachesGPX() throws {
        try importFIT()
        let gpx = Edit.addSensors(try Edit.text("pair-tour1-komoot"))
        let result = importGPX(gpx, as: "Beispielrunde-komoot.gpx")
        guard case .attached(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Expected attached, got \(result.outcome)")
            return
        }
        #expect(try rides().count == 1)
        #expect(ride.sourceFormat == "fit")
        #expect(ride.attachedSourceName == "Beispielrunde-komoot.gpx")
        #expect(ride.attachedSourceFormat == "gpx")
        #expect(ride.summaryEstimatedFromGPS == false)
        // The Bosch values stay.
        #expect(ride.timerTime == 2916)
        #expect(ride.distance == 19_543)
        #expect(ride.averagePower == 135)
        let samples = ride.samples
        let withHeartRate = samples.filter { $0.heartRate != nil }.count
        #expect(Double(withHeartRate) / Double(samples.count) > 0.8)
        #expect(samples.first { $0.temperature != nil }?.temperature == 18.5)
        #expect(samples.allSatisfy { $0.power == nil || $0.power! >= 0 })
        // The heart rate sits where the GPX put it (120...159), not shifted.
        #expect(samples.compactMap(\.heartRate).allSatisfy { (120...159).contains($0) })
    }

    @Test("A second GPX for a ride that has one attached is a duplicate to decide on, and never replaces the Bosch values")
    func secondGPX() throws {
        try importFIT()
        importGPX(Edit.addSensors(try Edit.text("pair-tour1-komoot")), as: "a.gpx")
        let second = importGPX(try Edit.text("pair-tour1-bosch-flow"), as: "b.gpx")
        guard case .duplicate(let id) = second.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Expected duplicate, got \(second.outcome)")
            return
        }
        try library.update(ride, with: Data(try Edit.text("pair-tour1-bosch-flow").utf8), fileName: "b.gpx")
        #expect(ride.sourceFormat == "fit")
        #expect(ride.timerTime == 2916)
        #expect(ride.attachedSourceName == "b.gpx")
        #expect(try rides().count == 1)
    }

    // MARK: - Bosch FIT for a GPX ride

    @Test("A Bosch FIT for a GPX ride is reported to ask; updating takes the Bosch values and keeps the local ones")
    func fitForGPX() throws {
        let gpxResult = importGPX(Edit.addSensors(try Edit.text("pair-tour1-bosch-flow")), as: "tour1.gpx")
        guard case .imported(let gpxID) = gpxResult.outcome, let ride = library.ride(withID: gpxID) else {
            Issue.record("Expected import")
            return
        }
        library.rename(ride, to: "Meine Tour")
        let other = library.makeBike(name: "Zweitrad")
        ride.bike = other
        #expect(ride.summaryEstimatedFromGPS)

        let result = try importFIT(bike: other)
        guard case .fitForGPX(let id) = result.outcome else {
            Issue.record("Expected fitForGPX, got \(result.outcome)")
            return
        }
        #expect(id == gpxID)
        #expect(try rides().count == 1)
        #expect(ride.sourceFormat == "gpx")   // nothing changed yet

        try library.update(ride, with: try GPXFixture.fitData("pair-tour1-bosch-flow"), fileName: "Beispielrunde-\(tour1UUID).fit")
        #expect(ride.sourceFormat == "fit")
        #expect(ride.source == .fit)
        #expect(ride.sourceIdentifier == tour1UUID)
        #expect(ride.summaryEstimatedFromGPS == false)
        #expect(ride.timerTime == 2916)
        #expect(ride.distance == 19_543)
        #expect(ride.name == "Meine Tour")
        #expect(ride.bike?.id == other.id)
        #expect(ride.sourceFile?.fileName == "Beispielrunde-\(tour1UUID).fit")
        // The GPX stays noted, its heart rate is kept on the Bosch time series.
        #expect(ride.attachedSourceName == "tour1.gpx")
        #expect(ride.attachedSourceFormat == "gpx")
        #expect(ride.samples.filter { $0.heartRate != nil }.count > 2000)
        #expect(ride.averagePower == 135)

        // The Bosch file is now known by its ID.
        let again = try importFIT(bike: other)
        guard case .duplicate = again.outcome else {
            Issue.record("Expected duplicate, got \(again.outcome)")
            return
        }
    }

    @Test("Two GPX files of one tour are a duplicate, as with two FIT exports")
    func gpxAndGPX() throws {
        let first = importGPX(try Edit.text("pair-tour1-bosch-flow"), as: "bosch.gpx")
        guard case .imported(let id) = first.outcome else {
            Issue.record("Expected import")
            return
        }
        let second = importGPX(try Edit.text("pair-tour1-komoot"), as: "komoot.gpx")
        guard case .duplicate(let existing) = second.outcome else {
            Issue.record("Expected duplicate, got \(second.outcome)")
            return
        }
        #expect(existing == id)
        #expect(try rides().count == 1)
        // "Update" replaces the values with the new file; name and bike stay.
        let ride = try #require(library.ride(withID: id))
        library.rename(ride, to: "Meine Tour")
        try library.update(ride, with: try GPXFixture.data("pair-tour1-komoot"), fileName: "komoot.gpx")
        #expect(ride.name == "Meine Tour")
        #expect(ride.sourceFile?.fileName == "komoot.gpx")
        #expect(ride.sourceFormat == "gpx")
        #expect(ride.attachedSourceFormat == nil)
    }

    // MARK: - What is not the same ride

    @Test("Another tour is a new ride")
    func otherTour() throws {
        try importFIT()
        let result = importGPX(try Edit.text("pair-tour2-bosch-flow"), as: "tour2.gpx")
        guard case .imported = result.outcome else {
            Issue.record("Expected import, got \(result.outcome)")
            return
        }
        #expect(try rides().count == 2)
    }

    @Test("Same start, another route: a new ride")
    func sameStartOtherRoute() throws {
        try importFIT()
        let result = importGPX(Edit.shifted(try Edit.text("pair-tour1-bosch-flow"), by: 0.01), as: "elsewhere.gpx")
        guard case .imported = result.outcome else {
            Issue.record("Expected import, got \(result.outcome)")
            return
        }
        #expect(try rides().count == 2)
    }

    @Test("A recording that stopped early is another file, not a duplicate")
    func shortRecording() throws {
        try importFIT()
        let all = try Edit.text("pair-tour1-bosch-flow")
        let result = importGPX(Edit.firstPoints(all, 2400), as: "short.gpx")   // about 84 % of the track
        guard case .imported = result.outcome else {
            Issue.record("Expected import, got \(result.outcome)")
            return
        }
        #expect(try rides().count == 2)
    }

    @Test("A few metres of error in the route are still the same ride")
    func tolerances() throws {
        try importFIT()
        let nearby = Edit.shifted(try Edit.text("pair-tour1-bosch-flow"), by: 0.00006)   // about 7 m
        guard case .attached = importGPX(nearby, as: "near.gpx").outcome else {
            Issue.record("Expected attached")
            return
        }
    }

    @Test("A friend's file for the same tour on another bike is a ride of its own (group ride)")
    func groupRide() throws {
        let mine = library.activeBike()
        let friends = library.makeBike(name: "Gravel")
        try importFIT(bike: mine)
        let result = importGPX(try Edit.text("pair-tour1-komoot"), as: "friend.gpx", bike: friends)
        guard case .imported(let id) = result.outcome else {
            Issue.record("Expected import, got \(result.outcome)")
            return
        }
        #expect(library.ride(withID: id)?.bike?.id == friends.id)
        #expect(try rides().count == 2)
        // On my bike another recording of it would have been attached.
        let sameBike = importGPX(try Edit.text("pair-tour1-bosch-flow"), as: "mine.gpx", bike: mine)
        guard case .attached = sameBike.outcome else {
            Issue.record("Expected attached, got \(sameBike.outcome)")
            return
        }
    }

    @Test("Rides in the trash and the sample ride do not match")
    func trashAndSample() throws {
        let result = try importFIT()
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Expected import")
            return
        }
        library.moveToTrash([ride])
        guard case .imported = importGPX(try Edit.text("pair-tour1-komoot"), as: "a.gpx").outcome else {
            Issue.record("Expected import")
            return
        }
        #expect(try rides().count == 2)
    }

    @Test("Two FIT files are not compared by route: only the Bosch ID and the exact start decide, as before")
    func fitAndFIT() throws {
        try importFIT()
        let other = try importFIT(as: "Beispielrunde-11111111-2222-3333-4444-555555555555.fit")
        // Same start and distance: the old duplicate rule (IMP-02) still applies.
        guard case .duplicate = other.outcome else {
            Issue.record("Expected duplicate, got \(other.outcome)")
            return
        }
    }

    // MARK: - For the dialogs

    @Test("\"As new ride\" keeps both: the file becomes a ride without the Bosch ID of the first")
    func asNewRide() throws {
        let first = try importFIT()
        guard case .imported(let firstID) = first.outcome else { return }
        let again = library.importFile(data: try GPXFixture.fitData("pair-tour1-bosch-flow"), fileName: "Beispielrunde-\(tour1UUID).fit",
                                       detectDuplicates: false)
        guard case .imported(let secondID) = again.outcome, let second = library.ride(withID: secondID) else {
            Issue.record("Expected import, got \(again.outcome)")
            return
        }
        #expect(secondID != firstID)
        #expect(second.sourceIdentifier == "")
        #expect(library.ride(withID: firstID)?.sourceIdentifier == tour1UUID)
        #expect(try rides().count == 2)
    }

    @Test("The log records an attached GPX as such, with the ride")
    func logsAttached() throws {
        try importFIT()
        let result = importGPX(try Edit.text("pair-tour1-komoot"), as: "komoot.gpx")
        let record = library.record(result, source: .manual)
        #expect(record.outcome == .attached)
        #expect(record.rideID != nil)
        #expect(record.outcome.needsAttention == false)
    }

    @Test("The facts for the dialog: ride in the library and file side by side")
    func facts() throws {
        let gpx = importGPX(try Edit.text("pair-tour1-komoot"), as: "komoot.gpx")
        guard case .imported(let id) = gpx.outcome, let ride = library.ride(withID: id) else { return }
        let existing = DuplicateFacts(ride: ride)
        #expect(existing.source == .gpx)
        #expect(existing.estimated)
        #expect(existing.averagePower == nil)
        #expect(existing.pointCount > 2500)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wattspur-facts-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Beispielrunde-\(tour1UUID).fit")
        try GPXFixture.fitData("pair-tour1-bosch-flow").write(to: url)
        let incoming = try #require(library.facts(ofFileAt: url))
        #expect(incoming.source == .fit)
        #expect(incoming.estimated == false)
        #expect(incoming.averagePower == 135)
        #expect(incoming.ascent == 166)
        #expect(abs(incoming.startDate.timeIntervalSince(existing.startDate)) < 10)
        #expect(library.facts(ofFileAt: dir.appendingPathComponent("missing.fit")) == nil)
    }

    // MARK: - Keeping the sensor values

    @Test("Re-parsing a Bosch ride with an attached GPX keeps the heart rate")
    func reparseKeepsSensors() throws {
        try importFIT()
        importGPX(Edit.addSensors(try Edit.text("pair-tour1-komoot")), as: "a.gpx")
        let ride = try #require(try rides().first)
        let before = ride.samples.filter { $0.heartRate != nil }.count
        ride.parserVersion = 1
        #expect(library.reparseOutdatedRides() == 1)
        #expect(ride.parserVersion == FITRideImporter.parserVersion)
        #expect(ride.samples.filter { $0.heartRate != nil }.count == before)
        #expect(before > 2000)
    }

    @Test("Updating a Bosch ride from a newer export keeps the attached heart rate")
    func fitUpdateKeepsSensors() throws {
        try importFIT()
        importGPX(Edit.addSensors(try Edit.text("pair-tour1-komoot")), as: "a.gpx")
        let ride = try #require(try rides().first)
        try library.update(ride, with: try GPXFixture.fitData("pair-tour1-bosch-flow"), fileName: "Beispielrunde-\(tour1UUID).fit")
        #expect(ride.attachedSourceName == "a.gpx")
        #expect(ride.samples.filter { $0.heartRate != nil }.count > 2000)
    }
}

@Suite("Route and path comparison")
struct RouteMatchTests {
    /// A winding route of about 4 km.
    private func route(offsetNorth: Double = 0, points: Int = 400, noise: Double = 0) -> OverviewRoute {
        var seed: UInt64 = 7
        func jitter() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return (Double(seed >> 33) / Double(1 << 31) - 0.5) * 2 * noise / 111_000
        }
        let line = (0..<points).map { i -> RoutePoint in
            let t = Double(i) / Double(points - 1)
            return RoutePoint(latitude: 50 + t * 0.03 + 0.003 * sin(t * 12) + offsetNorth / 111_000 + jitter(),
                              longitude: 9 + t * 0.02 + 0.002 * cos(t * 9) + jitter())
        }
        return OverviewRoute(segments: [line])
    }

    @Test("The same route matches itself, also driven the other way and with a few metres of noise")
    func same() {
        let a = route()
        #expect(RouteMatch.matches(a, a))
        #expect(RouteMatch.matches(a, OverviewRoute(segments: [a.segments[0].reversed()])))
        #expect(RouteMatch.matches(a, route(noise: 8)))
        let d = RouteMatch.distances(a, a)
        #expect((d?.percentile95 ?? 1) < 1)
    }

    @Test("Another route, a route 150 m to the side and one that stops early do not match")
    func different() {
        let a = route()
        #expect(!RouteMatch.matches(a, route(offsetNorth: 150)))
        let stopped = OverviewRoute(segments: [Array(a.segments[0].prefix(Int(Double(a.segments[0].count) * 0.85)))])
        #expect(!RouteMatch.matches(a, stopped))
        let other = OverviewRoute(segments: [a.segments[0].map { RoutePoint(latitude: $0.latitude + 0.02, longitude: $0.longitude) }])
        #expect(!RouteMatch.matches(a, other))
        #expect(!RouteMatch.matches(a, OverviewRoute(segments: [])))
        #expect(RouteMatch.distances(OverviewRoute(segments: []), a) == nil)
    }

    @Test("The GPS path leaves out pauses, jumps and the seams of merged rides")
    func gpsPath() {
        func sample(_ t: Double, _ north: Double) -> RideSample {
            RideSample(time: t, latitude: 50 + north / 111_195, longitude: 9)
        }
        let samples = [sample(0, 0), sample(1, 5), sample(2, 10), sample(100, 500),   // pause: not counted
                       sample(101, 505), sample(102, 50_000), sample(103, 515),      // jump: not counted
                       sample(103, 520)]                                             // same time (seam): not counted
        #expect(abs(GPSPath.length(of: samples) - 15) < 0.5)
        #expect(GPSPath.length(of: []) == 0)
    }
}

@MainActor
@Suite("Watched folder with FIT and GPX")
struct GPXFolderImportTests {
    let container: ModelContainer
    let library: RideLibrary
    let folder: URL

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("wattspur-gpx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private var watcher: FolderImport {
        FolderImport(library: library, folder: folder, importedFolderName: "Importiert", failedFolderName: "Fehlerhaft")
    }

    private func put(_ data: Data, _ name: String) throws {
        try data.write(to: folder.appendingPathComponent(name))
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path)
    }

    @Test("A GPX file is imported for the active bike, like a FIT")
    func importsGPX() throws {
        try put(GPXFixture.data("strava-style-power-hr-cad"), "run.gpx")
        let summary = watcher.run()
        #expect(summary.imported == 1)
        #expect(exists("Importiert/run.gpx"))
        let ride = try #require(library.ride(withID: summary.importedRideIDs[0]))
        #expect(ride.source == .gpx)
        #expect(ride.bike?.id == library.activeBike().id)
    }

    @Test("A GPX next to a Bosch ride is attached, a Bosch FIT for a GPX ride updates it, nobody is asked")
    func attachesAndUpdates() throws {
        // FIT first, GPX second.
        try put(GPXFixture.fitData("pair-tour1-bosch-flow"), "Beispielrunde-\(tour1UUID).fit")
        #expect(watcher.run().imported == 1)
        try put(GPXFixture.data("pair-tour1-komoot"), "komoot.gpx")
        let second = watcher.run()
        #expect(second.attached == 1)
        #expect(second.imported == 0)
        #expect(exists("Importiert/komoot.gpx"))
        #expect(try container.mainContext.fetch(FetchDescriptor<Ride>()).count == 1)

        // A new library: GPX first, FIT second.
        let other = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let lib2 = RideLibrary(context: other.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
        let folder2 = FileManager.default.temporaryDirectory.appendingPathComponent("wattspur-gpx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder2, withIntermediateDirectories: true)
        let watcher2 = FolderImport(library: lib2, folder: folder2, importedFolderName: "Importiert", failedFolderName: "Fehlerhaft")
        try GPXFixture.data("pair-tour1-bosch-flow").write(to: folder2.appendingPathComponent("tour.gpx"))
        let first = watcher2.run()
        let ride = try #require(lib2.ride(withID: first.importedRideIDs[0]))
        lib2.rename(ride, to: "Meine Tour")
        try GPXFixture.fitData("pair-tour1-bosch-flow").write(to: folder2.appendingPathComponent("Beispielrunde-\(tour1UUID).fit"))
        let summary = watcher2.run()
        #expect(summary.updated == 1)
        #expect(summary.imported == 0)
        #expect(summary.failed == 0)
        #expect(ride.source == .fit)
        #expect(ride.name == "Meine Tour")
        #expect(ride.timerTime == 2916)
        #expect(FileManager.default.fileExists(atPath: folder2.appendingPathComponent("Importiert/Beispielrunde-\(tour1UUID).fit").path))
        let log = lib2.importRecords()
        #expect(log.contains { $0.outcome == .updated && $0.fileName.hasSuffix(".fit") })
    }
}
