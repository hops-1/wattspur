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
