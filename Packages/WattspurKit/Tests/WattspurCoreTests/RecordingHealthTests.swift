import Foundation
import Testing
@testable import WattspurCore

@Suite("The recording's health log (B-369)")
struct RecordingHealthTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let device = RecordingHealth.Device(cpuSeconds: 12, footprintMB: 210, thermal: 1, isVisible: false, lowPower: false)

    @Test("One line a minute: positions, the largest delay, missing barometer, CPU and memory")
    func minute() throws {
        var health = RecordingHealth(start: Self.start, cpuSeconds: 0)
        for second in 1...59 {
            let now = Self.start.addingTimeInterval(Double(second))
            health.position(measured: now.addingTimeInterval(second == 30 ? -42 : -1), handled: now, hasBarometer: second != 5)
            #expect(!health.isDue(at: now))
        }
        let now = Self.start.addingTimeInterval(60)
        #expect(health.isDue(at: now))
        let line = health.line(at: now, device: Self.device)
        let fields = line.split(separator: ",").map(String.init)
        #expect(fields.count == RecordingHealth.header.split(separator: ",").count)
        #expect(Array(fields.dropFirst()) == ["60", "0", "59", "42.0", "1", "20", "210", "1", "0"])
        #expect(!health.isDue(at: now.addingTimeInterval(59)))
        // The next minute starts at zero.
        let next = health.line(at: now.addingTimeInterval(60), device: Self.device).split(separator: ",").map(String.init)
        #expect(Array(next.dropFirst().prefix(6)) == ["60", "0", "0", "0.0", "0", "0"])
    }

    @Test("The log has no column for a place")
    func noPlaces() {
        let header = RecordingHealth.header.lowercased()
        for word in ["lat", "lon", "course", "altitude", "name"] { #expect(!header.contains(word)) }
    }
}
