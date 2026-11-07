import ActivityKit
import AppIntents
import Foundation

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
    }

    /// When the recording started; the time counts from here, as in the app.
    var startDate: Date
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

/// What the intent calls; the app sets it when the recorder starts. In the extension it stays
/// empty, which does not matter: the intent never runs there.
@MainActor
enum RecordingControl {
    static var togglePause: () -> Void = {}
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
