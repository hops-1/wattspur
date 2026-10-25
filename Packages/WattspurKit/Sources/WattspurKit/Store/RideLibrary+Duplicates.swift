import Foundation
import SwiftData

/// Finding the same ride in another file, and joining a Bosch FIT with a GPX of the same ride
/// (B-143, IMP-04). Start within ±60 s, GPS path within ±10 %, and the same simplified route
/// (B-104): the Bosch distance comes from the wheel sensor and lies about 5 % above the GPS path.
extension RideLibrary {
    /// How far the start times of two files of one ride may be apart, in seconds.
    public static let similarStartTolerance: TimeInterval = 60
    /// How far the GPS paths may be apart, as a share of the longer one.
    public static let similarDistanceTolerance = 0.10

    /// The ride of `bike` that `parsed` records again, if there is one. Rides of other bikes never
    /// match: two people on one tour start together and ride the same route (group ride), and
    /// their files are different rides. Rides in the trash, the sample ride and rides that are
    /// part of a merged ride do not match. The closest start wins.
    public func findSimilarRide(to parsed: ParsedRide, bike: Bike?) -> Ride? {
        let from = parsed.startDate.addingTimeInterval(-Self.similarStartTolerance)
        let to = parsed.startDate.addingTimeInterval(Self.similarStartTolerance)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && !$0.isSample && $0.deletedAt == nil
        })
        let candidates = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.mergedInto == nil && !$0.isMerged }
            .filter { bike == nil || $0.bike == nil || $0.bike?.id == bike?.id }
            .sorted { abs($0.startDate.timeIntervalSince(parsed.startDate)) < abs($1.startDate.timeIntervalSince(parsed.startDate)) }
        guard !candidates.isEmpty else { return nil }

        let newPath = GPSPath.length(of: parsed.samples)
        guard newPath > 0 else { return nil }
        let newRoute = OverviewRoute(samples: parsed.samples)
        for ride in candidates {
            let samples = ride.samples
            let path = GPSPath.length(of: samples)
            guard path > 0, abs(path - newPath) <= Self.similarDistanceTolerance * max(path, newPath) else { continue }
            let route = ride.overviewRoute.flatMap { $0.isEmpty ? nil : $0 } ?? OverviewRoute(samples: samples)
            if RouteMatch.matches(route, newRoute) { return ride }
        }
        return nil
    }

    /// Adds the extra source of a GPX file to a Bosch ride: its heart rate and temperature go into the
    /// time series, the file is noted. The Bosch values stay (Requirements 3.3).
    func attach(_ parsed: ParsedRide, fileName: String, to ride: Ride) {
        carrySensorValues(from: parsed.samples, startDate: parsed.startDate, to: ride)
        ride.attachedSourceName = fileName
        ride.attachedSourceFormat = RideSource.gpx.rawValue
    }

    /// Copies heart rate and temperature from `source` (a time series starting at `startDate`) to the
    /// nearest sample of the ride, if that is within `sensorTolerance` seconds.
    func carrySensorValues(from source: [RideSample], startDate: Date, to ride: Ride) {
        var samples = ride.samples
        guard !samples.isEmpty else { return }
        // Seconds the source axis runs ahead of the ride's.
        let shift = startDate.timeIntervalSince(ride.startDate)
        let heartRates = source.compactMap { s in s.heartRate.map { (time: s.time + shift, value: Double($0)) } }
        let temperatures = source.compactMap { s in s.temperature.map { (time: s.time + shift, value: $0) } }
        guard !heartRates.isEmpty || !temperatures.isEmpty else { return }
        let order = samples.indices.sorted { samples[$0].time < samples[$1].time }
        Self.assign(heartRates, to: order, in: &samples) { $0.heartRate = Int($1.rounded()) }
        Self.assign(temperatures, to: order, in: &samples) { $0.temperature = $1 }
        ride.setSamples(samples)
    }

    /// How far apart in seconds two samples may be to count as the same moment.
    static let sensorTolerance: TimeInterval = 5

    private static func assign(_ values: [(time: TimeInterval, value: Double)], to order: [Int], in samples: inout [RideSample],
                               set: (inout RideSample, Double) -> Void) {
        guard !values.isEmpty else { return }
        let sorted = values.sorted { $0.time < $1.time }
        var j = 0
        for index in order {
            let t = samples[index].time
            while j + 1 < sorted.count, abs(sorted[j + 1].time - t) <= abs(sorted[j].time - t) { j += 1 }
            if abs(sorted[j].time - t) <= sensorTolerance { set(&samples[index], sorted[j].value) }
        }
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

extension DuplicateFacts {
    public init(ride: Ride) {
        self.init(source: ride.source, startDate: ride.startDate, distance: ride.distance, rideTime: ride.timerTime,
                  ascent: ride.totalAscent, averagePower: ride.averagePower, pointCount: ride.samples.count,
                  estimated: ride.summaryEstimatedFromGPS)
    }
}
