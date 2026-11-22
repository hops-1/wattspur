import Foundation
import Testing
@testable import WattspurCore

@Suite("Barometer readings by the time they were measured (B-369)")
struct BarometerHistoryTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static func at(_ second: Double) -> Date { start.addingTimeInterval(second) }

    static func history(seconds: Range<Int>) -> BarometerHistory {
        var history = BarometerHistory()
        for second in seconds { history.add(metres: Double(second), at: at(Double(second))) }
        return history
    }

    @Test("A GPS position handled minutes late finds the reading of its own second")
    func late() {
        let history = Self.history(seconds: 0..<600)
        #expect(history.metres(at: Self.at(40.2)) == 40)
        #expect(history.metres(at: Self.at(320.7)) == 321)
        #expect(history.metres(at: Self.at(599)) == 599)
    }

    @Test("Further away than five seconds from any reading there is none")
    func gap() {
        var history = Self.history(seconds: 0..<10)
        history.add(metres: 60, at: Self.at(60))
        #expect(history.metres(at: Self.at(13)) == 9)
        #expect(history.metres(at: Self.at(30)) == nil)
        #expect(history.metres(at: Self.at(56)) == 60)
        #expect(history.metres(at: Self.at(70)) == nil)
        #expect(BarometerHistory().metres(at: Self.start) == nil)
    }

    @Test("Old readings go, so an all-day ride stays small")
    func bounded() {
        let history = Self.history(seconds: 0..<30_000)
        #expect(history.count <= Int(BarometerHistory.span) * 2 + 2)
        #expect(history.metres(at: Self.at(29_999 - BarometerHistory.span + 1)) != nil)
        #expect(history.metres(at: Self.at(10)) == nil)
    }

    @Test("A reading out of order is sorted in")
    func outOfOrder() {
        var history = Self.history(seconds: 0..<3)
        history.add(metres: 20, at: Self.at(20))
        history.add(metres: 10, at: Self.at(10))
        #expect(history.metres(at: Self.at(11)) == 10)
        #expect(history.metres(at: Self.at(20)) == 20)
    }

    @Test("Eight seconds late, as on the bike tour of 22.11.2026: every position keeps its height")
    func lateFusion() {
        var history = BarometerHistory()
        var fusion = AltitudeFusion()
        var missing = 0
        for now in 0..<700 {
            history.add(metres: Double(now) / 10, at: Self.at(Double(now)))
            let measured = now < 50 ? now : now - 8
            let date = Self.at(Double(measured))
            let value = fusion.altitude(gps: 200 + Double(measured) / 10, verticalAccuracy: 5,
                                        barometer: history.metres(at: date), at: date)
            if now >= 10, value == nil { missing += 1 }
        }
        #expect(missing == 0)
    }
}
