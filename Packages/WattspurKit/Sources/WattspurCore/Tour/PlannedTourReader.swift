import Foundation

/// What a GPX file holds, from a quick look at its first points (B-372, V-22).
public enum GPXContent: Sendable, Equatable {
    /// A recorded ride: real times, or the file is no GPX at all (the ride importer then says why).
    case ride
    /// A planned tour without any time: only `rte`, or a `trk` without times.
    case plannedTour
    /// A `trk` whose times look estimated: no time in the metadata, steps of more than 3 s and points
    /// more than 20 m apart (medians). komoot exports its tours so; then the tour is the likely answer,
    /// otherwise the ride.
    case estimatedTimes(komoot: Bool)

    /// What an import takes without asking (the watched folder on the Mac): the tour for a file
    /// without times and for a komoot file with estimated times, the ride for everything else.
    public var isTourWithoutAsking: Bool {
        switch self {
        case .plannedTour, .estimatedTimes(komoot: true): true
        case .ride, .estimatedTimes(komoot: false): false
        }
    }
}

/// Reads a planned tour from a GPX file (B-372) with the reader of the ride importer: the points of
/// the tracks (their times are ignored) or, without a track, of the routes; waypoints are left out.
public struct PlannedTourReader: Sendable {
    /// Bump whenever reading changes.
    public static let parserVersion = 1
    /// Steps longer than this (median, seconds) look estimated (V-22: komoot 7 s, a recording 1 s).
    public static let estimatedStep: TimeInterval = 3
    /// Points further apart than this (median, metres) look planned (V-22: komoot 37 m).
    public static let estimatedSpacing = 20.0
    /// The quick look reads at most this many points.
    public static let lookPoints = 500
    /// `content(of:)` needs no more than the start of a file.
    public static let lookBytes = 1024 * 1024

    public let maxFileSize: Int
    public let maxPoints: Int

    public init(maxFileSize: Int = GPXRideImporter.defaultMaxFileSize, maxPoints: Int = GPXRideImporter.defaultMaxPoints) {
        self.maxFileSize = maxFileSize
        self.maxPoints = maxPoints
    }

    /// The tour in the file. Throws `noTrackPoints` (or `onlyRoutesOrWaypoints` for waypoints alone)
    /// when fewer than two points with a position are left, and the reader's errors for a broken file.
    public func read(_ data: Data) throws(GPXImportError) -> PlannedTour {
        guard data.count <= maxFileSize else { throw .tooLarge }
        let reader = GPXReader(maxPoints: maxPoints)
        let finished = Self.parse(data, with: reader)
        if reader.exceededPoints { throw .tooManyPoints }
        if !finished {
            if !reader.sawRoot { throw .notGPX }
            throw .malformedXML
        }
        guard reader.sawRoot else { throw .notGPX }

        let track = reader.segments.joined().filter(\.hasValidPosition)
        let line = track.count >= 2 ? Array(track) : reader.routes.joined().filter(\.hasValidPosition)
        guard line.count >= 2 else { throw reader.sawRouteOrWaypoint && track.isEmpty ? .onlyRoutesOrWaypoints : .noTrackPoints }
        let points = line.map { PlannedTour.Point(latitude: $0.latitude, longitude: $0.longitude, altitude: $0.altitude) }
        let name = [reader.trackName, reader.routeName, reader.metadataName].compactMap { $0 }.first { !$0.isEmpty }
        return PlannedTour(name: name, points: points, source: Self.isKomoot(reader.creator) ? .komoot : .gpx)
    }

    /// A quick look at the first points (`lookPoints`); `data` may be just the start of the file.
    public static func content(of data: Data) -> GPXContent {
        let reader = GPXReader(maxPoints: GPXRideImporter.defaultMaxPoints, stopAfter: lookPoints)
        _ = parse(data.prefix(lookBytes), with: reader)
        guard reader.sawRoot else { return .ride }
        let track = reader.segments.joined().filter(\.hasValidPosition)
        if track.isEmpty {
            return reader.routes.joined().filter(\.hasValidPosition).count >= 2 ? .plannedTour : .ride
        }
        let timed = track.filter { $0.time != nil }
        if timed.isEmpty { return .plannedTour }
        guard timed.count >= 3, !reader.hasMetadataTime else { return .ride }

        var steps: [Double] = []
        var spacings: [Double] = []
        for (a, b) in zip(timed, timed.dropFirst()) {
            let dt = b.time!.timeIntervalSince(a.time!)
            guard dt > 0 else { continue }
            steps.append(dt)
            spacings.append(a.distance(to: b))
        }
        guard let step = median(steps), let spacing = median(spacings),
              step > estimatedStep, spacing > estimatedSpacing else { return .ride }
        return .estimatedTimes(komoot: isKomoot(reader.creator))
    }

    static func isKomoot(_ creator: String?) -> Bool {
        creator?.lowercased().contains("komoot") ?? false
    }

    private static func parse(_ data: Data, with reader: GPXReader) -> Bool {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        return parser.parse()
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted.count.isMultiple(of: 2) ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
    }
}
