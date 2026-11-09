import Foundation
import SwiftData

/// Several Bosch rides inside one iPhone recording (B-274). Bosch Flow saves a tour with long pauses
/// as several rides, the iPhone as one recording with pauses. A Bosch file matches a ride only with
/// about the same distance (`ImportService.findSimilarRide`), so the parts stayed apart from the
/// recording. Now: when the Bosch rides that lie wholly inside a recording add up to its distance, they
/// are merged (as with "Merge Rides"), take the recording's name, bike, heart rate, lean angle,
/// acceleration and roughness, and the recording goes to the trash, where it can be restored.
struct RecordingPartsService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    /// How far a part may start before or end after the recording: the Bosch clock and the moment the
    /// rider taps "Start" differ by a little.
    static let spanTolerance: TimeInterval = 120
    /// The Bosch distances together against the GPS path of the recording. The wheel sensor counts
    /// about 5 % more than the GPS (`ImportService`); a missing short part or a long one too many
    /// falls outside.
    static let distanceShare = 0.9...1.2

    /// After a Bosch ride came in (or came again): if it belongs to a recording together with other
    /// Bosch rides, merges them and returns the merged ride; else `nil` and nothing changes.
    @discardableResult
    func joinParts(around ride: Ride) -> Ride? {
        guard ride.source == .fit, ride.mergedInto == nil, !ride.isMerged, ride.deletedAt == nil, !ride.isSample,
              let recording = recording(containing: ride) else { return nil }
        return joinParts(of: recording)
    }

    /// The Bosch rides inside `recording`, merged with its values, if they add up to its distance.
    @discardableResult
    func joinParts(of recording: Ride) -> Ride? {
        let parts = boschRides(inside: recording)
        guard parts.count >= 2 else { return nil }
        let samples = recording.samples
        let path = GPSPath.length(of: samples)
        let sum = parts.reduce(0) { $0 + $1.distance }
        guard path > 0, Self.distanceShare.contains(sum / path) else { return nil }

        let imports = ImportService(env)
        for part in parts {
            imports.carrySensorValues(from: samples, startDate: recording.startDate, to: part)
            part.attachedSourceName = recording.sourceFile?.fileName
            part.attachedSourceFormat = RideSource.gpx.rawValue
            if let bike = recording.bike { part.bike = bike }
        }
        guard let merged = try? MergeService(env).merge(parts, name: recording.name) else { return nil }
        if let bike = recording.bike { merged.bike = bike }
        RideService(env).moveToTrash(recording)
        LibrarySave.save(context)
        return merged
    }

    /// A GPX ride on its own (no Bosch file attached, not merged) whose time covers the ride's.
    private func recording(containing ride: Ride) -> Ride? {
        let start = ride.startDate, end = ride.startDate.addingTimeInterval(ride.elapsedTime)
        let from = start.addingTimeInterval(-ImportService.similarLookBack)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= start && $0.deletedAt == nil && !$0.isSample
        })
        return ((try? context.fetch(descriptor)) ?? []).first { candidate in
            candidate.source == .gpx && candidate.attachedSourceFormat == nil
                && candidate.mergedInto == nil && !candidate.isMerged
                && candidate.startDate.addingTimeInterval(-Self.spanTolerance) <= start
                && candidate.startDate.addingTimeInterval(candidate.elapsedTime + Self.spanTolerance) >= end
        }
    }

    /// The Bosch rides that lie wholly inside the recording's time, oldest first.
    private func boschRides(inside recording: Ride) -> [Ride] {
        let from = recording.startDate.addingTimeInterval(-Self.spanTolerance)
        let to = recording.startDate.addingTimeInterval(recording.elapsedTime + Self.spanTolerance)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && $0.deletedAt == nil && !$0.isSample
        }, sortBy: [SortDescriptor(\.startDate)])
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.source == .fit && $0.mergedInto == nil && !$0.isMerged
                && $0.startDate.addingTimeInterval($0.elapsedTime) <= to
        }
    }
}
