import Foundation
import Testing
@testable import WattspurCore

/// The CarPlay panel (B-327). All tracks here are made up.
@Suite("Driving panel")
struct DrivingPanelTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    static func fix(_ seconds: Double, north metres: Double, speed: Double, lean: Double? = nil) -> RideRecording.Fix {
        RideRecording.Fix(date: start.addingTimeInterval(seconds), latitude: 49.8 + metres / 111_195, longitude: 8.8,
                          altitude: 100, horizontalAccuracy: 5, speed: speed,
                          motion: lean.map { MotionValues(lean: $0, acceleration: nil, roughness: 0) })
    }

    /// A drive north at 20 m/s for `seconds`, leaning `lean` degrees at the end.
    static func drive(_ device: RecordingDevice, seconds: Int = 60, lean: Double = 10) -> RideRecording {
        var recording = RideRecording(startDate: start, device: device)
        for second in 0...seconds {
            recording.add(fix(Double(second), north: Double(second) * 20, speed: 20, lean: lean))
        }
        return recording
    }

    @Test("No recording: the idle panel")
    func idle() {
        let panel = DrivingPanel(recording: nil, at: Self.start)
        #expect(panel == DrivingPanel(state: .idle))
    }

    @Test("A car shows speed, time, distance and the lateral acceleration of the last position")
    func car() {
        let panel = DrivingPanel(recording: Self.drive(.without(.car)), at: Self.start.addingTimeInterval(61))
        #expect(panel.state == .recording)
        #expect(abs(panel.speed - 20) < 0.01)
        #expect(panel.elapsed == 61)
        #expect(abs(panel.distance - 1200) < 5)
        #expect(panel.sideMeasure == .lateralAcceleration)
        #expect(panel.lean == 10)
        #expect(SideMeasure.lateralAcceleration.text(lean: 10).hasSuffix(" g"))
    }

    @Test("A motorcycle shows the lean angle, a bicycle none")
    func sideMeasure() {
        let moto = DrivingPanel(recording: Self.drive(.without(.motorcycle), lean: -30), at: Self.start.addingTimeInterval(61))
        #expect(moto.sideMeasure == .leanAngle)
        #expect(moto.lean == -30)
        let bike = DrivingPanel(recording: Self.drive(.without(.bike)), at: Self.start.addingTimeInterval(61))
        #expect(bike.sideMeasure == nil)
        #expect(bike.lean == nil)
    }

    @Test("Paused: no speed and no side value; the time goes on, the distance stays")
    func paused() {
        var recording = Self.drive(.without(.car))
        recording.pause()
        let panel = DrivingPanel(recording: recording, at: Self.start.addingTimeInterval(120))
        #expect(panel.state == .paused)
        #expect(panel.speed == 0)
        #expect(panel.lean == nil)
        #expect(panel.elapsed == 120)
        #expect(abs(panel.distance - 1200) < 5)
    }

    @Test("Ready: waiting for the vehicle, no time yet")
    func ready() {
        var recording = RideRecording(startDate: Self.start, device: .without(.car))
        recording.waitForMovement()
        let panel = DrivingPanel(recording: recording, at: Self.start.addingTimeInterval(40))
        #expect(panel.state == .ready)
        #expect(panel.elapsed == 0)
        #expect(panel.distance == 0)
    }

    @Test("Written anew at most every 5 s, a new state at once, nothing when the figures stayed")
    func refresh() {
        let shownAt = Self.start
        let shown = DrivingPanel(state: .recording, speed: 20, elapsed: 10, distance: 200)
        #expect(DrivingPanel(state: .idle).needsRefresh(since: nil, shownAt: nil, at: shownAt))
        let newer = DrivingPanel(state: .recording, speed: 21, elapsed: 14, distance: 280)
        #expect(!newer.needsRefresh(since: shown, shownAt: shownAt, at: shownAt.addingTimeInterval(4)))
        #expect(newer.needsRefresh(since: shown, shownAt: shownAt, at: shownAt.addingTimeInterval(5)))
        let paused = DrivingPanel(state: .paused, elapsed: 11, distance: 200)
        #expect(paused.needsRefresh(since: shown, shownAt: shownAt, at: shownAt.addingTimeInterval(1)))
        #expect(!shown.needsRefresh(since: shown, shownAt: shownAt, at: shownAt.addingTimeInterval(30)))
    }

    @Test("Vehicles: the open cars and motorcycles in order, no bicycles, then car and motorcycle without a device")
    func vehicles() {
        func device(_ name: String, _ kind: String, archived: Bool = false) -> RideExchange.Bike {
            RideExchange.Bike(id: UUID(), name: name, kind: kind, color: "black", isEbike: false, isArchived: archived)
        }
        let nugget = device("Nugget", "car")
        let old = device("Golf", "car", archived: true)
        let bike = device("Cube", "bike")
        let moto = device("Tenere", "motorcycle")
        let list = DrivingPanel.vehicles(from: [nugget, old, bike, moto])
        #expect(list == [RecordingDevice(bikeID: nugget.id, kind: .car), RecordingDevice(bikeID: moto.id, kind: .motorcycle),
                         .without(.car), .without(.motorcycle)])
    }
}
