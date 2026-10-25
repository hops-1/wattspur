import Foundation
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit
@testable import WattspurCore

@MainActor
@Suite("Library maintenance")
struct LibraryMaintenanceTests {
    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    @Test("After launch the old trash is emptied and outdated rides are read again, once")
    func catchesUpAfterLaunch() async throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        let name = "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit"
        guard case .imported(let keptID) = library.importFile(data: data, fileName: name).outcome,
              case .imported(let trashedID) = library.importFile(data: data, fileName: name, detectDuplicates: false).outcome,
              let kept = library.ride(withID: keptID), let trashed = library.ride(withID: trashedID) else {
            Issue.record("Expected two rides"); return
        }
        kept.parserVersion = 0
        trashed.deletedAt = .now.addingTimeInterval(-40 * 86_400)
        library.save()

        let maintenance = LibraryMaintenance()
        await maintenance.run(library: library)

        #expect(library.ride(withID: trashedID) == nil)
        #expect(kept.parserVersion == FITRideImporter.parserVersion)
        #expect(!kept.needsOverviewRoute)

        // A second call, e.g. from another window, does nothing.
        kept.parserVersion = 0
        await maintenance.run(library: library)
        #expect(kept.parserVersion == 0)
    }
}
