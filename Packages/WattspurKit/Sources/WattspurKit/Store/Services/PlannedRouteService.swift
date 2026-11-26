import Foundation
import SwiftData

/// Planned tours (B-372): saving one from a GPX file, renaming and the trash, like rides.
struct PlannedRouteService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    /// Tours, newest first; with `includingTrash` also those in the trash.
    func routes(includingTrash: Bool = false) -> [PlannedRoute] {
        let descriptor = includingTrash
            ? FetchDescriptor<PlannedRoute>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            : FetchDescriptor<PlannedRoute>(predicate: PlannedRoute.listedPredicate,
                                            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return fetch(descriptor)
    }

    func route(withID id: UUID) -> PlannedRoute? {
        var descriptor = FetchDescriptor<PlannedRoute>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Saves the tour in a GPX file. The same tour again gives `plannedTourDuplicate` and comes back
    /// from the trash if it was there (as rides do, R-44).
    func importTour(data: Data, fileName: String, now: Date = .now) -> ImportResult {
        let tour: PlannedTour
        do {
            tour = try PlannedTourReader().read(data)
        } catch {
            return ImportResult(fileName: fileName, outcome: .failed(.gpx(error)))
        }
        let key = tour.contentKey
        let existing: PlannedRoute?
        do {
            var descriptor = FetchDescriptor<PlannedRoute>(predicate: #Predicate { $0.contentKey == key },
                                                           sortBy: [SortDescriptor(\.createdAt)])
            descriptor.fetchLimit = 1
            existing = try fetchOrThrow(descriptor).first
        } catch {
            // As with rides (B-354): a library that cannot be read must not get the tour twice.
            return ImportResult(fileName: fileName, outcome: .failed(.libraryUnreadable(String(describing: error))))
        }
        if let existing {
            var result = ImportResult(fileName: fileName, outcome: .plannedTourDuplicate(existingRouteID: existing.id))
            if existing.deletedAt != nil {
                setDeletedAt([(existing, nil)])
                result.restoredFromTrash = true
            }
            return result
        }

        let suggested = tour.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let route = PlannedRoute(name: suggested.isEmpty ? ImportService.parseFileName(fileName).title : suggested, tour: tour)
        route.createdAt = now
        route.sourceFileName = fileName
        route.sourceData = data
        context.insert(route)
        LibrarySave.save(context)
        return ImportResult(fileName: fileName, outcome: .plannedTour(routeID: route.id))
    }

    func rename(_ route: PlannedRoute, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != route.name else { return }
        let old = route.name
        route.name = trimmed
        LibrarySave.save(context)
        let id = route.id
        registerUndo { service in
            guard let route = service.route(withID: id) else { return }
            service.rename(route, to: old)
        }
    }

    func moveToTrash(_ routes: [PlannedRoute], at date: Date = .now) {
        setDeletedAt(routes.map { ($0, date) })
    }

    func restore(_ routes: [PlannedRoute]) {
        setDeletedAt(routes.map { ($0, nil) })
    }

    /// Changes the trash state; undo puts back each tour's previous state.
    private func setDeletedAt(_ changes: [(route: PlannedRoute, date: Date?)]) {
        let previous = changes.map { (id: $0.route.id, date: $0.route.deletedAt) }
        for change in changes { change.route.deletedAt = change.date }
        LibrarySave.save(context)
        registerUndo { service in
            let routes = previous.compactMap { change in service.route(withID: change.id).map { (route: $0, date: change.date) } }
            guard !routes.isEmpty else { return }
            service.setDeletedAt(routes)
        }
    }

    /// Deletes tours that are in the trash longer than `days` for good, like rides (LIST-08).
    func purgeTrash(olderThan days: Int = 30, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        let descriptor = FetchDescriptor<PlannedRoute>(predicate: #Predicate { $0.deletedAt != nil })
        var removed = false
        for route in fetch(descriptor) where (route.deletedAt ?? now) <= cutoff {
            context.delete(route)
            removed = true
        }
        if removed { LibrarySave.save(context) }
    }
}
