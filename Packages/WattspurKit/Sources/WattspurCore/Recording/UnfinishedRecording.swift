import Foundation

/// What the app does at launch with a recording it could not finish (B-383).
///
/// iOS ends apps to free memory, also in the middle of a ride: on 24.11.2026 it ended Wattspur
/// twice in a car with CarPlay, navigation, a podcast and the camera, while Wattspur itself used
/// less than 70 MB. Apple asks apps that receive positions to start them again at once at the next
/// launch, also a launch in the background; iOS then hands over the positions it kept meanwhile.
/// So a ride from a few minutes ago goes on by itself. An older one may have ended long ago, and
/// the rider is asked, as before.
public enum UnfinishedRecording {
    /// A ride whose log was written less than this long ago goes on by itself.
    public static let resumeWindow: TimeInterval = 15 * 60

    public enum Choice: Equatable, Sendable {
        /// Go on at once, without a question and without a pause.
        case continueByItself
        /// Ask the rider: continue, end and save, or discard.
        case ask
        /// Nothing to keep: the recording was still waiting for the vehicle to move (B-311).
        case discard
    }

    /// The choice for `recording` replayed from the log. `lastWritten` is when the log was last
    /// written (the file's date), `nil` if unknown; the newest of it, the last position and the
    /// start counts. A paused ride writes nothing, so its age is the time since the pause.
    public static func choice(for recording: RideRecording, lastWritten: Date?, now: Date) -> Choice {
        if recording.isReady { return .discard }
        return now.timeIntervalSince(lastActivity(of: recording, lastWritten: lastWritten)) <= resumeWindow
            ? .continueByItself : .ask
    }

    /// The last sign of the ride: the newest of `lastWritten`, the last position and the start.
    public static func lastActivity(of recording: RideRecording, lastWritten: Date?) -> Date {
        [lastWritten, recording.lastPoint?.fix.date].compactMap { $0 }.reduce(recording.startDate, max)
    }
}
