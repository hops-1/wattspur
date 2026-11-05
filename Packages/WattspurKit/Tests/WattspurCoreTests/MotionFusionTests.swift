import Foundation
import Testing
@testable import WattspurCore

@Suite("Lean angle, acceleration and roughness from the motion sensors")
struct MotionFusionTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    /// The iPhone tilted back by 40° in the mount, so it can be read: gravity in its own frame.
    static let tilt = 40.0 * .pi / 180
    static let gravity = (x: 0.0, y: -cos(tilt), z: -sin(tilt))
    static let up = (x: -gravity.x, y: -gravity.y, z: -gravity.z)
    /// The way ahead in the iPhone's frame, level with the road.
    static let forward = (x: 1.0, y: 0.0, z: 0.0)

    /// Readings at 50 Hz for `seconds`, with a turn rate (rad/s, positive = left) about the vertical,
    /// an acceleration along the way and a shake up and down, all in g.
    static func readings(from: TimeInterval, seconds: Double, turn: Double = 0, along: Double = 0,
                         shake: (Double) -> Double = { _ in 0 }) -> [MotionFusion.Reading] {
        (0..<Int(seconds * 50)).map { i in
            let t = from + Double(i) / 50
            let s = shake(t)
            return MotionFusion.Reading(
                date: start.addingTimeInterval(t), quaternion: (0, 0, 0, 1), gravity: gravity,
                acceleration: (along * forward.x + s * up.x, along * forward.y + s * up.y, along * forward.z + s * up.z),
                rotation: (turn * up.x, turn * up.y, turn * up.z))
        }
    }

    /// Rides the given seconds, one GPS point a second with the speeds given, and returns the values.
    static func ride(speeds: [Double], turn: Double = 0, along: Double = 0,
                     shake: (Double) -> Double = { _ in 0 }) -> [MotionValues?] {
        var fusion = MotionFusion()
        var values: [MotionValues?] = []
        _ = fusion.close(at: start, speed: speeds[0])
        for (second, speed) in speeds.enumerated().dropFirst() {
            for reading in readings(from: Double(second - 1), seconds: 1, turn: turn, along: along, shake: shake) {
                fusion.add(reading)
            }
            values.append(fusion.close(at: start.addingTimeInterval(Double(second)), speed: speed))
        }
        return values
    }

    @Test("A steady left turn gives the lean angle from speed and turn rate, whatever the tilt of the iPhone")
    func leftTurn() throws {
        // 72 km/h and 0.5 rad/s: tan(lean) = 20 · 0.5 / 9.81, about 45.6°.
        let values = Self.ride(speeds: Array(repeating: 20, count: 6), turn: 0.5)
        let last = try #require(values.last ?? nil)
        #expect(abs(last.lean - 45.55) < 0.3)
    }

    @Test("A right turn leans the other way")
    func rightTurn() throws {
        let values = Self.ride(speeds: Array(repeating: 15, count: 6), turn: -0.4)
        let last = try #require(values.last ?? nil)
        #expect(last.lean < -30)
        #expect(abs(last.lean - -31.46) < 0.3)
    }

    @Test("Slower than 10 km/h there is no lean angle")
    func tooSlow() throws {
        let values = Self.ride(speeds: Array(repeating: 2, count: 4), turn: 3)
        for value in values {
            #expect(try #require(value).lean == 0)
        }
    }

    @Test("Braking hard on a straight road")
    func braking() throws {
        // From 72 to 67 km/h every second: about −0.14 g; the sensors feel −0.4 g.
        let speeds = (0..<6).map { 20 - 1.4 * Double($0) }
        let values = Self.ride(speeds: speeds, along: -0.4)
        let last = try #require(values.last ?? nil)
        let acceleration = try #require(last.acceleration)
        #expect(abs(acceleration - -0.4) < 0.02)
        #expect(last.lean == 0)
    }

    @Test("Speeding up is positive, a steady ride is about 0")
    func speedingUpAndSteady() throws {
        let faster = Self.ride(speeds: (0..<6).map { 5 + 2 * Double($0) }, along: 0.25)
        #expect(abs(try #require(faster.last??.acceleration) - 0.25) < 0.02)
        let steady = Self.ride(speeds: Array(repeating: 12, count: 6))
        #expect(abs(try #require(steady.last??.acceleration)) < 0.01)
    }

    @Test("The acceleration of the turn itself does not count as speeding up")
    func turnIsNotAcceleration() throws {
        // In a turn the iPhone feels v · ω sideways; at a steady speed nothing is along the way.
        var fusion = MotionFusion()
        _ = fusion.close(at: Self.start, speed: 15)
        var last: MotionValues?
        for second in 1...5 {
            for var reading in Self.readings(from: Double(second - 1), seconds: 1, turn: 0.3) {
                let sideways = 15 * 0.3 / MotionFusion.gravity
                // Sideways is level and across the way: z × up gives such a direction here.
                reading.acceleration = (0, sideways * Self.up.z, -sideways * Self.up.y)
                fusion.add(reading)
            }
            last = fusion.close(at: Self.start.addingTimeInterval(Double(second)), speed: 15)
        }
        let value = try #require(last)
        #expect(abs(try #require(value.acceleration)) < 0.01)
        #expect(value.lean > 20)
    }

    @Test("Cobblestones shake, smooth tarmac does not")
    func roughness() throws {
        let cobbles = Self.ride(speeds: Array(repeating: 6, count: 4)) { 0.3 * sin(2 * .pi * 12 * $0) }
        let rough = try #require(cobbles.last ?? nil).roughness
        // The root mean square of a sine is its amplitude / √2; the filter keeps most of 12 Hz.
        #expect(rough > 0.17 && rough < 0.23)
        let smooth = Self.ride(speeds: Array(repeating: 6, count: 4))
        #expect(try #require(smooth.last ?? nil).roughness < 0.001)
    }

    @Test("Without readings or a valid speed there is less to say")
    func missing() {
        var fusion = MotionFusion()
        #expect(fusion.close(at: Self.start, speed: 10) == nil)
        for reading in Self.readings(from: 0, seconds: 1, turn: 0.5) { fusion.add(reading) }
        let value = fusion.close(at: Self.start.addingTimeInterval(1), speed: -1)
        #expect(value?.acceleration == nil)
        #expect(value?.lean != 0) // the speed of the point before still counts for the lean
    }

    @Test("Two intervals merge into the stronger values")
    func merged() {
        let first = MotionValues(lean: -20, acceleration: 0.1, roughness: 0.02)
        let second = MotionValues(lean: 12, acceleration: -0.5, roughness: 0.01)
        #expect(first.merged(with: second) == MotionValues(lean: -20, acceleration: -0.5, roughness: 0.02))
        #expect(first.merged(with: nil) == first)
        let noSpeed = MotionValues(lean: 0, acceleration: nil, roughness: 0.03)
        #expect(noSpeed.merged(with: first).acceleration == 0.1)
    }

    @Test("A fix with motion values survives the recording log; older lines without them still read")
    func recordingLog() throws {
        let motion = MotionValues(lean: -12.5, acceleration: 0.21, roughness: 0.04)
        let fix = RideRecording.Fix(date: Self.start, latitude: 49.8, longitude: 8.8, altitude: 170,
                                    horizontalAccuracy: 5, speed: 8, motion: motion)
        var log = RecordingLog.line(.start(Self.start))
        log.append(RecordingLog.line(.fix(fix)))
        let recording = try #require(RecordingLog.replay(log))
        #expect(recording.segments[0][0].fix.motion == motion)

        let old = #"{"fix":{"_0":{"date":1800000001000,"latitude":49.8,"longitude":8.8,"horizontalAccuracy":5}}}"#
        var oldLog = RecordingLog.line(.start(Self.start))
        oldLog.append(Data(old.utf8) + Data([0x0A]))
        let oldRecording = try #require(RecordingLog.replay(oldLog))
        #expect(oldRecording.pointCount == 1)
        #expect(oldRecording.segments[0][0].fix.motion == nil)
    }
}
