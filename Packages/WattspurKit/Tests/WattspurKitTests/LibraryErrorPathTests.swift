import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

/// What happens when the library cannot be read or written: a failed read is reported and never
/// taken for "nothing found" by the import (B-354, S-36), a failed save is logged and posted (B-359, S-31).
@MainActor
@Suite("Library error paths", .serialized)
struct LibraryErrorPathTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        LibraryFetch.reset()
        LibrarySave.reset()
    }

    private var rideCount: Int { (try? container.mainContext.fetchCount(FetchDescriptor<Ride>())) ?? -1 }

    @Test("A failed read during an import adds no second ride and is in the diagnostic report")
    func failedReadStopsImport() throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        let first = library.importFile(data: data, fileName: "A.fit")
        guard case .imported = first.outcome else { Issue.record("first import: \(first.outcome)"); return }
        #expect(rideCount == 1)

        LibraryFetch.failReads(of: Ride.self, in: container.mainContext)
        let second = library.importFile(data: data, fileName: "A.fit")
        guard case .failed(.libraryUnreadable) = second.outcome else {
            Issue.record("second import: \(second.outcome)"); return
        }
        let report = DiagnosticReport(appVersion: "1.6.6", build: "1", commit: "abc", rideCount: 1, trashedRideCount: 0,
                                      ridesByParserVersion: [:], importLog: [ImportLogEntry(result: second)],
                                      failedReads: LibraryFetch.failures)
        LibraryFetch.reset()
        #expect(rideCount == 1)
        #expect(report.text.contains("failed: libraryUnreadable"))
        #expect(report.text.contains("Failed reads of the library (since launch): Ride: "))
    }

    @Test("A failed read is counted by model type")
    func failedReadIsCounted() {
        LibraryFetch.failReads(of: Bike.self, in: container.mainContext)
        #expect(library.bikes(includingArchived: true).isEmpty)
        #expect((LibraryFetch.failures["Bike"] ?? 0) >= 1)
        #expect(LibraryFetch.failures["Ride"] == nil)
        LibraryFetch.reset()
    }

    @Test("Without a failure the report says there was none")
    func noFailure() {
        let report = DiagnosticReport(appVersion: "1", build: "1", commit: "x", rideCount: 0, trashedRideCount: 0,
                                      ridesByParserVersion: [:], importLog: [])
        #expect(report.text.contains("Failed reads of the library (since launch): –"))
    }

    @Test("A failed save is posted with its text and returns false")
    func failedSave() async {
        container.mainContext.insert(Ride(name: "Neu", startDate: .now))
        LibrarySave.failSaves(of: container.mainContext)
        var message: String?
        let observer = NotificationCenter.default.addObserver(forName: LibrarySave.failedNotification, object: nil,
                                                              queue: nil) { note in
            message = note.userInfo?["message"] as? String
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(!LibrarySave.save(container.mainContext))
        #expect(message == "The disk is full (test).")

        LibrarySave.reset()
        message = nil
        #expect(LibrarySave.save(container.mainContext))
        #expect(message == nil)
    }
}
