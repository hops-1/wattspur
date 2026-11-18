import Foundation
import Testing
@testable import WattspurCore

/// A car shows lateral acceleration instead of a lean angle (B-287), from the same stored values;
/// and a turned iPhone does not count as a curve. The values follow the pattern of the two car
/// rides of 9./10.11.2026 (up to 21°, that is 0.38 g; 17° on a straight road while the iPhone was
/// turned in the mount), all made up.
@Suite("Lateral acceleration in a car")
struct CarLateralTests {
    @Test("A car shows the tangent of the stored angle in g, everything else the angle")
    func sideMeasure() {
        #expect(SideMeasure(kind: .car) == .lateralAcceleration)
        for kind in [BikeKind.bike, .gravel, .cargo, .motorcycle, .runningShoe] {
            #expect(SideMeasure(kind: kind) == .leanAngle)
        }
        let lateral = SideMeasure.lateralAcceleration
        #expect(abs(lateral.value(lean: 21) - 0.3839) < 0.0005)
        #expect(abs(lateral.value(lean: -21) + 0.3839) < 0.0005)
        #expect(lateral.value(lean: 0) == 0)
        #expect(SideMeasure.leanAngle.value(lean: 21) == 21)
        #expect(lateral.unit == "g" && SideMeasure.leanAngle.unit == "°")
    }

    @Test("The figures and the sprint of a car ride")
    func carFigures() throws {
        let kmh: [Double] = [0, 30, 60, 90, 105, 100, 80, 80, 80]
        let lean: [Double?] = [0, 2, 0, -5, 0, 21, 8, -14, 0]
        let samples = RideMotionTests.samples(kmh: kmh, lean: lean)
        let car = try #require(RideMotion(samples: samples, kind: .car))
        #expect(car.side == .lateralAcceleration)
        #expect(car.maxLeanLeft == 21 && car.maxLeanRight == 14)
        #expect(abs(car.maxSideLeft - 0.384) < 0.001)
        #expect(abs(car.maxSideRight - 0.249) < 0.001)
        // A car sprints to 100 km/h like a motorcycle.
        let sprint = try #require(car.sprint)
        #expect(sprint.targetKmh == 100)
        // From 0 at 0 s to 100 between 90 at 3 s and 105 at 4 s.
        #expect(abs(sprint.seconds - 3.667) < 0.01)
        // The same ride on a motorcycle keeps the angle.
        let moto = try #require(RideMotion(samples: samples, kind: .motorcycle))
        #expect(moto.side == .leanAngle && moto.maxSideLeft == 21)
        #expect(RideMotion(samples: samples, kind: .gravel)?.sprint?.targetKmh == 25)
    }

    @Test("The track of a car is coloured in steps of 0.1 g")
    func bands() {
        #expect(RideMotion.LeanBand(lateral: 0.05) == .upright)
        #expect(RideMotion.LeanBand(lateral: 0.1) == .slight)
        #expect(RideMotion.LeanBand(lateral: -0.25) == .medium)
        #expect(RideMotion.LeanBand(lateral: 0.39) == .strong)
        #expect(RideMotion.LeanBand(lateral: 0.6) == .extreme)
        let lateral = SideMeasure.lateralAcceleration
        // 21° is 0.38 g: a strong turn for a car, a slight lean for a bike.
        #expect(lateral.band(lean: 21) == .strong)
        #expect(SideMeasure.leanAngle.band(lean: 21) == .medium)
        #expect(lateral.label(.upright) == "0.0–0.1 g" || lateral.label(.upright) == "0,0–0,1 g")
        #expect(lateral.label(.extreme).hasSuffix("g +"))
        #expect(SideMeasure.leanAngle.label(.slight) == "10–20°" && SideMeasure.leanAngle.label(.extreme) == "40° +")

        let samples = RideMotionTests.samples(kmh: [80, 80, 80, 80], lean: [0, 21, 21, 0])
        let car = RideMotion.leanStretches(samples, side: .lateralAcceleration).map(\.band)
        let bike = RideMotion.leanStretches(samples).map(\.band)
        #expect(car.contains(.strong) && !car.contains(.medium))
        #expect(bike.contains(.medium) && !bike.contains(.strong))
    }

