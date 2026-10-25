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
        try? context.save()
        registerUndo { $0.rename(ride, to: old) }
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
        let previous = changes.map { ($0.ride, $0.ride.deletedAt) }
        for change in changes { change.ride.deletedAt = change.date }
        try? context.save()
        registerUndo { $0.setDeletedAt(previous) }
    }

    /// Permanently deletes trashed rides older than `days` (LIST-08), including the original file.
    func purgeTrash(olderThan days: Int = 30, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-TimeInterval(days) * 86_400)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.deletedAt != nil })
        for ride in (try? context.fetch(descriptor)) ?? [] where (ride.deletedAt ?? now) <= cutoff {
            context.delete(ride)
        }
        try? context.save()
    }

    /// Deletes the sample ride for good, including its original file.
    func removeSamples() {
        sampleRides().forEach(context.delete)
        try? context.save()
    }

    func sampleRides() -> [Ride] {
        (try? context.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.isSample }))) ?? []
    }
}
