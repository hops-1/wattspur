import Foundation
import Testing
@testable import WattspurCore

@Suite("Profile while recording")
struct RecordingProfileTests {
    /// A recording north at 6 m/s for `seconds`, climbing 1 m every 10 s.
    private func recording(seconds: Int) -> RideRecording {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var recording = RideRecording(startDate: start)
        for second in 0...seconds {
            recording.add(RideRecording.Fix(date: start.addingTimeInterval(Double(second)),
                                            latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8,
                                            altitude: 150 + Double(second) / 10, horizontalAccuracy: 5, speed: 6))
        }
        return recording
    }

    @Test("Height grows along the distance, speed stays")
    func values() {
        let ride = recording(seconds: 600)
        let heights = RecordingProfile.points(ride, kind: .elevation)
        #expect(heights.count > 100)
        #expect(heights.first!.value < heights.last!.value)
        #expect(zip(heights, heights.dropFirst()).allSatisfy { $0.distance < $1.distance })
        let speeds = RecordingProfile.points(ride, kind: .speed)
        #expect(speeds.allSatisfy { abs($0.value - 6) < 0.01 })
    }

    @Test("No values yet, no profile")
    func empty() {
        let ride = RideRecording(startDate: .now)
        #expect(RecordingProfile.points(ride, kind: .elevation).isEmpty)
    }

    @Test("Two hours stay small and quick")
    func longRide() {
        let ride = recording(seconds: 7_200)
        let clock = ContinuousClock()
        var points: [RecordingProfile.Point] = []
        let elapsed = clock.measure { points = RecordingProfile.points(ride, kind: .elevation) }
        #expect(points.count <= RecordingProfile.defaultBins)
        // Once a second on the recording screen; far below that even in a debug build.
        #expect(elapsed < .milliseconds(50))
    }
}