    /// Drives `seconds` at `speed` m/s with the sensors turning `turn` rad/s about “up” and the
    /// GPS course going from `course` by `courseRate` degrees a second (clockwise), and returns the values.
    static func drive(seconds: Int, speed: Double, turn: Double, course: Double = 90, courseRate: Double = 0,
                      courseAccuracy: Double = 2) -> [MotionValues?] {
        var fusion = MotionFusion()
        let start = MotionFusionTests.start
        _ = fusion.close(at: start, speed: speed, course: course, courseAccuracy: courseAccuracy)
        var values: [MotionValues?] = []
        for second in 1...seconds {
            for reading in MotionFusionTests.readings(from: Double(second - 1), seconds: 1, turn: turn) {
                fusion.add(reading)
            }
            var heading = (course + courseRate * Double(second)).truncatingRemainder(dividingBy: 360)
            if heading < 0 { heading += 360 }
            values.append(fusion.close(at: start.addingTimeInterval(Double(second)), speed: speed,
                                       course: heading, courseAccuracy: courseAccuracy))
        }
        return values
    }

    @Test("Turning the iPhone in the mount on a straight road is no curve")
    func turnedIPhone() throws {
        // 90 km/h straight on; turning the iPhone reads as 0.12 rad/s about “up”: 17° without the check.
        let turned = Self.drive(seconds: 4, speed: 25, turn: 0.12)
        let last = try #require(turned.last ?? nil)
        #expect(last.lean == 0)
        #expect(last.roughness >= 0)
        // Without a course (no GPS course, or one that is unsure) the check cannot run.
        let unsure = try #require(Self.drive(seconds: 4, speed: 25, turn: 0.12, courseAccuracy: 25).last ?? nil)
        #expect(abs(unsure.lean - 17) < 0.5)
    }

    /// A curve of 0.15 rad/s at 36 km/h, where the iPhone is turned from upright to across between
    /// seconds 3 and 3.5 (B-325): “up” turns by 90° about the screen.
    static func turnedAcross(vehicle: RecordingVehicle, seconds: Int = 8) -> [MotionValues?] {
        var fusion = MotionFusion(vehicle: vehicle)
        let start = MotionFusionTests.start
        let (c, s) = (cos(MotionFusionTests.tilt), sin(MotionFusionTests.tilt))
        let rate = -0.15 * 180 / .pi
        _ = fusion.close(at: start, speed: 10, course: 90, courseAccuracy: 2)
        var values: [MotionValues?] = []
        for second in 1...seconds {
            for i in 0..<50 {
                let t = Double(second - 1) + Double(i) / 50
                let angle = min(max((t - 3) / 0.5, 0), 1) * .pi / 2
                let gravity = (x: c * sin(angle), y: -c * cos(angle), z: -s)
                let up = (x: -gravity.x, y: -gravity.y, z: -gravity.z)
                fusion.add(MotionFusion.Reading(date: start.addingTimeInterval(t), quaternion: (0, 0, 0, 1), gravity: gravity,
                                                acceleration: (0, 0, 0), rotation: (0.15 * up.x, 0.15 * up.y, 0.15 * up.z)))
            }
            let heading = (90 + rate * Double(second) + 360).truncatingRemainder(dividingBy: 360)
            values.append(fusion.close(at: start.addingTimeInterval(Double(second)), speed: 10, course: heading, courseAccuracy: 2))
        }
        return values
    }

    @Test("A car's iPhone turned between upright and across is no curve for a moment (B-325)")
    func turnedAcross() throws {
        let car = Self.turnedAcross(vehicle: .car).map { $0?.lean ?? .nan }
        // The curve before, nothing while the iPhone turns and settles, the curve again after.
        #expect(car[0...2].allSatisfy { $0 > 8 })
        #expect(car[3...4].allSatisfy { $0 == 0 })
        #expect(car[5...].allSatisfy { $0 > 8 })
        // A motorcycle leans with its iPhone: its curve keeps its value.
        let motorcycle = Self.turnedAcross(vehicle: .motorcycle).map { $0?.lean ?? .nan }
        #expect(motorcycle.allSatisfy { $0 > 8 })
    }

