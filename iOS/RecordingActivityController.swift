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

    /// Activities left over from a crash or from iOS ending the app. Only those there at launch:
    /// Siri may start a ride with the app closed, and its new activity must stay (R-54).
    private var leftOver: [String]

    init() {
        leftOver = Activity<RecordingAttributes>.activities.map(\.id)
    }

    /// The leftovers show nothing true any more: ended, when the ride is not continued at once.
    func endLeftOver() {
        let ids = Set(leftOver)
        leftOver = []
        guard !ids.isEmpty else { return }
        Task.detached {
            for activity in Activity<RecordingAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// The ride goes on after iOS ended the app (B-383): its activity is still on the Lock Screen
    /// and in CarPlay, and is taken over and brought up to date. A new one only if none is left,
    /// which works only with the app in front; else `start(_:)` follows when it comes to the front.
    func resume(_ recording: RideRecording) {
        guard activity == nil else { return }
        let ids = leftOver
        leftOver = []
        guard let kept = Activity<RecordingAttributes>.activities.first(where: { ids.contains($0.id) }) else {
            start(recording)
            return
        }
        activity = kept
        let others = Set(ids).subtracting([kept.id])
        if !others.isEmpty {
            Task.detached {
                for activity in Activity<RecordingAttributes>.activities where others.contains(activity.id) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        lastState = nil
        update(recording, force: true)
    }

    func start(_ recording: RideRecording) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = Self.state(of: recording)
        let device = Self.device(of: recording)
        activity = try? Activity.request(attributes: RecordingAttributes(startDate: recording.startDate, symbol: device.symbol,
                                                                         kind: device.kind,
                                                                         side: device.side),
                                         content: ActivityContent(state: state, staleDate: nil))
        lastState = state
        lastUpdate = .now
    }

    /// After a new position: only when enough time has passed or Pause changed.
    func update(_ recording: RideRecording, force: Bool = false) {
        guard let activity else { return }
        let state = Self.state(of: recording)
        guard state != lastState else { return }
        guard force || state.isPaused != lastState?.isPaused || state.isReady != lastState?.isReady || Date.now.timeIntervalSince(lastUpdate) >= Self.interval else { return }
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
        // The side value only for vehicles, to whole degrees: a bicycle's activity stays as it was.
        let lean = recording.vehicle == .eBike || recording.isPaused ? nil : recording.lastPoint?.fix.motion?.lean.rounded()
        return RecordingAttributes.ContentState(distance: (recording.distance / 10).rounded() * 10,
                                                speed: (recording.currentSpeed * 36).rounded() / 36,
                                                isPaused: recording.isPaused, lean: lean,
                                                isReady: recording.isReady ? true : nil,
                                                start: recording.startDate, device: device(of: recording))
    }

    private static func device(of recording: RideRecording) -> RecordingAttributes.Device {
        let side: String? = switch recording.vehicle {
        case .car: "lateral"
        case .motorcycle: "lean"
        case .eBike: nil
        }
        return RecordingAttributes.Device(symbol: recording.device?.symbol, kind: recording.device?.kind.rawValue, side: side)
    }
}
