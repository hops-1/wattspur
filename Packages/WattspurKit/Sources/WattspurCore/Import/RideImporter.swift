import Foundation

public enum RideImportError: Error, Equatable, Sendable {
    case decoding(FITDecodingError)
    case gpx(GPXImportError)
    case noRideData
}

/// A source format that can be turned into a `ParsedRide` (Requirements chapter 7).
/// FIT is the first implementation; GPX, Apple Health or Strava can follow.
public protocol RideImporter: Sendable {
    /// File extensions this importer handles, lower case, without dot.
    var fileExtensions: Set<String> { get }
    /// Current parser version; stored rides with a lower one are re-parsed (NFR-17).
    var parserVersion: Int { get }
    func parse(_ data: Data) throws(RideImportError) -> ParsedRide
}

/// Imports Bosch eBike Flow FIT exports (and other FIT activity files).
public struct FITRideImporter: RideImporter {
    /// Bump whenever parsing changes so stored rides are re-parsed (NFR-17).
    public static let parserVersion = 2

    public let fileExtensions: Set<String> = ["fit"]
    public var parserVersion: Int { Self.parserVersion }
    private let decoder: FITDecoder

    public init(decoder: FITDecoder = FITDecoder()) {
        self.decoder = decoder
    }

    public func parse(_ data: Data) throws(RideImportError) -> ParsedRide {
        let file: FITFile
        do {
            file = try decoder.decode(data)
        } catch {
            throw .decoding(error)
        }

        let records = file.messages(FITProfile.Message.record)
        let session = file.messages(FITProfile.Message.session).first

        let firstRecordTime = records.lazy.compactMap { $0[FITProfile.timestampField]?.integerValue }.first
        guard let startTimestamp = session?[FITProfile.Session.startTime]?.integerValue ?? firstRecordTime else {
            throw .noRideData
        }

        let samples = Self.mergeRecords(records, startTimestamp: startTimestamp)
        guard !samples.isEmpty || session != nil else { throw .noRideData }

        let summary = session.map(Self.summary(from:)) ?? Self.summary(estimatedFrom: samples)
        let serial = file.messages(FITProfile.Message.fileID).first?[FITProfile.FileID.serialNumber]?.integerValue

        // Work is summed over the raw records, as Bosch does: records sharing a
        // second each count as one second of pedalling (matches the Flow app's kcal).
        let powers = records.compactMap { Self.sensorValue($0[FITProfile.Record.power]) }
        let work = powers.isEmpty ? nil : powers.reduce(0.0) { $0 + Double($1) } / 1000

        return ParsedRide(
            startDate: Date(fitTimestamp: startTimestamp),
            summary: summary,
            samples: samples,
            deviceSerialNumber: serial.flatMap { UInt64(exactly: $0) },
            parserVersion: Self.parserVersion,
            workKilojoules: work
        )
    }

    // MARK: - Merging the record streams (B-004)

    /// Bosch writes position and sensor values in separate `record` messages that
    /// share only the timestamp. They are merged into one sample per second.
    /// A number from the file, unless it is NaN or infinite (a float field can hold both).
    private static func finite(_ value: FITValue?) -> Double? {
        guard let d = value?.doubleValue, d.isFinite else { return nil }
        return d
    }

    /// Power and cadence are small whole numbers; anything else is damage and is ignored, which
    /// also keeps the sums over a ride far from overflowing.
    private static func sensorValue(_ value: FITValue?) -> Int? {
        guard let v = value?.integerValue, (0...100_000).contains(v) else { return nil }
        return Int(v)
    }

    static func mergeRecords(_ records: [FITMessage], startTimestamp: Int64) -> [RideSample] {
        typealias F = FITProfile.Record
        var bySecond: [Int64: RideSample] = [:]

        for record in records {
            guard let timestamp = record[FITProfile.timestampField]?.integerValue else { continue }
            var sample = bySecond[timestamp] ?? RideSample(time: TimeInterval(timestamp) - TimeInterval(startTimestamp))

            if let lat = Self.finite(record[F.positionLat]), let lon = Self.finite(record[F.positionLong]) {
                sample.latitude = FITProfile.degrees(fromSemicircles: lat)
                sample.longitude = FITProfile.degrees(fromSemicircles: lon)
            }
            if let alt = Self.finite(record[F.enhancedAltitude] ?? record[F.altitude]) {
                sample.altitude = alt / 5 - 500
            }
            if let distance = Self.finite(record[F.distance]) {
                sample.distance = distance / 100
            }
            if let speed = Self.finite(record[F.enhancedSpeed] ?? record[F.speed]) {
                sample.speed = speed / 1000
            }
            if let power = Self.sensorValue(record[F.power]) {
                sample.power = power
            }
            if let cadence = Self.sensorValue(record[F.cadence]) {
                sample.cadence = cadence
                sample.cadenceMeasured = true
            }
            bySecond[timestamp] = sample
        }

        var samples = bySecond.values.sorted { $0.time < $1.time }

        // Hold the last measured cadence for display.
        var lastCadence: Int?
        for i in samples.indices {
            if samples[i].cadenceMeasured {
                lastCadence = samples[i].cadence
            } else if samples[i].power != nil || samples[i].speed != nil {
                samples[i].cadence = lastCadence
            }
        }
        return samples
    }

    // MARK: - Summary

    static func summary(from session: FITMessage) -> RideSummary {
        typealias S = FITProfile.Session
        func value(_ field: UInt8) -> Double? { session[field]?.doubleValue.flatMap { $0.isFinite ? $0 : nil } }
        func int(_ field: UInt8) -> Int? { session[field]?.integerValue.flatMap { (0...10_000_000).contains($0) ? Int($0) : nil } }

        return RideSummary(
            timerTime: (value(S.totalTimerTime) ?? 0) / 1000,
            elapsedTime: (value(S.totalElapsedTime) ?? 0) / 1000,
            distance: (value(S.totalDistance) ?? 0) / 100,
            averageSpeed: (value(S.enhancedAvgSpeed) ?? value(S.avgSpeed)).map { $0 / 1000 },
            maxSpeed: (value(S.enhancedMaxSpeed) ?? value(S.maxSpeed)).map { $0 / 1000 },
            averagePower: int(S.avgPower),
            maxPower: int(S.maxPower),
            averageCadence: int(S.avgCadence),
            maxCadence: int(S.maxCadence),
            totalAscent: int(S.totalAscent),
            totalDescent: int(S.totalDescent)
        )
    }

    /// Fallback for files without a `session` message.
    static func summary(estimatedFrom samples: [RideSample]) -> RideSummary {
        let duration = samples.last?.time ?? 0
        let distance = samples.last(where: { $0.distance != nil })?.distance ?? 0
        let powers = samples.compactMap(\.power).filter { $0 > 0 }
        let cadences = samples.filter(\.cadenceMeasured).compactMap(\.cadence).filter { $0 > 0 }
        return RideSummary(
            timerTime: TimeInterval(samples.count),
            elapsedTime: duration,
            distance: distance,
            averageSpeed: samples.isEmpty ? nil : distance / TimeInterval(samples.count),
            maxSpeed: samples.compactMap(\.speed).max(),
            averagePower: powers.isEmpty ? nil : powers.reduce(0, +) / powers.count,
            maxPower: powers.max(),
            averageCadence: cadences.isEmpty ? nil : cadences.reduce(0, +) / cadences.count,
            maxCadence: cadences.max()
        )
    }
}
