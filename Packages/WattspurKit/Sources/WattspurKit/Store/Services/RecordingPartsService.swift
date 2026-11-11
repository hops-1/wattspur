import Foundation
import SwiftData

/// Several Bosch rides inside one iPhone recording (B-274). Bosch Flow saves a tour with long pauses
/// as several rides, the iPhone as one recording with pauses. A Bosch file matches a ride only with
/// about the same distance (`ImportService.findSimilarRide`), so the parts stayed apart from the
/// recording. Now: when the Bosch rides that lie wholly inside a recording add up to its distance, they
/// are merged (as with "Merge Rides"), take the recording's name, bike, heart rate, lean angle,
/// acceleration and roughness, and the recording goes to the trash, where it can be restored.
/// The opposite, one Bosch ride over several recordings, is split (`splitAcrossRecordings`).
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

    // MARK: One Bosch ride over several recordings

    /// After a Bosch ride came in (or came again): if it covers several iPhone recordings, splits it
    /// into one Bosch ride per recording and returns them, oldest first; else `nil` and nothing
    /// changes. The opposite of `joinParts`: on 11.11.2026 Bosch Flow saved the way to work and the way
    /// home as one ride, the iPhone as two recordings, and the three stayed apart. Each piece takes the
    /// Bosch values of its time, the recording's name, bike, heart rate and lean angle; the recordings
    /// go to the trash, where they can be restored. The whole Bosch ride is deleted: its file lives on
    /// in every piece, and a ride in the trash would come back when the file is imported again.
    @discardableResult
    func splitAcrossRecordings(_ ride: Ride) -> [Ride]? {
        guard ride.source == .fit, !ride.isMerged, ride.mergedInto == nil, ride.attachedSourceFormat == nil,
              ride.deletedAt == nil, !ride.isSample else { return nil }
        let recordings = recordings(inside: ride)
        guard recordings.count >= 2 else { return nil }
        let path = recordings.reduce(0) { $0 + GPSPath.length(of: $1.samples) }
        guard path > 0, Self.distanceShare.contains(ride.distance / path) else { return nil }

        let samples = ride.samples
        let pieces = recordings.map { recording in
            let window = Self.window(of: recording)
            return samples.filter { window.contains(ride.startDate.addingTimeInterval($0.time)) }
        }
        guard pieces.allSatisfy({ $0.count >= 2 }) else { return nil }
        let total = samples.count

        let imports = ImportService(env)
        var rides: [Ride] = []
        for (recording, piece) in zip(recordings, pieces) {
            let parsed = Self.parsed(piece, of: ride, share: Double(piece.count) / Double(total))
            let part = Ride(name: recording.name, startDate: parsed.startDate)
            part.sourceIdentifier = ride.sourceIdentifier
            part.sourceFormat = ride.sourceFormat
            part.apply(parsed)
            part.rider = ride.rider
            part.bike = recording.bike ?? ride.bike
            if let file = ride.sourceFile, let data = file.data {
                part.sourceFile = SourceFile(fileName: file.fileName, data: data)
            }
            context.insert(part)
            imports.carrySensorValues(from: recording.samples, startDate: recording.startDate, to: part)
            part.attachedSourceName = recording.sourceFile?.fileName
            part.attachedSourceFormat = RideSource.gpx.rawValue
            rides.append(part)
        }
        RideService(env).moveToTrash(recordings)
        context.delete(ride)
        LibrarySave.save(context)
        return rides
    }

    /// After a recording came in: if a Bosch ride covers it and other recordings, splits that ride
    /// (`splitAcrossRecordings`); else `nil`.
    @discardableResult
    func splitBoschRide(around recording: Ride) -> [Ride]? {
        guard recording.source == .gpx, recording.attachedSourceFormat == nil, !recording.isMerged,
              recording.mergedInto == nil, recording.deletedAt == nil, !recording.isSample else { return nil }
        let span = Self.span(of: recording)
        let from = span.lowerBound.addingTimeInterval(-ImportService.similarLookBack)
        let to = span.lowerBound.addingTimeInterval(Self.spanTolerance)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && $0.deletedAt == nil && !$0.isSample
        })
        let covering = ((try? context.fetch(descriptor)) ?? []).first { candidate in
            guard candidate.source == .fit, candidate.attachedSourceFormat == nil,
                  candidate.mergedInto == nil, !candidate.isMerged else { return false }
            let window = Self.window(of: candidate)
            return window.contains(span.lowerBound) && window.contains(span.upperBound)
        }
        return covering.flatMap(splitAcrossRecordings)
    }

    /// The recordings on their own (no Bosch file attached, not merged) whose points lie wholly inside
    /// the Bosch ride's time, oldest first.
    private func recordings(inside ride: Ride) -> [Ride] {
        let window = Self.window(of: ride)
        let from = window.lowerBound
        let to = window.upperBound
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && $0.deletedAt == nil && !$0.isSample
        }, sortBy: [SortDescriptor(\.startDate)])
        return ((try? context.fetch(descriptor)) ?? []).filter { candidate in
            guard candidate.id != ride.id, candidate.source == .gpx, candidate.attachedSourceFormat == nil,
                  candidate.mergedInto == nil, !candidate.isMerged else { return false }
            let span = Self.span(of: candidate)
            return window.contains(span.lowerBound) && window.contains(span.upperBound)
        }
    }

    /// One piece of a Bosch ride as a ride of its own: its points from zero, its distance from the wheel
    /// sensor where the points have it, else its `share` of the ride's.
    static func parsed(_ piece: [RideSample], of ride: Ride, share: Double) -> ParsedRide {
        let first = piece[0].time
        let base = piece.first { $0.distance != nil }?.distance
        let samples = piece.map { sample in
            var sample = sample
            sample.time -= first
            if let base, let distance = sample.distance { sample.distance = distance - base }
            return sample
        }
        var summary = FITRideImporter.summary(estimatedFrom: samples)
        if base == nil || summary.distance <= 0 {
            summary.distance = ride.distance * share
            summary.averageSpeed = summary.timerTime > 0 ? summary.distance / summary.timerTime : nil
        }
        let powers = samples.compactMap(\.power)
        return ParsedRide(startDate: ride.startDate.addingTimeInterval(first), summary: summary, samples: samples,
                          deviceSerialNumber: ride.deviceSerialNumber.map { UInt64(bitPattern: $0) },
                          parserVersion: ride.parserVersion,
                          workKilojoules: powers.isEmpty ? nil : powers.reduce(0.0) { $0 + Double($1) } / 1000)
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