    @Test("A real curve, where the course turns with the sensors, keeps its value")
    func realCurve() throws {
        // A left turn at 0.15 rad/s: the course goes counter-clockwise by 8.6° a second.
        let left = try #require(Self.drive(seconds: 4, speed: 25, turn: 0.15, courseRate: -0.15 * 180 / .pi).last ?? nil)
        #expect(abs(left.lean - 20.9) < 0.5)
        // A right turn over north: the course goes from 5° to 355°.
        let right = try #require(Self.drive(seconds: 3, speed: 20, turn: -0.2, course: 10,
                                            courseRate: 0.2 * 180 / .pi).last ?? nil)
        #expect(right.lean < -20)
        // A course a few degrees off the sensors still counts.
        let near = try #require(Self.drive(seconds: 4, speed: 25, turn: 0.15, courseRate: -0.15 * 180 / .pi + 2).last ?? nil)
        #expect(near.lean > 20)
    }

    /// A steady curve at 85 km/h as on 17.11.2026 (B-319): the GPS course says 0.15 g, the holder
    /// sways with 20°/s at 2 Hz, the course is 2° off each second, to the one side and then the other.
    static func swayingCurve(vehicle: RecordingVehicle, seconds: Int = 20) -> [MotionValues?] {
        let speed = 85 / 3.6
        let turn = 0.15 * MotionFusion.gravity / speed // rad/s to the left
        let sway = 20 * Double.pi / 180
        var fusion = MotionFusion(vehicle: vehicle)
        let start = MotionFusionTests.start
        let g = MotionFusionTests.gravity
        let up = MotionFusionTests.up
        _ = fusion.close(at: start, speed: speed, course: 180, courseAccuracy: 2)
        var values: [MotionValues?] = []
        for second in 1...seconds {
            for i in 0..<50 {
                let t = Double(second - 1) + Double(i) / 50
                let rate = turn + sway * sin(2 * .pi * 2 * t)
                fusion.add(MotionFusion.Reading(date: start.addingTimeInterval(t), quaternion: (0, 0, 0, 1),
                                                gravity: g, acceleration: (0, 0, 0),
                                                rotation: (rate * up.x, rate * up.y, rate * up.z)))
            }
            let noise = second.isMultiple(of: 2) ? 2.0 : -2.0
            let course = 180 - turn * 180 / .pi * Double(second) + noise
            values.append(fusion.close(at: start.addingTimeInterval(Double(second)), speed: speed,
                                       course: course, courseAccuracy: 2))
        }
        return values
    }

    @Test("A car takes the mean of a second: a swaying holder at 85 km/h stays near the GPS value")
    func swayingHolder() throws {
        let lateral = SideMeasure.lateralAcceleration
        let car = try Self.swayingCurve(vehicle: .car).dropFirst().map { try #require($0) }
        // No point of the steady curve is left out as a turned iPhone.
        #expect(car.allSatisfy { $0.lean != 0 })
        // Within 30 % of the 0.15 g from the course.
        for value in car {
            #expect(abs(lateral.value(lean: value.lean) - 0.15) <= 0.045)
        }
        // A bike keeps the strongest value of the second, as before.
        let bike = try Self.swayingCurve(vehicle: .eBike).dropFirst().map { try #require($0) }
        #expect(bike.contains { lateral.value(lean: $0.lean) > 0.3 })
    }

    @Test("The check allows more at speed and in a curve, but not a turned iPhone")
    func allowedMismatch() throws {
        // 7°/s on a straight road at 90 km/h is still a turned iPhone, in a car as well.
        var fusion = MotionFusion(vehicle: .car)
        let start = MotionFusionTests.start
        _ = fusion.close(at: start, speed: 25, course: 90, courseAccuracy: 2)
        var last: MotionValues?
        for second in 1...4 {
            for reading in MotionFusionTests.readings(from: Double(second - 1), seconds: 1, turn: 0.12) {
                fusion.add(reading)
            }
            last = fusion.close(at: start.addingTimeInterval(Double(second)), speed: 25, course: 90, courseAccuracy: 2)
        }
        #expect(try #require(last).lean == 0)
        // At 30 km/h a course 4.5° off the sensors in a curve still counts, on a straight road not.
        let speed = 30 / 3.6
        let inCurve = try #require(Self.drive(seconds: 3, speed: speed, turn: 0.3,
                                              courseRate: -0.3 * 180 / .pi + 4.5).last ?? nil)
        #expect(inCurve.lean > 10)
        let straight = try #require(Self.drive(seconds: 3, speed: speed, turn: 4.5 * .pi / 180).last ?? nil)
        #expect(straight.lean == 0)
    }

    @Test("Below 10 km/h there is no check, and no lean either")
    func slow() throws {
        let slow = try #require(Self.drive(seconds: 3, speed: 2, turn: 0.5).last ?? nil)
        #expect(slow.lean == 0)
    }

    @Test("A car can be recorded; it is fast like a motorcycle and shows the lateral acceleration")
    func recordingVehicle() throws {
        #expect(RecordingVehicle.car.rawValue == "car")
        #expect(RecordingVehicle.car.maxSpeed == RecordingVehicle.motorcycle.maxSpeed)
        #expect(RecordingVehicle.car.side == .lateralAcceleration && RecordingVehicle.motorcycle.side == .leanAngle)
        let data = try JSONEncoder().encode(RecordingLog.Event.vehicle(.car))
        #expect(try JSONDecoder().decode(RecordingLog.Event.self, from: data) == .vehicle(.car))
    }
}
