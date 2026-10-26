import Foundation
import SwiftData

/// Saved routes: making one from a ride, naming, changing and dissolving it (B-121, ROUTE-07).
/// The rides of a route are not stored; see `RouteGroup` and `RouteGrouping`.
struct RouteGroupService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    /// What is needed to make a route again, e.g. when a dissolved one comes back with ⌘Z.
    private struct Snapshot {
        var id: UUID
        var name: String
        var createdAt: Date
        var threshold: Double
        var includeReverse: Bool
        var routeData: Data?
        var referenceRideID: UUID?

        init(_ group: RouteGroup) {
            id = group.id
            name = group.name
            createdAt = group.createdAt
            threshold = group.threshold
            includeReverse = group.includeReverse
            routeData = group.referenceRouteData
            referenceRideID = group.referenceRideID
        }

        func makeGroup() -> RouteGroup {
            let group = RouteGroup(name: name, threshold: threshold, includeReverse: includeReverse,
                                   referenceRoute: OverviewRoute(segments: []), referenceRideID: referenceRideID)
            group.id = id
            group.createdAt = createdAt
            group.referenceRouteData = routeData
            return group
        }
    }

    func groups() -> [RouteGroup] {
        RouteGroup.sorted((try? context.fetch(FetchDescriptor<RouteGroup>())) ?? [])
    }

    func group(withID id: UUID) -> RouteGroup? {
        var descriptor = FetchDescriptor<RouteGroup>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Saves the route of `ride` as a route with `name`. `nil` for an empty name, or a ride whose
    /// route is missing, still being prepared or too short to compare.
    @discardableResult
    func create(from ride: Ride, name: String, threshold: Double = RouteSimilarity.defaultThreshold,
                includeReverse: Bool = false) -> RouteGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let route = ride.overviewRoute, RouteSignature(route) != nil else { return nil }
        let group = RouteGroup(name: trimmed, threshold: RouteSimilarity.clampedThreshold(threshold),
                               includeReverse: includeReverse, referenceRoute: route, referenceRideID: ride.id)
        context.insert(group)
        try? context.save()
        let id = group.id
        registerUndo { $0.remove(id) }
        return group
    }

    func rename(_ group: RouteGroup, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != group.name else { return }
        let old = group.name
        group.name = trimmed
        try? context.save()
        registerUndo { $0.rename(group, to: old) }
    }

    /// Changes how loosely rides must match. Which rides belong to the route changes with it.
    func update(_ group: RouteGroup, threshold: Double, includeReverse: Bool) {
        let newThreshold = RouteSimilarity.clampedThreshold(threshold)
        guard newThreshold != group.threshold || includeReverse != group.includeReverse else { return }
        let oldThreshold = group.threshold, oldReverse = group.includeReverse
        group.threshold = newThreshold
        group.includeReverse = includeReverse
        try? context.save()
        registerUndo { $0.update(group, threshold: oldThreshold, includeReverse: oldReverse) }
    }

    /// Dissolves the route. The rides stay as they are; they only no longer belong to it.
    func dissolve(_ group: RouteGroup) {
        let snapshot = Snapshot(group)
        context.delete(group)
        try? context.save()
        registerUndo { $0.restore(snapshot) }
    }

    private func remove(_ id: UUID) {
        guard let group = group(withID: id) else { return }
        dissolve(group)
    }

    private func restore(_ snapshot: Snapshot) {
        guard group(withID: snapshot.id) == nil else { return }
        context.insert(snapshot.makeGroup())
        try? context.save()
        let id = snapshot.id
        registerUndo { $0.remove(id) }
    }
}
