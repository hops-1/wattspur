import Foundation
import Testing
@testable import WattspurCore

@Suite("What reaches the screen while recording (B-369)")
struct RecordingDisplayTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    static func fix(_ second: Int, speed: Double = 6) -> RideRecording.Fix {
        RideRecording.Fix(date: start.addingTimeInterval(Double(second)), latitude: 10 + Double(second) * 6 / 111_195,
                          longitude: 20, altitude: nil, horizontalAccuracy: 5, speed: speed)
    }

    @Test("Hidden, new positions do not reach the screen; in front each one does")
    func positions() {
        var recording = RideRecording(startDate: Self.start)
        recording.add(Self.fix(1))
        let shown = recording
        recording.add(Self.fix(2))
        #expect(!RecordingDisplay.publishes(recording, over: shown, isVisible: false))
        #expect(RecordingDisplay.publishes(recording, over: shown, isVisible: true))
    }

    @Test("Start, end, pause and resume reach the screen also while it is hidden")
    func changes() {
        var recording = RideRecording(startDate: Self.start)
        #expect(RecordingDisplay.publishes(recording, over: nil, isVisible: false))
        #expect(RecordingDisplay.publishes(nil, over: recording, isVisible: false))
        #expect(!RecordingDisplay.publishes(nil, over: nil, isVisible: false))
        let running = recording
        recording.pause()
        #expect(RecordingDisplay.publishes(recording, over: running, isVisible: false))
        let paused = recording
        recording.resume()
        #expect(RecordingDisplay.publishes(recording, over: paused, isVisible: false))
    }

    @Test("The ride that begins after Ready reaches the screen while it is hidden (B-311)")
    func ready() {
        var recording = RideRecording(startDate: Self.start)
        recording.waitForMovement()
        let ready = recording
        let began = recording.add(Self.fix(30))
        #expect(began)
        #expect(RecordingDisplay.publishes(recording, over: ready, isVisible: false))
    }
}
