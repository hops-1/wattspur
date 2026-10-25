import Foundation

/// What the duplicate dialog puts side by side: a ride in the library and a new file that looks
/// like the same ride (B-143, B-144). `nil` stands for "not in this source".
public struct DuplicateFacts: Sendable, Equatable {
    public var source: RideSource?
    public var startDate: Date
    /// Metres; for a GPX the estimate from the track.
    public var distance: Double
    public var rideTime: TimeInterval
    public var ascent: Int?
    public var averagePower: Int?
    public var pointCount: Int
    /// `true` if the totals are estimated from a GPS track.
    public var estimated: Bool

    public init(ride: Ride) {
        source = ride.source
        startDate = ride.startDate
        distance = ride.distance
        rideTime = ride.timerTime
        ascent = ride.totalAscent
        averagePower = ride.averagePower
        pointCount = ride.samples.count
        estimated = ride.summaryEstimatedFromGPS
    }

    public init(parsed: ParsedRide, source: RideSource?) {
        self.source = source
        startDate = parsed.startDate
        distance = parsed.summary.distance
        rideTime = parsed.summary.timerTime
        ascent = parsed.summary.totalAscent
        averagePower = parsed.summary.averagePower
        pointCount = parsed.samples.count
        estimated = parsed.summaryEstimated
    }
}

extension RideLibrary {
    /// The facts of a file for the duplicate dialog; `nil` if no importer reads it.
    public func facts(ofFileAt url: URL) -> DuplicateFacts? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard let data = try? Data(contentsOf: url),
              let importer = importers.first(where: { $0.fileExtensions.contains(ext) }),
              let parsed = try? importer.parse(data) else { return nil }
        return DuplicateFacts(parsed: parsed, source: RideSource(fileExtension: ext))
    }
}
