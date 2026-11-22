import Foundation
import Testing
@testable import WattspurCore

/// Auto-start, stage 1 (B-311): the recording waits as “Ready” until the vehicle moves, and the
/// connection tells which device it is. All tracks here are made up.
@Suite("Auto-start")
struct AutoStartTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A position `metres` north of the start, `seconds` after it, at `speed` m/s.
    static func fix(_ seconds: Double, north metres: Double, speed: Double?, accuracy: Double = 8) -> RideRecording.Fix {
        RideRecording.Fix(date: start.addingTimeInterval(seconds), latitude: 49.8 + metres / 111_195,
                          longitude: 8.8, altitude: 100, horizontalAccuracy: accuracy, speed: speed)
    }

    static func car(_ name: String, archived: Bool = false) -> RideExchange.Bike {
        RideExchange.Bike(id: UUID(), name: name, kind: "car", color: "black", isEbike: false, isArchived: archived)
    }

    @Test("Ready → ride: nothing is kept below 10 km/h; the first fast position begins the ride and sets the start")
    func readyToRide() {
        var recording = RideRecording(startDate: Self.start, device: .without(.car))
        recording.waitForMovement()
        #expect(recording.isReady)
        // Walking to the car and standing with the engine on: 0 to 5 km/h for two minutes.
        for second in 0..<120 {
            do { let kept = recording.add(Self.fix(Double(second), north: Double(second) * 0.8, speed: 1.4)); #expect(!kept) }
        }
        // No speed measured is no proof of driving either.
        do { let kept = recording.add(Self.fix(120, north: 100, speed: nil)); #expect(!kept) }
        #expect(recording.isReady)
        #expect(recording.pointCount == 0)
        // Driving off: 12 km/h, then faster.
        do { let kept = recording.add(Self.fix(121, north: 100, speed: 12 / 3.6)); #expect(kept) }
        #expect(!recording.isReady)
        #expect(recording.startDate == Self.start.addingTimeInterval(121))
        for second in 122...180 {
            recording.add(Self.fix(Double(second), north: 100 + Double(second - 121) * 10, speed: 10))
        }
        #expect(abs(recording.distance - 590) < 2)
        // Slower again later (a traffic light) keeps the ride going.
        do { let kept = recording.add(Self.fix(181, north: 692, speed: 1)); #expect(kept) }
    }

    @Test("A fast but inaccurate position does not begin the ride; the first accurate one does, without the start accuracy")
    func accuracy() {
        var recording = RideRecording(startDate: Self.start, device: .without(.car))
        recording.waitForMovement()
        do { let kept = recording.add(Self.fix(10, north: 0, speed: 15, accuracy: 45)); #expect(!kept) }
        #expect(recording.isReady)
        // 20 m is worse than the 10 m a normal first position needs, but good enough after waiting.
        do { let kept = recording.add(Self.fix(11, north: 15, speed: 15, accuracy: 20)); #expect(kept) }
        #expect(!recording.isReady)
    }

    @Test("A kept position from before the start, with the speed of an earlier drive, does not begin the ride")
    func stalePosition() {
        var recording = RideRecording(startDate: Self.start, device: .without(.car))
        recording.waitForMovement()
        do { let kept = recording.add(Self.fix(-90, north: 0, speed: 14)); #expect(!kept) }
        #expect(recording.isReady)
        do { let kept = recording.add(Self.fix(40, north: 0, speed: 14)); #expect(kept) }
        #expect(recording.startDate == Self.start.addingTimeInterval(40))
    }

    @Test("Only a recording without positions can wait; a normal recording is never ready")
    func onlyBeforeTheFirstPosition() {
        var recording = RideRecording(startDate: Self.start, device: .without(.car))
        #expect(!recording.isReady)
        recording.add(Self.fix(0, north: 0, speed: 0, accuracy: 5))
        recording.waitForMovement()
        #expect(!recording.isReady)
    }

    @Test("The log keeps “Ready”: replayed, the recording still waits, or has begun with the first fast position")
    func log() throws {
        var data = RecordingLog.line(.start(Self.start))
        data += RecordingLog.line(.device(.without(.car)))
        data += RecordingLog.line(.ready)
        data += RecordingLog.line(.fix(Self.fix(5, north: 2, speed: 1)))
        let waiting = try #require(RecordingLog.replay(data))
        #expect(waiting.isReady)
        #expect(waiting.pointCount == 0)
        data += RecordingLog.line(.fix(Self.fix(30, north: 20, speed: 8)))
        data += RecordingLog.line(.fix(Self.fix(31, north: 28, speed: 8)))
        let riding = try #require(RecordingLog.replay(data))
        #expect(!riding.isReady)
        #expect(riding.pointCount == 2)
        #expect(riding.startDate == Self.start.addingTimeInterval(30))
    }

    @Test("CarPlay picks the device that starts with CarPlay, before any Bluetooth device")
    func carPlay() {
        let nugget = Self.car("Nugget"), golf = Self.car("Golf")
        let triggers: [UUID: AutoStart.Trigger] = [nugget.id: .carPlay, golf.id: .bluetooth("VW BT 1234")]
        let ports = [AutoStart.AudioPort(kind: .bluetooth, name: "VW BT 1234"), AutoStart.AudioPort(kind: .carPlay, name: "CarPlay")]
        #expect(AutoStart.device(for: ports, triggers: triggers, devices: [golf, nugget])?.bikeID == nugget.id)
    }

    @Test("Bluetooth by name, ignoring case; no match, an archived device or no connection give none")
    func bluetooth() {
        let moto = RideExchange.Bike(id: UUID(), name: "Honda", kind: "motorcycle", color: "red", isEbike: false, isArchived: false)
        let old = Self.car("Alter Polo", archived: true)
        let triggers: [UUID: AutoStart.Trigger] = [moto.id: .bluetooth("Sena 50S"), old.id: .bluetooth("Polo")]
        let headset = [AutoStart.AudioPort(kind: .bluetooth, name: "SENA 50s")]
        let device = AutoStart.device(for: headset, triggers: triggers, devices: [moto, old])
        #expect(device?.bikeID == moto.id)
        #expect(device?.kind == .motorcycle)
        #expect(AutoStart.device(for: [AutoStart.AudioPort(kind: .bluetooth, name: "AirPods")], triggers: triggers, devices: [moto, old]) == nil)
        #expect(AutoStart.device(for: [AutoStart.AudioPort(kind: .bluetooth, name: "Polo")], triggers: triggers, devices: [moto, old]) == nil)
        #expect(AutoStart.device(for: [AutoStart.AudioPort(kind: .other, name: "Speaker")], triggers: triggers, devices: [moto]) == nil)
        // CarPlay with no device for it: no match, the recording takes the last device.
        #expect(AutoStart.device(for: [AutoStart.AudioPort(kind: .carPlay, name: "CarPlay")], triggers: triggers, devices: [moto]) == nil)
    }

    @Test("Standing still: slow positions and the GPS wandering do not count as moving; 10 min after the last move it is over (B-339)")
    func standstill() {
        var watch = AutoStart.Standstill(limit: 600, since: Self.start)
        watch.record(Self.fix(30, north: 0, speed: 12))
        #expect(watch.lastMove == Self.start.addingTimeInterval(30))
        // Parked: the GPS wanders at 1–3 km/h, one inaccurate jump looks fast.
        for second in stride(from: 31.0, to: 700, by: 1) {
            watch.record(Self.fix(second, north: 0, speed: 0.6))
        }
        watch.record(Self.fix(400, north: 50, speed: 20, accuracy: 80))
        #expect(watch.lastMove == Self.start.addingTimeInterval(30))
        #expect(!watch.isOver(at: Self.start.addingTimeInterval(629)))
        #expect(watch.isOver(at: Self.start.addingTimeInterval(630)))
    }

    @Test("“Ready” without driving off is over after the standstill time, counted from its start")
    func readyTimesOut() {
        let watch = AutoStart.Standstill(limit: 300, since: Self.start)
        #expect(!watch.isOver(at: Self.start.addingTimeInterval(299)))
        #expect(watch.isOver(at: Self.start.addingTimeInterval(300)))
    }

    @Test("Under 500 m, or still ready, an auto-ended ride is not kept")
    func keeps() {
        var short = RideRecording(startDate: Self.start, device: .without(.car))
        for second in 0...30 { short.add(Self.fix(Double(second), north: Double(second) * 10, speed: 10)) }
        #expect(!AutoStart.keeps(short))
        var long = RideRecording(startDate: Self.start, device: .without(.car))
        for second in 0...60 { long.add(Self.fix(Double(second), north: Double(second) * 10, speed: 10)) }
        #expect(AutoStart.keeps(long))
        var ready = RideRecording(startDate: Self.start, device: .without(.car))
        ready.waitForMovement()
        #expect(!AutoStart.keeps(ready))
    }

    @Test("A trigger survives JSON, as kept on the iPhone")
    func triggerCoding() throws {
        let id = UUID()
        let triggers: [UUID: AutoStart.Trigger] = [id: .bluetooth("Sena 50S"), UUID(): .carPlay]
        let data = try JSONEncoder().encode(triggers)
        #expect(try JSONDecoder().decode([UUID: AutoStart.Trigger].self, from: data) == triggers)
    }
}
