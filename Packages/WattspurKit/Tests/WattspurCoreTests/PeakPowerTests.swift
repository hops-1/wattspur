import Foundation
import Testing
@testable import WattspurCore

@Suite("Best minute of power")
struct PeakPowerTests {
    /// One record per second with the given powers, starting at `start`.
    private func seconds(_ powers: [Int?], start: Double = 0) -> [RideSample] {
        powers.enumerated().map { RideSample(time: start + Double($0.offset), power: $0.element) }
    }

    @Test("A steady 200 W for two minutes is 200 W")
    func steady() {
        #expect(PeakPower.bestAverage(of: seconds(Array(repeating: 200, count: 121))) == 200)
    }

    @Test("The best minute is found inside a longer ride")
    func bestMinute() {
        // 5 minutes at 100 W, 1 minute at 300 W, 5 minutes at 100 W.
        let powers = Array(repeating: 100, count: 300) + Array(repeating: 300, count: 61) + Array(repeating: 100, count: 300)
        #expect(PeakPower.bestAverage(of: seconds(powers)) == 300)
        // Ten seconds less at 300 W: each record holds until the next, so 51 records are 51 s of
        // 300 W; the best 60 s hold those and 9 s of 100 W.
        let short = Array(repeating: 100, count: 300) + Array(repeating: 300, count: 51) + Array(repeating: 100, count: 300)
        #expect(PeakPower.bestAverage(of: seconds(short)) == 270) // (51 × 300 + 9 × 100) / 60
    }

    @Test("Under a minute there is no value")
    func tooShort() {
        #expect(PeakPower.bestAverage(of: seconds(Array(repeating: 500, count: 60))) == nil) // 59 s
        #expect(PeakPower.bestAverage(of: seconds(Array(repeating: 500, count: 61))) == 500)
        #expect(PeakPower.bestAverage(of: []) == nil)
    }

    @Test("A ride without power values (a GPX file) has none")
    func noPower() {
        #expect(PeakPower.bestAverage(of: seconds(Array(repeating: nil, count: 300))) == nil)
    }

    @Test("A stretch never spans a pause or a record without power")
    func gaps() {
        // 40 s at 400 W, a pause of 20 s, 40 s at 400 W: no minute without a break.
        let split = seconds(Array(repeating: 400, count: 41)) + seconds(Array(repeating: 400, count: 41), start: 61)
        #expect(PeakPower.bestAverage(of: split) == nil)
        // A record without power in the middle breaks the run.
        var broken = seconds(Array(repeating: 400, count: 100))
        broken[50].power = nil
        #expect(PeakPower.bestAverage(of: broken) == nil)
        // The other minute is long enough.
        let second = seconds(Array(repeating: 150, count: 61), start: 200)
        #expect(PeakPower.bestAverage(of: seconds(Array(repeating: 400, count: 41)) + second) == 150)
    }

    @Test("Uneven spacing is weighted by time")
    func uneven() {
        // Every 2 s: 100 W for 30 s then 300 W for 90 s; the best minute is entirely 300 W.
        let samples = stride(from: 0.0, through: 120, by: 2).map { RideSample(time: $0, power: $0 < 30 ? 100 : 300) }
        #expect(PeakPower.bestAverage(of: samples) == 300)
    }
}
