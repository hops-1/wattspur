import ActivityKit
import AppIntents
import Foundation
import WattspurCore

/// The Live Activity of a recording (B-223): time, distance and speed on the Lock Screen and in
/// the Dynamic Island, with a button for Pause. Shared by the app, which starts and updates it,
/// and the widget extension, which draws it. Only values from the iPhone, nothing from the bike.
struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// Metres.
        var distance: Double
        /// Metres per second, the current speed; 0 while standing or paused.
        var speed: Double
        var isPaused: Bool
        /// The lean angle of the last point in degrees, positive to the left (B-289); `nil` for a
        /// bicycle, before the first value and while paused. A car shows it as lateral acceleration.
        var lean: Double? = nil
        /// Waiting for the vehicle to move (auto-start, B-311); `nil` otherwise.
        var isReady: Bool? = nil
        /// When the time counts from, and the device (B-370): both can change while ready, and the
        /// attributes cannot. `nil` in an activity of an older build.
        var start: Date? = nil
        var device: Device? = nil
    }

    struct Device: Codable, Hashable, Sendable {
        var symbol: String?
        var kind: String?
        var side: String?
    }

    /// The start and the device as they are now (B-370).
    func start(_ state: ContentState) -> Date { state.start ?? startDate }
    func device(_ state: ContentState) -> Device { state.device ?? Device(symbol: symbol, kind: kind, side: side) }

    /// When the recording started; the time counts from here, as in the app.
    var startDate: Date
    /// The symbol of the device recorded with (B-286), e.g. `car`; `nil` is a bicycle.
    var symbol: String? = nil
    /// The kind of the device recorded with (`BikeKind`), drawn as in the app (B-342); `nil` is a bicycle.
    var kind: String? = nil
    /// What the side value means (B-289): `lateral` for a car, `lean` for a motorcycle; `nil` shows none.
    var side: String? = nil
}

/// Pause or Resume from the Live Activity. A `LiveActivityIntent` runs in the app's process, so
/// the recorder there does the work; the extension only shows the button.
struct ToggleRecordingPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Ride"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { RecordingControl.togglePause() }
        return .result()
    }
}

/// Cancels “Ready” of an auto-start (B-311) from the Live Activity; nothing was recorded yet.
struct CancelReadyIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Auto-Start"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { RecordingControl.cancelReady() }
        return .result()
    }
}

/// What the intents call; the app sets it when the recorder starts. In the extension it stays
/// empty, which does not matter: the intents never run there.
@MainActor
enum RecordingControl {
    static var togglePause: () -> Void = {}
    static var cancelReady: () -> Void = {}
}

/// The side value of the Live Activity as text: “0,23 g” for a car, “23°” for a motorcycle, in the
/// language of the device; the side as an arrow. The same rule as in the app (`SideMeasure`).
enum ActivitySide {
    /// In g from the lean angle (`SideMeasure.lateralAcceleration`).
    static func lateral(lean degrees: Double) -> Double {
        SideMeasure.lateralAcceleration.value(lean: degrees)
    }

    static func text(lean degrees: Double, kind: String) -> String {
        let arrow = degrees > 0.5 ? "← " : degrees < -0.5 ? "→ " : ""
        return arrow + (kind == "lateral" ? SideMeasure.lateralAcceleration : SideMeasure.leanAngle).text(lean: degrees)
    }
}

/// Numbers for the Live Activity, in the units of the app: km and km/h, or miles and mph by region.
enum ActivityFormat {
    static func distance(_ metres: Double) -> String {
        let unit: UnitLength = Locale.current.measurementSystem == .metric ? .kilometers : .miles
        return Measurement(value: metres, unit: UnitLength.meters).converted(to: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(1))))
    }

    /// “6,8” and “km” apart, for the narrow space beside the Dynamic Island.
    static func distanceParts(_ metres: Double) -> (number: String, unit: String) {
        let metric = Locale.current.measurementSystem == .metric
        let value = Measurement(value: metres, unit: UnitLength.meters).converted(to: metric ? .kilometers : .miles).value
        return (value.formatted(.number.precision(.fractionLength(1))), metric ? "km" : "mi")
    }

    /// In mph where the distance is in miles (R-55).
    static func speed(_ metresPerSecond: Double) -> String {
        let unit: UnitSpeed = Locale.current.measurementSystem == .metric ? .kilometersPerHour : .milesPerHour
        return Measurement(value: metresPerSecond, unit: UnitSpeed.metersPerSecond).converted(to: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}
