import Foundation
import Testing
import TestFixtures
@testable import WattspurCore

@Suite("Route by elevation")
struct RouteElevationTests {
    /// One sample per second along a line, with the given heights.
    private func samples(_ heights: [Double?]) -> [RideSample] {
        heights.enumerated().map { index, height in
            RideSample(time: Double(index), latitude: 50 + Double(index) * 0.0001, longitude: 8, altitude: height)
        }
    }

    @Test("Lowest point is step 0, highest is the last step, and the scale says the heights")
    func lowAndHigh() throws {
        let result = try #require(RouteElevation.stretches(samples([100, 100, 150, 200, 200])))
        #expect(result.scale.lowest == 100)
        #expect(result.scale.highest == 200)
        #expect(result.stretches.first?.band == 0)
        #expect(result.stretches.last?.band == RouteElevation.levels - 1)
        // The pieces join: each starts where the one before ends.
        for (a, b) in zip(result.stretches, result.stretches.dropFirst()) {
            #expect(a.latitude.last == b.latitude.first)
        }
    }

    @Test("A flat ride does not run through all colours")
    func flatRide() throws {
        let result = try #require(RouteElevation.stretches(samples([100, 102, 99, 101, 100])))
        #expect(result.scale.high - result.scale.low == RouteElevation.minimumRange)
        let bands = Set(result.stretches.compactMap(\.band))
        #expect(bands.allSatisfy { (2...5).contains($0) })
    }

    @Test("Samples without a height are a grey piece; without any height there is nothing")
    func gaps() throws {
        let result = try #require(RouteElevation.stretches(samples([100, 100, nil, nil, 300, 300])))
        #expect(result.stretches.contains { $0.band == nil })
        #expect(RouteElevation.stretches(samples([nil, nil, nil])) == nil)
    }

    @Test("A pause breaks the route like the other colourings")
    func pause() throws {
        var list = samples([100, 100, 100, 100])
        for index in 2..<4 { list[index].time += 60 }
        let result = try #require(RouteElevation.stretches(list))
        #expect(result.stretches.count == 2)
    }

    @Test("The sample ride goes from blue to red")
    func sampleRide() throws {
        let ride = try FITRideImporter().parse(Fixture.data("reinheim-rundfahrt"))
        let result = try #require(RouteElevation.stretches(ride.samples))
        #expect(Set(result.stretches.compactMap(\.band)).count == RouteElevation.levels)
        #expect(result.scale.highest > result.scale.lowest + 50)
    }

    @Test("From the route of the iPhone, with its segments apart")
    func fromRoute() throws {
        let route = RideExchange.Route(rideID: UUID(), segments: [
            .init(latitude: [50, 50.001, 50.002], longitude: [8, 8, 8], altitude: [100, 120, 140], distance: [0, 110, 220]),
            .init(latitude: [50.01, 50.011], longitude: [8, 8], altitude: [nil, 300], distance: [1000, 1110]),
        ])
        let result = try #require(RouteElevation.stretches(route))
        #expect(result.scale.lowest == 100)
        #expect(result.scale.highest == 300)
        // No piece runs from the first segment into the second.
        #expect(result.stretches.allSatisfy { ($0.latitude.max() ?? 0) < 50.005 || ($0.latitude.min() ?? 0) > 50.005 })
    }
}
