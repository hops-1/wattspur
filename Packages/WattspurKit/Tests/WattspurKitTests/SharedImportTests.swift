import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// “Share to Wattspur” (B-301): what the share extension leaves goes into the folder “Import”, and a
/// planned route gets its own line in the summary. Invented files only.
@MainActor
@Suite("Shared imports")
final class SharedImportTests {
    let container: ModelContainer
    let library: RideLibrary
    let flow = ImportFlow()
    let folder: URL

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
        _ = library.prepareBikes()
        folder = FileManager.default.temporaryDirectory.appending(path: "SharedImportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

    private static let plannedTour = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="https://www.komoot.de" xmlns="http://www.topografix.com/GPX/1/1"><trk><trkseg>
    <trkpt lat="50.0" lon="9.0"><ele>300</ele></trkpt><trkpt lat="50.001" lon="9.0"><ele>301</ele></trkpt>
    </trkseg></trk></gpx>
    """.utf8)

    private func write(_ name: String, _ data: Data, in parent: URL) throws -> URL {
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let url = parent.appending(path: name)
        try data.write(to: url)
        return url
    }

    @Test("A planned route is counted apart from broken files, in the summary and the report")
    func plannedRouteInSummary() async throws {
        flow.stepsThroughFiles = true
        let planned = try write("Runde am See.gpx", Self.plannedTour, in: folder.appending(path: "a"))
        let broken = try write("Kaputt.gpx", Data("<gpx><trk>".utf8), in: folder.appending(path: "b"))
        flow.start([planned, broken], library: library) { _, _ in }
        while flow.progress != nil { await Task.yield() }
        let summary = flow.takeSummary()
        #expect(summary.plannedRouteFileNames == ["Runde am See.gpx"])
        #expect(summary.failedFileNames == ["Kaputt.gpx"])
        #expect(!summary.isEmpty)

        var onlyPlanned = ImportFlow.Summary()
        onlyPlanned.plannedRouteFileNames = ["x.gpx"]
        #expect(!onlyPlanned.isEmpty)

        let report = ImportReport(entries: [planned, broken].map { ImportReport.Entry(url: $0, result: library.importFile(at: $0)) })
        #expect(report.plannedRouteFileNames == ["Runde am See.gpx"])
        #expect(report.unreadableFileNames == ["Kaputt.gpx"])
    }

    @Test("Shared files move from their folders into the inbox; hidden folders still being written wait")
    func collectShared() throws {
        let inbox = ImportInbox(base: folder.appending(path: "Documents"))
        let shared = folder.appending(path: "Shared")
        _ = try write("Tour.gpx", Data("<gpx/>".utf8), in: shared.appending(path: UUID().uuidString))
        _ = try write("Tour.gpx", Data("<gpx/>".utf8), in: shared.appending(path: UUID().uuidString))
        let mixed = shared.appending(path: UUID().uuidString)
        _ = try write("Fahrt.FIT", Data([1, 2, 3]), in: mixed)
        _ = try write("Notiz.txt", Data("hallo".utf8), in: mixed)
        let writing = shared.appending(path: ".writing-\(UUID().uuidString)")
        _ = try write("Halb.gpx", Data("<gpx".utf8), in: writing)

        #expect(inbox.collectShared(from: shared) == 3)
        #expect(inbox.waitingFiles().map(\.lastPathComponent) == ["Fahrt.FIT", "Tour 2.gpx", "Tour.gpx"])
        let left = try FileManager.default.contentsOfDirectory(atPath: shared.path(percentEncoded: false)).sorted()
        // The empty folders are gone; the one with the note and the hidden one stay.
        #expect(left == [writing.lastPathComponent, mixed.lastPathComponent].sorted())
        #expect(inbox.collectShared(from: folder.appending(path: "nothing")) == 0)
    }
}
