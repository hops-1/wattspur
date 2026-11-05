import Foundation
import Testing
@testable import WattspurCore

@Suite("Height from barometer and GPS")
struct AltitudeFusionTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// GPS noise of up to ±4 m that repeats in every run.
    static func noise(_ second: Int) -> Double {
        var x = UInt64(second &* 2_654_435_761 &+ 1)
        x ^= x >> 13; x = x &* 0x5bd1e995; x ^= x >> 15
        return Double(x % 8001) / 1000 - 4
    }

    /// Ascent counted from 2 m on, like the GPX summary (B-234).
    static func ascent(_ heights: [Double]) -> Double {
        guard var reference = heights.first else { return 0 }
        var up = 0.0
        for height in heights.dropFirst() {
            if height - reference >= 2 { up += height - reference; reference = height }
            else if reference - height >= 2 { reference = height }
        }
        return up
    }

    @Test("Over a hill the height follows the barometer at the level of the GPS, without the GPS noise")
    func hill() {
        var fusion = AltitudeFusion()
        var fused: [Double] = [], gpsOnly: [Double] = [], truth: [Double] = []
        for second in 0..<1800 {
            // 50 m up in the first half, down again in the second.
            let height = 150 + 50 * sin(Double(second) / 1800 * .pi)
            let gps = height + Self.noise(second)
            let value = fusion.altitude(gps: gps, verticalAccuracy: 5, barometer: height - 150,
                                        at: Self.start.addingTimeInterval(Double(second)))
            fused.append(value ?? .nan)
            gpsOnly.append(gps)
            truth.append(height)
        }
        let worst = zip(fused, truth).dropFirst(10).map { abs($0 - $1) }.max() ?? .infinity
        #expect(worst < 2)
        #expect(abs(Self.ascent(fused) - 50) < 3)
        // The GPS alone counts its noise as climbing.
        #expect(Self.ascent(gpsOnly) > 70)
    }

    @Test("The weather moving the barometer by 8 m in an hour is taken out by the GPS")
    func weather() throws {
        var fusion = AltitudeFusion()
        var last: Double?
        for second in 0..<3600 {
            let drift = 8 * Double(second) / 3600
            last = fusion.altitude(gps: 200 + Self.noise(second), verticalAccuracy: 5, barometer: drift,
                                   at: Self.start.addingTimeInterval(Double(second)))
        }
        let height = try #require(last)
        #expect(abs(height - 200) < 2)
    }

    @Test("Without a barometer the GPS height is used, as before")
    func withoutBarometer() {
        var fusion = AltitudeFusion()
        #expect(fusion.altitude(gps: 123, verticalAccuracy: 5, barometer: nil, at: Self.start) == 123)
        #expect(fusion.altitude(gps: nil, verticalAccuracy: -1, barometer: nil, at: Self.start) == nil)
    }

    @Test("Inaccurate GPS heights do not set the level; until a good one comes the GPS height stays")
    func inaccurateGPS() {
        var fusion = AltitudeFusion()
        #expect(fusion.altitude(gps: 300, verticalAccuracy: 40, barometer: 0, at: Self.start) == 300)
        #expect(fusion.offset == nil)
        #expect(fusion.altitude(gps: 180, verticalAccuracy: 5, barometer: 1, at: Self.start.addingTimeInterval(1)) == 180)
        #expect(fusion.offset == 179)
        // Without GPS height for a moment the barometer carries on at the level found.
        #expect(fusion.altitude(gps: nil, verticalAccuracy: -1, barometer: 3, at: Self.start.addingTimeInterval(2)) == 182)
    }
}
