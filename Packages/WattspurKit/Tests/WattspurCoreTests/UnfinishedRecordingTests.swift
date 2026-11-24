import Foundation
import Testing
@testable import WattspurCore

/// A recording found at launch after iOS ended the app (B-383). All tracks here are made up.
@Suite("Unfinished recording")
struct UnfinishedRecordingTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A position `metres` north of the start, `seconds` after it, at `speed` m/s.
    static func fix(_ seconds: Double, north metres: Double, speed: Double = 8) -> RideRecording.Fix {
        RideRecording.Fix(date: start.addingTimeInterval(seconds), latitude: 49.8 + metres / 111_195,
                          longitude: 8.8, altitude: 100, horizontalAccuracy: 5, speed: speed)
    }

    /// Ten minutes north at 8 m/s, one position a second.
    static func ride() -> RideRecording {
        var recording = RideRecording(startDate: start, device: .without(.bike))
        for second in 0...600 { recording.add(fix(Double(second), north: Double(second) * 8)) }
        return recording
    }

    @Test("Ended by iOS a few minutes ago: the ride goes on by itself")
    func fresh() {
        let ride = Self.ride()
        let lastFix = Self.start.addingTimeInterval(600)
        #expect(UnfinishedRecording.choice(for: ride, lastWritten: lastFix, now: lastFix.addingTimeInterval(60)) == .continueByItself)
        #expect(UnfinishedRecording.choice(for: ride, lastWritten: lastFix,
                                           now: lastFix.addingTimeInterval(UnfinishedRecording.resumeWindow)) == .continueByItself)
    }

    @Test("Older than the window: the rider is asked, as before")
    func old() {
        let lastFix = Self.start.addingTimeInterval(600)
        let now = lastFix.addingTimeInterval(UnfinishedRecording.resumeWindow + 1)
        #expect(UnfinishedRecording.choice(for: Self.ride(), lastWritten: lastFix, now: now) == .ask)
        // Hours later, the next morning.
        #expect(UnfinishedRecording.choice(for: Self.ride(), lastWritten: lastFix, now: lastFix.addingTimeInterval(12 * 3600)) == .ask)
    }

    @Test("Without the file's date the last position counts; the newest sign of the ride wins")
    func lastActivity() {
        let ride = Self.ride()
        let lastFix = Self.start.addingTimeInterval(600)
        #expect(UnfinishedRecording.lastActivity(of: ride, lastWritten: nil) == lastFix)
        #expect(UnfinishedRecording.lastActivity(of: ride, lastWritten: lastFix.addingTimeInterval(90)) == lastFix.addingTimeInterval(90))
        // An older file date (copied, restored) does not make the ride older than its last position.
        #expect(UnfinishedRecording.lastActivity(of: ride, lastWritten: Self.start) == lastFix)
        #expect(UnfinishedRecording.choice(for: ride, lastWritten: nil, now: lastFix.addingTimeInterval(120)) == .continueByItself)
        // No position yet: the start counts.
        let empty = RideRecording(startDate: Self.start)
        #expect(UnfinishedRecording.lastActivity(of: empty, lastWritten: nil) == Self.start)
        #expect(UnfinishedRecording.choice(for: empty, lastWritten: nil, now: Self.start.addingTimeInterval(30)) == .continueByItself)
    }

    @Test("A paused ride counts from the pause, when the log was written last, and stays paused")
    func paused() throws {
        var data = RecordingLog.line(.start(Self.start))
        data += RecordingLog.line(.device(.without(.bike)))
        for second in 0...60 { data += RecordingLog.line(.fix(Self.fix(Double(second), north: Double(second) * 8))) }
        data += RecordingLog.line(.pause)
        let ride = try #require(RecordingLog.replay(data))
        #expect(ride.isPaused)
        let pausedAt = Self.start.addingTimeInterval(65)
        #expect(UnfinishedRecording.choice(for: ride, lastWritten: pausedAt, now: pausedAt.addingTimeInterval(600)) == .continueByItself)
        #expect(UnfinishedRecording.choice(for: ride, lastWritten: pausedAt, now: pausedAt.addingTimeInterval(3600)) == .ask)
    }

    @Test("Still waiting for the vehicle to move: nothing to continue")
    func ready() {
        var recording = RideRecording(startDate: Self.start, device: .without(.car))
        recording.waitForMovement()
        #expect(UnfinishedRecording.choice(for: recording, lastWritten: Self.start, now: Self.start.addingTimeInterval(10)) == .discard)
    }

    @Test("An auto-started ride keeps that mark through the log, so it can still end by itself")
    func startedReady() throws {
        var data = RecordingLog.line(.start(Self.start))
        data += RecordingLog.line(.device(.without(.car)))
        data += RecordingLog.line(.ready)
        data += RecordingLog.line(.fix(Self.fix(30, north: 20, speed: 8)))
        data += RecordingLog.line(.fix(Self.fix(31, north: 28, speed: 8)))
        let riding = try #require(RecordingLog.replay(data))
        #expect(!riding.isReady)
        #expect(riding.startedReady)
        #expect(!Self.ride().startedReady)
        // Saved as JSON and read back, the mark stays; older JSON without it reads as not auto-started.
        let json = try JSONEncoder().encode(riding)
        #expect(try JSONDecoder().decode(RideRecording.self, from: json).startedReady)
        let old = try JSONEncoder().encode(Self.ride())
        #expect(try !JSONDecoder().decode(RideRecording.self, from: old).startedReady)
    }

    @Test("Continued without a pause: the positions iOS hands over later join the ride")
    func gapWithoutPause() throws {
        var data = RecordingLog.line(.start(Self.start))
        data += RecordingLog.line(.device(.without(.bike)))
        for second in 0...60 { data += RecordingLog.line(.fix(Self.fix(Double(second), north: Double(second) * 8))) }
        var ride = try #require(RecordingLog.replay(data))
        let before = ride.distance
        // Two minutes without positions, then the ones iOS kept, on along the same road.
        let first = ride.add(Self.fix(180, north: 180 * 8))
        let second = ride.add(Self.fix(181, north: 181 * 8))
        #expect(first && second)
        #expect(ride.segments.count == 1)
        #expect(ride.distance > before + 900)
        // Far away after the gap (more than 2 km): a new stretch without a line, no jump in distance (B-309).
        let far = ride.add(Self.fix(600, north: 181 * 8 + 3000))
        #expect(far)
        #expect(ride.segments.count == 2)
        #expect(ride.distance < before + 1200)
    }
}
