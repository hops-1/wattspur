import Foundation
import SwiftData

/// Renaming, the trash and the sample ride (B-010 … B-015, LIST-07, LIST-08, ONB-02).
struct RideService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    func rename(_ ride: Ride, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ride.name else { return }
        let old = ride.name
        ride.name = trimmed
        LibrarySave.save(context)
        let id = ride.id
        registerUndo { service in
            guard let ride = service.ride(withID: id) else { return }
            service.rename(ride, to: old)
        }
    }

    /// Moves a ride to the trash (LIST-07). It stays restorable for 30 days.
    func moveToTrash(_ ride: Ride, at date: Date = .now) {
        moveToTrash([ride], at: date)
    }

    /// Moves several rides to the trash with one save, so one undo brings them all back.
    func moveToTrash(_ rides: [Ride], at date: Date = .now) {
        setDeletedAt(rides.map { ($0, date) })
    }

    func restore(_ ride: Ride) {
        restore([ride])
    }

    func restore(_ rides: [Ride]) {
        setDeletedAt(rides.map { ($0, nil) })
    }

    /// Changes the trash state; undo puts back each ride's previous state.
    private func setDeletedAt(_ changes: [(ride: Ride, date: Date?)]) {
        let previous = changes.map { (id: $0.ride.id, date: $0.ride.deletedAt) }
        for change in changes { change.ride.deletedAt = change.date }
        LibrarySave.save(context)
        registerUndo { service in
            let rides = previous.compactMap { change in service.ride(withID: change.id).map { (ride: $0, date: change.date) } }
            guard !rides.isEmpty else { return }
            service.setDeletedAt(rides)
        }
    }

    /// Permanently deletes trashed rides older than `days` (LIST-08), including the original file.
    func purgeTrash(olderThan days: Int = 30, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.deletedAt != nil })
        for ride in (try? context.fetch(descriptor)) ?? [] where (ride.deletedAt ?? now) <= cutoff {
            context.delete(ride)
        }
        LibrarySave.save(context)
    }

    /// Deletes the sample ride for good, including its original file.
    func removeSamples() {
        sampleRides().forEach(context.delete)
        LibrarySave.save(context)
    }

    func sampleRides() -> [Ride] {
        (try? context.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.isSample }))) ?? []
    }
}
