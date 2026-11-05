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
            // No height until the level is found, so no jump at the start.
            if second < AltitudeFusion.anchorCount - 1 { #expect(value == nil) }
            guard let value else { continue }
            fused.append(value)
            gpsOnly.append(gps)
            truth.append(height)
        }
        let worst = zip(fused, truth).map { abs($0 - $1) }.max() ?? .infinity
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

    @Test("Inaccurate GPS heights do not set the level; until it is found there is no height")
    func inaccurateGPS() {
        var fusion = AltitudeFusion()
        #expect(fusion.altitude(gps: 300, verticalAccuracy: 40, barometer: 0, at: Self.start) == nil)
        #expect(fusion.altitude(gps: 180, verticalAccuracy: 5, barometer: 1, at: Self.start.addingTimeInterval(1)) == nil)
        #expect(fusion.offset == nil)
        // With fewer than five good heights the level is set after the timeout.
        let later = Self.start.addingTimeInterval(1 + AltitudeFusion.anchorTimeout)
        #expect(fusion.altitude(gps: nil, verticalAccuracy: -1, barometer: 3, at: later) == 182)
        #expect(fusion.offset == 179)
    }

    @Test("At a standstill the first seconds give no climb (iPhone test 5.11.2026)")
    func standstill() {
        // GPS heights of 51 s in the office, one per second; the barometer stays at the start.
        let gps = [176.7, 176.7, 176.7, 180.6, 180.6, 181.8, 182.1, 182.1, 182.1, 182.2, 182.4, 182.4]
            + Array(repeating: 182.5, count: 26)
        var fusion = AltitudeFusion()
        let heights = gps.indices.compactMap { second in
            fusion.altitude(gps: gps[second], verticalAccuracy: 8, barometer: 0.1 * sin(Double(second)),
                            at: Self.start.addingTimeInterval(Double(second)))
        }
        #expect(heights.count == gps.count - (AltitudeFusion.anchorCount - 1))
        #expect((heights.max() ?? 0) - (heights.min() ?? 0) < 1)
        #expect(Self.ascent(heights) == 0)
        // Before, the first height was 176.7 m and the start counted almost 4 m of climb.
        #expect(Self.ascent(gps) > 3)
    }

    @Test("With a barometer expected, the first seconds wait for it instead of taking the GPS height")
    func waitsForBarometer() {
        var fusion = AltitudeFusion()
        fusion.waitsForBarometer = true
        #expect(fusion.altitude(gps: 177.2, verticalAccuracy: 5, barometer: nil, at: Self.start) == nil)
        // If it does not come, the GPS height stands in after the wait.
        let late = Self.start.addingTimeInterval(AltitudeFusion.barometerWait)
        #expect(fusion.altitude(gps: 177.2, verticalAccuracy: 5, barometer: nil, at: late) == 177.2)
    }
}
