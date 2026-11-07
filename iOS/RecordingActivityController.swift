import ActivityKit
import Foundation
import WattspurCore

/// Starts, updates and ends the Live Activity of a recording (B-223). The recorder calls it; the
/// extension draws the activity. Updates come at most every few seconds, and at once on Pause
/// and Resume, so the Lock Screen stays current without costing much battery.
@MainActor
final class RecordingActivityController {
    private var activity: Activity<RecordingAttributes>?
    private var lastUpdate = Date.distantPast
    private var lastState: RecordingAttributes.ContentState?
    /// Seconds between two updates while riding.
    private static let interval: TimeInterval = 5

    init() {
        // An activity left over from a crash or a killed app shows nothing true any more. Only those
        // there now: Siri may start a ride with the app closed, and its new activity must stay (R-54).
        let leftOver = Set(Activity<RecordingAttributes>.activities.map(\.id))
        guard !leftOver.isEmpty else { return }
        Task.detached {
            for activity in Activity<RecordingAttributes>.activities where leftOver.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func start(_ recording: RideRecording) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = Self.state(of: recording)
        activity = try? Activity.request(attributes: RecordingAttributes(startDate: recording.startDate),
                                         content: ActivityContent(state: state, staleDate: nil))
        lastState = state
        lastUpdate = .now
    }

    /// After a new position: only when enough time has passed or Pause changed.
    func update(_ recording: RideRecording, force: Bool = false) {
        guard let activity else { return }
        let state = Self.state(of: recording)
        guard state != lastState else { return }
        guard force || state.isPaused != lastState?.isPaused || Date.now.timeIntervalSince(lastUpdate) >= Self.interval else { return }
        lastState = state
        lastUpdate = .now
        Self.send(to: activity.id) { await $0.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end(_ recording: RideRecording?) {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        let final = recording.map { ActivityContent(state: Self.state(of: $0), staleDate: nil) }
        Self.send(to: activity.id) { await $0.end(final, dismissalPolicy: .immediate) }
    }

    /// `Activity` may not cross from the main actor into a task, so the task finds it again by its id.
    private static func send(to id: String,
                             _ action: @escaping @Sendable (Activity<RecordingAttributes>) async -> Void) {
        Task.detached {
            for activity in Activity<RecordingAttributes>.activities where activity.id == id {
                await action(activity)
            }
        }
    }

    private static func state(of recording: RideRecording) -> RecordingAttributes.ContentState {
        // Rounded, so a tiny change of speed does not count as new.
        RecordingAttributes.ContentState(distance: (recording.distance / 10).rounded() * 10,
                                         speed: (recording.currentSpeed * 36).rounded() / 36,
                                         isPaused: recording.isPaused)
    }
}
