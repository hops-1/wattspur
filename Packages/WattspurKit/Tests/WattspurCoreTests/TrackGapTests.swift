import Foundation
import Testing
@testable import WattspurCore

/// Issue #164 (B-309): by bike to the station, by train without recording, by bike home.
/// Invented tracks only, no personal ride files.
@Suite("Gaps in a track")
struct TrackGapTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    /// Metres per degree of latitude.
    static let metresPerDegree = 111_195.0

    /// A sample `metres` north of the start, `seconds` after it.
    static func sample(_ seconds: Double, north metres: Double) -> RideSample {
        RideSample(time: seconds, latitude: 49.8 + metres / metresPerDegree, longitude: 8.8, altitude: 150)
    }

    /// 10 min by bike north at 5 m/s, 20 min by train 25 km further without positions,
    /// then 10 min by bike again.
    static var trainRide: [RideSample] {
        let there = (0...600).map { sample(Double($0), north: Double($0) * 5) }
        let back = (0...600).map { sample(1_800 + 600 + Double($0), north: 3_000 + 25_000 + Double($0) * 5) }
        return there + back
    }

    @Test("A step of more than 2 km is a gap, a normal step is not")
    func isGap() {
        let a = RoutePoint(latitude: 49.8, longitude: 8.8)
        #expect(!TrackGap.isGap(a, RoutePoint(latitude: 49.8 + 1_900 / Self.metresPerDegree, longitude: 8.8)))
        #expect(TrackGap.isGap(a, RoutePoint(latitude: 49.8 + 2_100 / Self.metresPerDegree, longitude: 8.8)))
    }

    @Test("The train ride from the issue splits the track in two")
    func splitsTrainRide() {
        let stretches = TrackGap.split(Self.trainRide)
        #expect(stretches.count == 2)
        #expect(stretches.map(\.count) == [601, 601])
    }

    @Test("A single GPS outlier under 2 km and samples without a position keep one stretch")
    func noGap() {
        var samples = (0...100).map { Self.sample(Double($0), north: Double($0) * 5) }
        samples[50] = Self.sample(50, north: 250 + 800)
        samples.insert(RideSample(time: 70.5), at: 70)
        #expect(TrackGap.split(samples).count == 1)
        #expect(TrackGap.split([RideSample]()).isEmpty)
    }

    @Test("A sample without a position is measured from the last one with a position")
    func withoutPosition() {
        let samples = [Self.sample(0, north: 0), RideSample(time: 1), Self.sample(2, north: 5_000)]
        #expect(TrackGap.split(samples).map(\.count) == [2, 1])
    }

    @Test("The route for the map of all rides has one segment per stretch")
    func overviewRoute() {
        let route = OverviewRoute(samples: Self.trainRide)
        #expect(route.segments.count == 2)
        let preview = RoutePreview(route: route)
        #expect(preview?.segments.count == 2)
    }

    @Test("The GPX export starts a new segment at the gap, and the import counts no distance across it")
    func gpxRoundTrip() throws {
        let data = GPXWriter.document(name: "Train", segments: [GPXWriter.Segment(startDate: Self.start, samples: Self.trainRide)])
        let xml = String(decoding: data, as: UTF8.self)
        #expect(xml.components(separatedBy: "<trkseg>").count - 1 == 2)
        let ride = try GPXRideImporter().parse(data)
        // 2 × 3 km by bike, not the 25 km of the train.
        #expect(abs(ride.summary.distance - 6_000) < 100)
    }

    @Test("Recording on: off the train the iPhone starts a new stretch without the jump in distance")
    func recording() {
        var recording = RideRecording(startDate: Self.start)
        func fix(_ seconds: Double, north metres: Double) -> RideRecording.Fix {
            RideRecording.Fix(date: Self.start.addingTimeInterval(seconds), latitude: 49.8 + metres / Self.metresPerDegree,
                              longitude: 8.8, altitude: 150, horizontalAccuracy: 5)
        }
        for second in 0...600 { recording.add(fix(Double(second), north: Double(second) * 5)) }
        // In the train no positions arrive (the app is asleep), then 25 km further on.
        var kept = 0
        for second in 0...600 where recording.add(fix(2_400 + Double(second), north: 28_000 + Double(second) * 5)) {
            kept += 1
        }
        #expect(kept == 601)
        #expect(recording.segments.count == 2)
        #expect(abs(recording.distance - 6_000) < 50)
        #expect(recording.gpxSegments.count == 2)
    }
}
