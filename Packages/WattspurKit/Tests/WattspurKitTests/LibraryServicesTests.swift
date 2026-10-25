import Foundation
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit
@testable import WattspurCore

/// The library hands its work to small services; these check the seams between them.
@MainActor
@Suite("Library services")
struct LibraryServicesTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test("The library for another window keeps the importers and the default bike name")
    func usingKeepsSettings() {
        let library = RideLibrary(context: container.mainContext, defaultBikeName: "My eBike")
        let other = library.using(UndoManager())
        #expect(other.defaultBikeName == "My eBike")
        #expect(other.importers.count == library.importers.count)
        #expect(other.context === library.context)
        #expect(other.undoManager != nil)
    }

    @Test("The bike service names the first bike after the library's default name")
    func firstBikeUsesTheName() {
        let library = RideLibrary(context: container.mainContext, defaultBikeName: "My eBike")
        #expect(library.activeBike().name == "My eBike")
    }

    @Test("Trash, bikes and the import log share one undo manager and one data store")
    func servicesShareUndoAndData() throws {
        let undo = UndoManager()
        undo.groupsByEvent = false
        let library = RideLibrary(context: container.mainContext, undoManager: undo)
        let data = try Fixture.data("reinheim-rundfahrt")
        let result = library.importFile(data: data, fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        library.record(result, source: .manual)
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Expected an imported ride"); return
        }

        undo.beginUndoGrouping()
        library.moveToTrash(ride)
        undo.endUndoGrouping()
        #expect(ride.deletedAt != nil)
        undo.undo()
        #expect(ride.deletedAt == nil)

        #expect(library.importRecords().count == 1)
        #expect(library.latestImportDate() != nil)
        #expect(ride.bike === library.activeBike())
    }
}
