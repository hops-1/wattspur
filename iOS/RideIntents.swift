import AppIntents
import Foundation
import Observation
import WattspurCore

/// Siri and the Shortcuts app (B-225): start and end a ride, the distance of this week, and the
/// last ride. The German phrases are in `AppShortcuts.xcstrings`, the texts in `Localizable.xcstrings`.
struct WattspurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRideIntent(), phrases: [
            "Start a ride with \(.applicationName)",
            "Start \(.applicationName)",
            "Record a ride with \(.applicationName)",
        ], shortTitle: "Start Ride", systemImageName: "record.circle")
        AppShortcut(intent: EndRideIntent(), phrases: [
            "End the ride in \(.applicationName)",
            "Stop \(.applicationName)",
        ], shortTitle: "End Ride", systemImageName: "stop.circle")
        AppShortcut(intent: WeekDistanceIntent(), phrases: [
            "How far did I ride this week in \(.applicationName)",
            "My week in \(.applicationName)",
        ], shortTitle: "This Week", systemImageName: "calendar")
        AppShortcut(intent: OpenLastRideIntent(), phrases: [
            "Open my last ride in \(.applicationName)",
            "Show my last ride in \(.applicationName)",
        ], shortTitle: "Last Ride", systemImageName: "bicycle")
    }
}

/// Starts the recording, as “Start Ride” in the overview. The app comes to the front: GPS needs it.
struct StartRideIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Ride"
    static let description = IntentDescription("Starts recording a ride with GPS.")
    static let openAppWhenRun = true

    @Dependency private var recorder: Recorder

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if recorder.isRecording {
            return .result(dialog: .app("A ride is already being recorded."))
        }
        // The app asks first what to do with it; starting here would throw it away.
        if recorder.unfinished != nil {
            return .result(dialog: .app("Wattspur has an unfinished ride. Continue it or end it first."))
        }
        recorder.start()
        return .result(dialog: .app("Ride started. Have a good ride!"))
    }
}

/// Ends the recording as Stop does: the app opens “Save Ride” to name it and choose the bike.
struct EndRideIntent: AppIntent {
    static let title: LocalizedStringResource = "End Ride"
    static let description = IntentDescription("Ends the recording and opens Save Ride.")
    static let openAppWhenRun = true

    @Dependency private var recorder: Recorder

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard recorder.isRecording else {
            return .result(dialog: .app("No ride is being recorded."))
        }
        recorder.endRequested = true
        return .result(dialog: .app("Name the ride and save it."))
    }
}

/// The distance and the rides of this week, the same numbers as the overview and the widget.
struct WeekDistanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Distance This Week"
    static let description = IntentDescription("Tells how far you rode this week.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let totals = (WidgetShare.load() ?? .empty).totals()
        let distance = ActivityFormat.distance(totals.weekDistance)
        let rides = String(localized: "\(totals.weekRides) rides")
        // The value in kilometres, for shortcuts that go on with it.
        return .result(value: totals.weekDistance / 1000, dialog: .app("This week: \(distance), \(rides)."))
    }
}

/// Opens the newest ride in the ride list.
struct OpenLastRideIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Last Ride"
    static let description = IntentDescription("Shows your newest ride.")
    static let openAppWhenRun = true

    @Dependency private var router: IntentRouter

    @MainActor
    func perform() async throws -> some IntentResult {
        router.request = .lastRide
        return .result()
    }
}

extension IntentDialog {
    /// The text translated here in the app, in its language: the Shortcuts app showed the English
    /// text otherwise, although the German one is in the catalog.
    static func app(_ text: String.LocalizationValue) -> IntentDialog {
        IntentDialog(stringLiteral: String(localized: text))
    }
}

/// What an intent asks the app to show; the app reacts and clears it (`WattspurApp`).
@MainActor @Observable
final class IntentRouter {
    enum Request: Equatable { case lastRide }
    var request: Request?
}
