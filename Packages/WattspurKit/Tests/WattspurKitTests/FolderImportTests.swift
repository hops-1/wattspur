import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@MainActor
@Suite("Watched folder and import log")
struct FolderImportTests {
    let container: ModelContainer
    let library: RideLibrary
    let fixture: Data
    let folder: URL
    let rideName = "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57"

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        fixture = try Fixture.data("reinheim-rundfahrt")
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("wattspur-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func write(_ data: Data, _ name: String, in dir: URL? = nil) throws {
        try data.write(to: (dir ?? folder).appendingPathComponent(name))
    }

    func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path)
    }

    var importer: FolderImport {
        FolderImport(library: library, folder: folder, importedFolderName: "Importiert", failedFolderName: "Fehlerhaft")
    }

    @Test("Imported files move to the imported folder, broken ones to the failed folder")
    func movesFiles() async throws {
        try write(fixture, "\(rideName).fit")
        try write(fixture.prefix(500), "broken.fit")
        let summary = await importer.run()

        #expect(summary.imported == 1)
        #expect(summary.failed == 1)
        #expect(exists("Importiert/\(rideName).fit"))
        #expect(exists("Fehlerhaft/broken.fit"))
        #expect(!exists("\(rideName).fit"))
        let log = library.importRecords()
        #expect(log.count == 2)
        #expect(log.contains { $0.outcome == .failed && $0.movedTo == "Fehlerhaft/broken.fit" && !$0.detail.isEmpty })
        #expect(log.allSatisfy { $0.source == .folder })
    }

    @Test("Unsupported files stay in place and are logged only once")
    func leavesUnsupportedFiles() async throws {
        try write(Data("<TrainingCenterDatabase/>".utf8), "tour.tcx")
        #expect(await importer.run().newlyUnsupported == 1)
        #expect(await importer.run().newlyUnsupported == 0)
        #expect(exists("tour.tcx"))
        #expect(library.importRecords().count == 1)
        #expect(library.importRecords().first?.outcome == .unsupported)
    }

    @Test("Duplicates are skipped, moved away and logged; name clashes get a number")
    func skipsDuplicates() async throws {
        try write(fixture, "\(rideName).fit")
        await importer.run()
        try write(fixture, "\(rideName).fit")
        let summary = await importer.run()

        #expect(summary.duplicates == 1)
        #expect(exists("Importiert/\(rideName) 2.fit"))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Ride>()) == 1)
        #expect(library.importRecords().first?.outcome == .duplicate)
    }

    @Test("Subfolders, hidden files and iCloud placeholders are not imported")
    func ignoresOtherEntries() async throws {
        let sub = folder.appendingPathComponent("Importiert")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try write(fixture, "old.fit", in: sub)
        try write(Data(), ".DS_Store")
        try write(Data(), ".Morning ride.fit.icloud")
        let summary = await importer.run()

        #expect(summary.imported == 0)
        #expect(summary.downloading == 1)
        #expect(library.importRecords().isEmpty)
        #expect(FolderImport.iCloudPlaceholderName(".Morning ride.fit.icloud") == "Morning ride.fit")
        #expect(FolderImport.iCloudPlaceholderName(".DS_Store") == nil)
    }

    @Test("Manual imports and updates are logged; old entries are trimmed")
    func logsManualImports() throws {
        let result = library.importFile(data: fixture, fileName: "\(rideName).fit")
        let old = library.record(result, source: .manual, date: Date(timeIntervalSince1970: 0))
        #expect(old.logEntry.outcome == "imported")
        guard case .imported(let id) = result.outcome else { Issue.record("not imported"); return }
        library.recordUpdate(of: id, fileName: "\(rideName).fit", source: .manual)

        #expect(library.importRecords().map(\.outcome) == [.updated, .imported])
        library.trimImportLog(olderThan: 90)
        #expect(library.importRecords().map(\.outcome) == [.updated])
        #expect(library.canImport(fileName: "x.FIT"))
        #expect(!library.canImport(fileName: "x.fit 2"))
    }
}
