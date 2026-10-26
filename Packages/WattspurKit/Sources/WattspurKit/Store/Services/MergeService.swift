import Foundation
import SwiftData

/// Merging rides and suggesting what belongs together (B-095, B-096, B-131, LIST-09).
struct MergeService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    private var bikes: BikeService { BikeService(env) }

    /// Why the rides cannot be merged, or `nil` if they can. Merged rides count
    /// with their parts, so a merged ride can be merged again.
    func mergeProblem(_ rides: [Ride]) -> RideMerge.MergeError? {
        let parts = Self.leafParts(of: rides)
        if parts.count < 2 { return .tooFewRides }
        if rides.contains(where: \.isSample) { return .containsSample }
        // Only start and duration matter here; decoding the time series would slow down menus.
        let spans = parts.map { RideMerge.Part(startDate: $0.startDate, summary: $0.summary, samples: [], workKilojoules: 0) }
        return RideMerge.overlaps(spans) ? .overlapping : nil
    }

    /// Merges the rides into a new ride with the given name, in one save, so ⌘Z
    /// undoes it. The originals become its hidden parts and keep their files;
    /// merged rides among them are dissolved into their parts first.
    @discardableResult
    func merge(_ rides: [Ride], name: String) throws(RideMerge.MergeError) -> Ride {
        if let problem = mergeProblem(rides) { throw problem }
        let parts = mergeParts(of: rides)
        // Merged rides among the selection are dissolved; undo merges them again.
        let previousGroups = rides.filter(\.isMerged).map { (parts: $0.sortedParts, name: $0.name, deletedAt: $0.deletedAt) }
        let first = parts[0]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ride = Ride(name: trimmed.isEmpty ? first.name : trimmed, startDate: first.startDate)
        ride.timeZoneIdentifier = first.timeZoneIdentifier
        ride.deviceSerialNumber = first.deviceSerialNumber
        ride.rider = first.rider ?? bikes.defaultRider()
        ride.bike = first.bike ?? bikes.defaultBike()
        context.insert(ride)
        for old in rides where old.isMerged {
            old.parts = []
            context.delete(old)
        }
        for part in parts { part.mergedInto = ride }
        refresh(ride)
        try? context.save()
        registerUndo { service in
            service.split(ride)
            for group in previousGroups {
                let again = try? service.merge(group.parts, name: group.name)
                again?.deletedAt = group.deletedAt
            }
        }
        return ride
    }

    /// Dissolves a merged ride: its parts come back as rides of their own.
    /// Returns them, oldest first.
    @discardableResult
    func split(_ ride: Ride) -> [Ride] {
        let parts = ride.sortedParts
        guard !parts.isEmpty else { return [] }
        let name = ride.name
        let deletedAt = ride.deletedAt
        for part in parts {
            part.mergedInto = nil
            part.deletedAt = deletedAt
        }
        ride.parts = []
        context.delete(ride)
        try? context.save()
        registerUndo { service in
            for part in parts { part.deletedAt = nil }
            let again = try? service.merge(parts, name: name)
            again?.deletedAt = deletedAt
            try? service.context.save()
        }
        return parts
    }

    /// What merging the rides would give, for the confirmation dialog.
    func mergePreview(_ rides: [Ride]) throws(RideMerge.MergeError) -> RideMerge.Result {
        if let problem = mergeProblem(rides) { throw problem }
        return try Self.merged(Self.leafParts(of: rides))
    }

    /// The original rides behind the given ones, oldest first.
    func mergeParts(of rides: [Ride]) -> [Ride] {
        Self.leafParts(of: rides).sorted { $0.startDate < $1.startDate }
    }

    /// Recomputes a merged ride's values from its parts (after merging or re-parsing).
    func refresh(_ ride: Ride) {
        guard let result = try? Self.merged(ride.sortedParts) else { return }
        let parts = ride.sortedParts
        ride.startDate = result.startDate
        ride.parserVersion = parts.map(\.parserVersion).min() ?? 0
        let s = result.summary
        ride.timerTime = s.timerTime
        ride.elapsedTime = s.elapsedTime
        ride.distance = s.distance
        ride.averageSpeed = s.averageSpeed
        ride.maxSpeed = s.maxSpeed
        ride.averagePower = s.averagePower
        ride.maxPower = s.maxPower
        ride.averageCadence = s.averageCadence
        ride.maxCadence = s.maxCadence
        ride.totalAscent = s.totalAscent
        ride.totalDescent = s.totalDescent
        ride.workKilojoules = result.workKilojoules
        ride.minAltitude = result.minAltitude
        ride.maxAltitude = result.maxAltitude
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        ride.samplesData = try? encoder.encode(result.samples)
        ride.updateOverviewRouteFromParts()
        ride.updatePeakPowerFromParts()
    }

    private static func merged(_ parts: [Ride]) throws(RideMerge.MergeError) -> RideMerge.Result {
        let sorted = parts.sorted { $0.startDate < $1.startDate }
        return try RideMerge.merge(sorted.map(mergePart), timeZone: sorted.first?.timeZone ?? .current)
    }

    private static func leafParts(of rides: [Ride]) -> [Ride] {
        rides.flatMap { $0.isMerged ? $0.sortedParts : [$0] }
    }

    /// Where the parts of a merged ride meet (B-131); empty for any other ride.
    func joins(of ride: Ride) -> [RideMerge.Join] {
        let parts = ride.sortedParts
        guard parts.count >= 2 else { return [] }
        return RideMerge.joins(of: parts.map(Self.mergePart), timeZone: parts[0].timeZone)
    }

    private static func mergePart(_ ride: Ride) -> RideMerge.Part {
        RideMerge.Part(startDate: ride.startDate, summary: ride.summary, samples: ride.samples,
                       workKilojoules: ride.workKilojoules, minAltitude: ride.minAltitude, maxAltitude: ride.maxAltitude)
    }

    // MARK: - Suggestions (B-096)

    /// Groups of rides that probably belong together and include at least one of
    /// `rideIDs`, e.g. the rides just imported (B-096). Rides already in the
    /// library count too; trashed rides, the sample ride and parts of a merged
    /// ride do not. Oldest group first.
    func mergeSuggestions(involving rideIDs: [UUID], maxGapMinutes: Int = RideMergeSuggestion.defaultGapMinutes)
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
