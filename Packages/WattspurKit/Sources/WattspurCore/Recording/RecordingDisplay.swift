import Foundation

/// What of a recording reaches the screen (B-369). A screen nobody sees is not told about every
/// position: SwiftUI still works out the views in the background, and that work grew there until it
/// took a whole core after about a quarter of an hour (bike tour of 22.11.2026: phone froze, altitude
/// missing, battery empty). The recording itself, its log, the Live Activity and CarPlay go on.
public enum RecordingDisplay {
    /// Whether `recording` replaces what the screen shows: always while it is visible; hidden only
    /// when the recording starts, ends, pauses, resumes or the ride begins after “Ready”.
    public static func publishes(_ recording: RideRecording?, over shown: RideRecording?, isVisible: Bool) -> Bool {
        switch (recording, shown) {
        case (nil, nil): false
        case (nil, _), (_, nil): true
        case let (recording?, shown?):
            isVisible || recording.isPaused != shown.isPaused || recording.isReady != shown.isReady
                || recording.startDate != shown.startDate
        }
    }
}
