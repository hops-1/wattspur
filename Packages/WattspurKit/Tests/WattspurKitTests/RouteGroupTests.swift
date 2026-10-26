import Foundation
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit
@testable import WattspurCore

/// Saved routes in the library (B-121): the model, the service, undo and the way old libraries open.
@MainActor
@Suite("Route groups")
struct RouteGroupTests {
    let container: ModelContainer
    let undo = UndoManager()
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        undo.groupsByEvent = false
        library = RideLibrary(context: container.mainContext, undoManager: undo)
    }

    private func importRide(_ index: Int = 0) throws -> Ride {
        let data = try Fixture.data("reinheim-rundfahrt")
        let name = "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c\(String(format: "%04d", index)).fit"
        guard case .imported(let id) = library.importFile(data: data, fileName: name, detectDuplicates: false).outcome,
              let ride = library.ride(withID: id) else {
            throw RideMissing()
        }
        ride.setOverviewRoute(OverviewRoute(samples: ride.samples))
        return ride
    }

    private struct RideMissing: Error {}

    /// One user action, as the app's event loop makes it.
    @discardableResult
    private func step<T>(_ body: () -> T) -> T {
        undo.beginUndoGrouping()
        defer { undo.endUndoGrouping() }
        return body()
    }

    @Test("A route is made from a ride and keeps its own copy of the route")
    func create() throws {
        let ride = try importRide()
        var group: RouteGroup?
        step { group = library.addRouteGroup(from: ride, name: "  Rund um Reinheim ", threshold: 0.85, includeReverse: true) }
        let made = try #require(group)
        #expect(made.name == "Rund um Reinheim")
        #expect(made.threshold == 0.85)
        #expect(made.includeReverse)
        #expect(made.referenceRideID == ride.id)
        #expect(made.referenceRoute == ride.overviewRoute)
        #expect(library.routeGroups().map(\.id) == [made.id])
    }

    @Test("No empty name, no ride without a usable route, and the threshold stays in range")
    func refusals() throws {
        let ride = try importRide()
        #expect(library.addRouteGroup(from: ride, name: "   ") == nil)

        let noRoute = try importRide(1)
        noRoute.setOverviewRoute(OverviewRoute(segments: []))
        #expect(library.addRouteGroup(from: noRoute, name: "X") == nil)

        let outdated = try importRide(2)
        outdated.overviewRouteVersion = 0 // still being prepared
        #expect(library.addRouteGroup(from: outdated, name: "X") == nil)

        let loose = try #require(step { library.addRouteGroup(from: ride, name: "A", threshold: 0.2) })
        #expect(loose.threshold == RouteSimilarity.thresholdRange.lowerBound)
        let strict = try #require(step { library.addRouteGroup(from: ride, name: "B", threshold: .nan) })
        #expect(strict.threshold == RouteSimilarity.defaultThreshold)
        #expect(library.routeGroups().count == 2)
    }

    @Test("Saved routes are listed by name, not by the order they were made in")
    func sortedByName() throws {
        let ride = try importRide()
        for name in ["Zeiss über Rohrbach", "bäckerei", "Route 10", "Route 9", "Arbeit"] {
            step { _ = library.addRouteGroup(from: ride, name: name) }
        }
        #expect(library.routeGroups().map(\.name) == ["Arbeit", "bäckerei", "Route 9", "Route 10", "Zeiss über Rohrbach"])

        // The same name twice: the older route first.
        step { _ = library.addRouteGroup(from: ride, name: "Arbeit") }
        let names = library.routeGroups().filter { $0.name == "Arbeit" }
        #expect(names.count == 2 && names[0].createdAt <= names[1].createdAt)
    }

    @Test("Renaming and changing the threshold can be undone and redone")
    func renameAndUpdate() throws {
        let ride = try importRide()
        var made: RouteGroup!
        step { made = library.addRouteGroup(from: ride, name: "Pendeln") }
        step { library.rename(made, to: "Pendeln Arbeit") }
        library.rename(made, to: "   ") // ignored, registers nothing
        step { library.update(made, threshold: 0.95, includeReverse: true) }
        library.update(made, threshold: 0.95, includeReverse: true) // no change, registers nothing
        #expect(made.name == "Pendeln Arbeit")
        #expect(made.threshold == 0.95 && made.includeReverse)

        undo.undo()
        #expect(made.threshold == RouteSimilarity.defaultThreshold && !made.includeReverse)
        undo.undo()
        #expect(made.name == "Pendeln")
        undo.redo()
        #expect(made.name == "Pendeln Arbeit")
    }

    @Test("Dissolving leaves the rides and comes back with undo")
    func dissolve() throws {
        let ride = try importRide()
        var made: RouteGroup!
        step { made = library.addRouteGroup(from: ride, name: "Pendeln", threshold: 0.9, includeReverse: true) }
        let id = made.id
        let created = made.createdAt
        step { library.dissolve(made) }
        #expect(library.routeGroups().isEmpty)
        #expect(library.ride(withID: ride.id) != nil)

        undo.undo()
        let back = try #require(library.routeGroups().first)
        #expect(back.id == id)
        #expect(back.name == "Pendeln")
        #expect(back.createdAt == created)
        #expect(back.threshold == 0.9 && back.includeReverse)
        #expect(back.referenceRoute == ride.overviewRoute)

        undo.redo()
        #expect(library.routeGroups().isEmpty)
        undo.undo()
        #expect(library.routeGroups().count == 1)
    }

    @Test("Undoing the creation removes the route")
    func undoCreate() throws {
        let ride = try importRide()
        step { _ = library.addRouteGroup(from: ride, name: "Pendeln") }
        undo.undo()
        #expect(library.routeGroups().isEmpty)
        undo.redo()
        #expect(library.routeGroups().count == 1)
    }

    @Test("The rides of a route are computed: a new ride joins, a deleted reference ride changes nothing")
    func membersAreComputed() throws {
        let first = try importRide(0)
        let group = try #require(step { library.addRouteGroup(from: first, name: "Runde") })

        func members() throws -> Set<UUID> {
            let rides = try container.mainContext.fetch(FetchDescriptor<Ride>())
            let index = RouteIndex(rides)
            return Set(RouteGrouping.memberships(of: [group.spec], in: index).keys)
        }
        #expect(try members() == [first.id])

        let second = try importRide(1)
        #expect(try members() == [first.id, second.id])

        // The reference ride goes (trash): the route and the other ride stay.
        step { library.moveToTrash(first) }
        #expect(try members() == [second.id])
        #expect(group.referenceRoute == second.overviewRoute)
    }

    @Test("Routes are not touched by merging or trashing rides")
    func ridesDoNotOwnGroups() throws {
        let ride = try importRide()
        let group = try #require(step { library.addRouteGroup(from: ride, name: "Runde") })
        step { library.moveToTrash(ride) }
        #expect(library.routeGroups().map(\.id) == [group.id])
    }
}

