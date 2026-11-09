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
    /// Bosch rides, merges them and returns the merged ride; else `nil` and nothing changes. A part of a
    /// merged ride stands for that ride.
    @discardableResult
    func joinParts(around ride: Ride) -> Ride? {
        let ride = ride.mergedInto ?? ride
        guard Self.isBosch(ride), ride.deletedAt == nil, !ride.isSample,
              let recording = recording(containing: ride) else { return nil }
        return joinParts(of: recording)
    }

    /// The Bosch rides inside `recording`, merged with its values, if they add up to its distance.
    /// Bosch rides merged before (by hand, or two parts of three) count as one piece of it.
    @discardableResult
    func joinParts(of recording: Ride) -> Ride? {
        let pieces = boschRides(inside: recording)
        let parts = pieces.flatMap { $0.isMerged ? $0.sortedParts : [$0] }
        guard parts.count >= 2 else { return nil }
        let samples = recording.samples
        let path = GPSPath.length(of: samples)
        let sum = pieces.reduce(0) { $0 + $1.distance }
        guard path > 0, Self.distanceShare.contains(sum / path) else { return nil }

        let imports = ImportService(env)
        for part in parts {
            imports.carrySensorValues(from: samples, startDate: recording.startDate, to: part)
            part.attachedSourceName = recording.sourceFile?.fileName
            part.attachedSourceFormat = RideSource.gpx.rawValue
            if let bike = recording.bike { part.bike = bike }
        }
        guard let merged = try? MergeService(env).merge(pieces, name: recording.name) else { return nil }
        if let bike = recording.bike { merged.bike = bike }
        RideService(env).moveToTrash(recording)
        LibrarySave.save(context)
        return merged
    }

    /// A Bosch ride on its own, or a merged ride made of Bosch rides only.
    private static func isBosch(_ ride: Ride) -> Bool {
        guard ride.mergedInto == nil else { return false }
        if ride.isMerged { return ride.sortedParts.allSatisfy { $0.source == .fit } }
        return ride.source == .fit
    }

    /// When the ride really ran: from its first to its last point. The start in a Bosch file can lie
    /// long before the first point (7.11.2026: start 11:00, first point 12:14), and the elapsed time
    /// counts from there; without points, the start and the elapsed time.
    static func span(of ride: Ride) -> ClosedRange<Date> {
        let samples = ride.samples
        guard let first = samples.first?.time, let last = samples.last?.time, last >= first else {
            return ride.startDate...ride.startDate.addingTimeInterval(max(ride.elapsedTime, 0))
        }
        return ride.startDate.addingTimeInterval(first)...ride.startDate.addingTimeInterval(last)
    }

    /// A GPX ride on its own (no Bosch file attached, not merged) whose time covers the ride's.
    private func recording(containing ride: Ride) -> Ride? {
        let span = Self.span(of: ride)
        let from = span.lowerBound.addingTimeInterval(-ImportService.similarLookBack)
        let to = span.lowerBound.addingTimeInterval(Self.spanTolerance)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && $0.deletedAt == nil && !$0.isSample
        })
        return ((try? context.fetch(descriptor)) ?? []).first { candidate in
            guard candidate.source == .gpx, candidate.attachedSourceFormat == nil,
                  candidate.mergedInto == nil, !candidate.isMerged else { return false }
            return Self.window(of: candidate).contains(span.lowerBound) && Self.window(of: candidate).contains(span.upperBound)
        }
    }

    /// The recording's time with the tolerance on both sides.
    private static func window(of recording: Ride) -> ClosedRange<Date> {
        let span = span(of: recording)
        return span.lowerBound.addingTimeInterval(-spanTolerance)...span.upperBound.addingTimeInterval(spanTolerance)
    }

    /// The Bosch rides (and merged Bosch rides) whose points lie wholly inside the recording's time,
    /// oldest first. A Bosch start may lie hours before its first point, so the search reaches back.
    private func boschRides(inside recording: Ride) -> [Ride] {
        let window = Self.window(of: recording)
        let from = window.lowerBound.addingTimeInterval(-ImportService.similarLookBack)
        let to = window.upperBound
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && $0.deletedAt == nil && !$0.isSample
        }, sortBy: [SortDescriptor(\.startDate)])
        return ((try? context.fetch(descriptor)) ?? []).filter { ride in
            guard ride.id != recording.id, Self.isBosch(ride) else { return false }
            let span = Self.span(of: ride)
            return window.contains(span.lowerBound) && window.contains(span.upperBound)
        }
    }
}
