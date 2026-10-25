import Foundation
import SwiftData

extension RideLibrary {
    /// Groups of rides that probably belong together and include at least one of
    /// `rideIDs`, e.g. the rides just imported (B-096). Rides already in the
    /// library count too; trashed rides, the sample ride and parts of a merged
    /// ride do not. Oldest group first.
    public func mergeSuggestions(involving rideIDs: [UUID], maxGapMinutes: Int = RideMergeSuggestion.defaultGapMinutes)
        -> [RideMergeSuggestion.Group] {
        let wanted = Set(rideIDs)
        guard !wanted.isEmpty, maxGapMinutes > 0 else { return [] }
        let targets = wanted.compactMap { ride(withID: $0) }.filter { $0.deletedAt == nil && $0.mergedInto == nil && !$0.isSample }
        // The calendar day of a ride depends on its time zone, so look a day to either side.
        var candidates: [UUID: Ride] = [:]
        for target in targets {
            let from = target.startDate.addingTimeInterval(-86_400)
            let to = target.startDate.addingTimeInterval(2 * 86_400)
            let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
                $0.deletedAt == nil && $0.mergedInto == nil && !$0.isSample && $0.startDate >= from && $0.startDate <= to
            })
            for ride in (try? context.fetch(descriptor)) ?? [] { candidates[ride.id] = ride }
        }
        let entries = candidates.values.map { ride in
            RideMergeSuggestion.Entry(
                id: ride.id, start: ride.startDate, end: ride.startDate.addingTimeInterval(ride.elapsedTime),
                timeZone: ride.timeZone,
                startCoordinate: { ride.startCoordinate },
                endCoordinate: { ride.samples.last { $0.latitude != nil && $0.longitude != nil }
                    .flatMap { s in s.latitude.flatMap { lat in s.longitude.map { (lat, $0) } } } })
        }
        return RideMergeSuggestion.groups(in: entries, maxGap: TimeInterval(maxGapMinutes * 60))
            .filter { group in group.rideIDs.contains { wanted.contains($0) } }
    }
}