/// Migration 2 adds the table of saved routes. A library written before it must open unchanged.
@MainActor
@Suite("Route groups migration")
struct RouteGroupMigrationTests {
    @Test("A library file from before the saved routes opens with the new schema and keeps its rides")
    func oldLibraryOpens() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")

        // The models of 1.7.0: everything but `RouteGroup`.
        let oldModels: [any PersistentModel.Type] = WattspurSchema.models.filter { $0 != RouteGroup.self }
        #expect(oldModels.count == WattspurSchema.models.count - 1)
        var rideID: UUID?
        do {
            let old = try ModelContainer(for: Schema(oldModels), configurations: ModelConfiguration(url: url))
            let library = RideLibrary(context: old.mainContext)
            let data = try Fixture.data("reinheim-rundfahrt")
            if case .imported(let id) = library.importFile(data: data, fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c0001.fit").outcome {
                rideID = id
            }
            library.save()
        }
        let id = try #require(rideID)

        let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: url))
        let library = RideLibrary(context: container.mainContext)
        let ride = try #require(library.ride(withID: id))
        #expect(library.routeGroups().isEmpty)

        // And the new table works.
        ride.setOverviewRoute(OverviewRoute(samples: ride.samples))
        #expect(library.addRouteGroup(from: ride, name: "Runde") != nil)
        #expect(library.routeGroups().count == 1)
    }
}
