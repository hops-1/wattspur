import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

/// Many files at once on the iPhone (B-300): the file picker and the folder “Import”. Invented
/// rides only, written with `GPXWriter`; the Bosch pair is the anonymised fixture of B-273.
@MainActor
@Suite("Import of many files and the folder Import")
final class ImportManyFilesTests {
    let container: ModelContainer
    let library: RideLibrary
    let flow = ImportFlow()
    let folder: URL

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext, importers: [FITRideImporter(), GPXRideImporter()])
        _ = library.prepareBikes()
        folder = FileManager.default.temporaryDirectory.appending(path: "ImportManyFilesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // The temporary folder goes with the suite (R-10).
    deinit { try? FileManager.default.removeItem(at: folder) }

    /// An invented ride of two minutes, starting `start` seconds after 2027, in a folder of its own.
    private func ride(_ name: String, start: TimeInterval) throws -> URL {
        let begin = 1_798_761_600 + start
        var recording = RideRecording(startDate: Date(timeIntervalSince1970: begin))
        for second in 0...120 {
            recording.add(RideRecording.Fix(date: Date(timeIntervalSince1970: begin + Double(second)),
                                            latitude: 49.9 + Double(second) * 6 / 111_195, longitude: 8.7,
                                            altitude: 200, horizontalAccuracy: 5, speed: 6))
        }
        let gpx = GPXWriter.document(name: name, segments: recording.gpxSegments, description: nil,
                                     creator: "Test", bikeID: nil)
        return try write(name + ".gpx", gpx)
    }

    private func write(_ name: String, _ data: Data) throws -> URL {
        let sub = folder.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let url = sub.appending(path: name)
        try data.write(to: url)
        return url
    }

    /// Waits until the stepwise import has finished its files.
    private func settle() async {
        while flow.progress != nil { await Task.yield() }
    }

    @Test("Many files go one by one with a progress, and the summary counts new, completed, duplicate and broken")
    func summary() async throws {
        flow.stepsThroughFiles = true
        let first = try ride("Morgens", start: 0)
        let second = try ride("Abends", start: 40_000)
        let broken = try write("Kaputt.gpx", Data("<gpx><trk>".utf8))
        let note = try write("Notiz.txt", Data("hallo".utf8))
        var recorded = 0
        flow.start([first, second, broken, note], library: library) { _, _ in recorded += 1 }
        #expect(flow.progress == ImportFlow.Progress(done: 0, total: 4))
        #expect(flow.isBusy)
        await settle()
        #expect(recorded == 4)
        #expect(!flow.isBusy)
        var summary = flow.takeSummary()
        #expect(summary.newRides == 2)
        #expect(summary.failedFileNames == ["Kaputt.gpx"])
        #expect(summary.unsupportedFileNames == ["Notiz.txt"])
        #expect(flow.summary.isEmpty)

        // The same file again is a duplicate; left out, it counts as one.
        flow.start([try ride("Morgens", start: 0)], library: library) { _, _ in }
        await settle()
        if flow.plainDuplicates != nil { flow.plainDuplicates = nil } else if !flow.comparisons.isEmpty { flow.skip() }
        summary = flow.takeSummary()
        #expect(summary.duplicates == 1)
        #expect(summary.newRides == 0)
    }

    @Test("A Bosch FIT completes a GPS ride that is there (B-273), and counts as completed")
    func completes() async throws {
        flow.stepsThroughFiles = true
        flow.start([try write("Beispielrunde.gpx", GPXFixture.data("pair-tour1-bosch-flow"))], library: library) { _, _ in }
        await settle()
        _ = flow.takeSummary()
        flow.start([try write("Beispielrunde.fit", GPXFixture.fitData("pair-tour1-bosch-flow"))], library: library) { _, _ in }
        await settle()
        let comparison = try #require(flow.comparisons.first)
        #expect(comparison.kind == .fitForGPX)
        flow.update(comparison, library: library)
        #expect(!flow.isBusy)
        let summary = flow.takeSummary()
        #expect(summary.completed == 1)
        #expect(summary.newRides == 0)
        #expect(try container.mainContext.fetch(FetchDescriptor<Ride>()).count == 1)
    }

    @Test("A second batch during a running one waits and then runs")
    func secondBatchWaits() async throws {
        flow.stepsThroughFiles = true
        flow.start([try ride("Eins", start: 0), try ride("Zwei", start: 10_000)], library: library) { _, _ in }
        flow.start([try ride("Drei", start: 20_000)], library: library) { _, _ in }
        #expect(flow.isBusy)
        while flow.isBusy { await Task.yield() }
        #expect(flow.takeSummary().newRides == 3)
    }

    @Test("The folder Import: FIT and GPX wait there, other files stay, read files move on without overwriting")
    func inbox() throws {
        let inbox = ImportInbox(base: folder)
        #expect(inbox.waitingFiles().isEmpty)
        #expect(FileManager.default.fileExists(atPath: inbox.inbox.path(percentEncoded: false)))

        for name in ["b.gpx", "a.FIT", "liesmich.txt", ".versteckt.gpx"] {
            try Data("x".utf8).write(to: inbox.inbox.appending(path: name))
        }
        try FileManager.default.createDirectory(at: inbox.inbox.appending(path: "ordner.gpx"), withIntermediateDirectories: true)
        let waiting = inbox.waitingFiles()
        #expect(waiting.map(\.lastPathComponent) == ["a.FIT", "b.gpx"])

        let moved = try inbox.moveAway(waiting[1], failed: false)
        #expect(moved.deletingLastPathComponent().lastPathComponent == ImportInbox.importedName)
        try Data("y".utf8).write(to: inbox.inbox.appending(path: "b.gpx"))
        let second = try inbox.moveAway(inbox.inbox.appending(path: "b.gpx"), failed: false)
        #expect(second.lastPathComponent == "b 2.gpx")
        let failed = try inbox.moveAway(waiting[0], failed: true)
        #expect(failed.deletingLastPathComponent().lastPathComponent == ImportInbox.failedName)
        #expect(inbox.waitingFiles().isEmpty)
        #expect(FileManager.default.fileExists(atPath: inbox.inbox.appending(path: "liesmich.txt").path(percentEncoded: false)))
    }
}
