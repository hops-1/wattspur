import Foundation
import SwiftData
import Testing
@testable import WattspurKit

/// Fields for the GPX import (B-141): only the model, no parser. Rides and series
/// stored before must read and write exactly as before.
@MainActor
@Suite("Source data for GPX")
struct SourceDataTests {
    /// A sample as earlier versions stored it, without heart rate and temperature.
    private struct LegacySample: Codable, Equatable {
        var time: TimeInterval
        var latitude: Double?
        var longitude: Double?
        var altitude: Double?
        var distance: Double?
        var speed: Double?
        var power: Int?
        var cadence: Int?
        var cadenceMeasured: Bool
    }

    private func plist<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    private func keys(of data: Data) throws -> Set<String> {
        let array = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]])
        return Set(array.flatMap(\.keys))
    }

    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test("Time series stored before decode with no heart rate and no temperature")
    func decodesOldSeries() throws {
        let old = [LegacySample(time: 0, latitude: 49.1, longitude: 8.2, altitude: 120, distance: 0, speed: 5, power: 130, cadence: 60, cadenceMeasured: true),
                   LegacySample(time: 1, latitude: nil, longitude: nil, altitude: nil, distance: 5, speed: nil, power: nil, cadence: nil, cadenceMeasured: false)]
        let decoded = try PropertyListDecoder().decode([RideSample].self, from: try plist(old))
        #expect(decoded.count == 2)
        #expect(decoded[0].power == 130 && decoded[0].cadenceMeasured && decoded[0].latitude == 49.1)
        #expect(decoded.allSatisfy { $0.heartRate == nil && $0.temperature == nil })
    }

    @Test("Samples without the new values write no new keys, so stored series stay unchanged")
    func encodesLikeBefore() throws {
        let samples = [RideSample(time: 0, latitude: 49.1, longitude: 8.2, altitude: 120, distance: 0, speed: 5, power: 130, cadence: 60, cadenceMeasured: true),
                       RideSample(time: 1, distance: 5)]
        let legacy = [LegacySample(time: 0, latitude: 49.1, longitude: 8.2, altitude: 120, distance: 0, speed: 5, power: 130, cadence: 60, cadenceMeasured: true),
                      LegacySample(time: 1, latitude: nil, longitude: nil, altitude: nil, distance: 5, speed: nil, power: nil, cadence: nil, cadenceMeasured: false)]
        let new = try keys(of: try plist(samples))
        #expect(new == (try keys(of: try plist(legacy))))
        #expect(!new.contains("heartRate") && !new.contains("temperature"))
    }

    @Test("Heart rate and temperature survive the round trip")
    func roundTrip() throws {
        let samples = [RideSample(time: 0, power: 100, heartRate: 142, temperature: 14.5), RideSample(time: 1, heartRate: nil, temperature: -2)]
        let decoded = try PropertyListDecoder().decode([RideSample].self, from: try plist(samples))
        #expect(decoded == samples)
        #expect(decoded[0].heartRate == 142 && decoded[0].temperature == 14.5 && decoded[1].temperature == -2)
    }

    @Test("A ride imported from a FIT file has the old values and the new fields empty")
    func fitRideUnchanged() throws {
        let container = try memoryContainer()
        let library = RideLibrary(context: container.mainContext)
        let result = library.importFile(data: try Fixture.data("reinheim-rundfahrt"), fileName: "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit")
        guard case .imported(let id) = result.outcome, let ride = library.ride(withID: id) else {
            Issue.record("Import failed")
            return
        }
        #expect(ride.sourceFormat == "fit")
        #expect(ride.source == .fit)
        #expect(!ride.summaryEstimatedFromGPS)
        #expect(ride.attachedSourceName == nil && ride.attachedSourceFormat == nil)
        #expect(ride.samples.count > 2900)
        #expect(ride.samples.allSatisfy { $0.heartRate == nil && $0.temperature == nil })
        #expect(try keys(of: try #require(ride.samplesData)).isDisjoint(with: ["heartRate", "temperature"]))
    }

    @Test("A ride made before has the new fields at their defaults")
    func newRideDefaults() {
        let ride = Ride(name: "Old", startDate: .now)
        #expect(ride.sourceFormat == "")
        #expect(ride.source == nil)
        #expect(!ride.summaryEstimatedFromGPS)
        #expect(ride.attachedSourceName == nil && ride.attachedSourceFormat == nil)
    }

    @Test("Source kind and the extra source are stored with the ride")
    func storesSourceFields() throws {
        let container = try memoryContainer()
        let ride = Ride(name: "Track", startDate: .now)
        ride.sourceFormat = "gpx"
        ride.summaryEstimatedFromGPS = true
        ride.attachedSourceName = "Track.gpx"
        ride.attachedSourceFormat = "gpx"
        container.mainContext.insert(ride)
        try container.mainContext.save()
        let fetched = try #require(try container.mainContext.fetch(FetchDescriptor<Ride>()).first)
        #expect(fetched.source == .gpx)
        #expect(fetched.summaryEstimatedFromGPS)
        #expect(fetched.attachedSourceName == "Track.gpx" && fetched.attachedSourceFormat == "gpx")
    }

    @Test("File extensions map to a source regardless of case", arguments: [
        ("fit", RideSource.fit), ("FIT", .fit), ("gpx", .gpx), ("GPX", .gpx),
    ])
    func sourceFromExtension(ext: String, expected: RideSource) {
        #expect(RideSource(fileExtension: ext) == expected)
    }

    @Test("Other extensions are no source")
    func unknownExtension() {
        #expect(RideSource(fileExtension: "tcx") == nil)
        #expect(RideSource(fileExtension: "") == nil)
    }
}
