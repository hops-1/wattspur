import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// V-05: the sample ride is anonymized, but its totals stay the Bosch values.
@Suite("FIT anonymizer")
struct FITAnonymizerTests {
    let anonymizer = FITAnonymizer(latitudeOffset: 1.25, longitudeOffset: -0.75, trimDistance: 500, weeks: -3)
    let original: ParsedRide
    let anonymized: ParsedRide
    let anonymizedData: Data

    init() throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        original = try FITRideImporter().parse(data)
        anonymizedData = try anonymizer.anonymize(data)
        anonymized = try FITRideImporter().parse(anonymizedData)
    }

    @Test("The result is a valid FIT file with a correct checksum")
    func validFile() throws {
        _ = try FITDecoder(verifyChecksum: true).decode(anonymizedData)
    }

    @Test("Totals and sensor data are unchanged")
    func totalsKept() {
        #expect(anonymized.summary == original.summary)
        #expect(anonymized.samples.map(\.power) == original.samples.map(\.power))
        #expect(anonymized.samples.map(\.cadence) == original.samples.map(\.cadence))
        #expect(anonymized.samples.map(\.distance) == original.samples.map(\.distance))
    }

    @Test("Positions are moved by the offset")
    func positionsMoved() throws {
        let pairs = zip(original.samples, anonymized.samples).filter { $0.1.latitude != nil }
        #expect(!pairs.isEmpty)
        for (before, after) in pairs {
            let lat = try #require(before.latitude), lon = try #require(before.longitude)
            #expect(abs(try #require(after.latitude) - (lat + 1.25)) < 1e-6)
            #expect(abs(try #require(after.longitude) - (lon - 0.75)) < 1e-6)
        }
    }

    @Test("No position within 500 m of the start or the end")
    func endsTrimmed() throws {
        let total = original.summary.distance
        // Not every sample has a distance; carry the last one forward (at most 1 s old,
        // hence the small tolerance).
        var distance: Double?
        for sample in anonymized.samples {
            distance = sample.distance ?? distance
            guard sample.latitude != nil else { continue }
            let metres = try #require(distance)
            #expect(metres >= 480 && metres <= total - 480)
        }
        // The route itself is still there.
        #expect(anonymized.samples.filter { $0.latitude != nil }.count > anonymized.samples.count * 8 / 10)
    }

    @Test("Times move by whole weeks, the serial number is gone")
    func timesAndSerial() {
        #expect(anonymized.startDate == original.startDate.addingTimeInterval(-3 * 7 * 86_400))
        #expect(anonymized.deviceSerialNumber == nil)
    }

    @Test("A broken file is rejected instead of patched")
    func brokenFile() {
        #expect(throws: FITDecodingError.self) { try anonymizer.anonymize(Data([1, 2, 3])) }
    }
}
