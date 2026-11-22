import AppIntents
import Foundation
import Observation
import UIKit
import WattspurCore

/// Siri and the Shortcuts app (B-225): start and end a ride, the distance of this week, and the
/// last ride. The German phrases are in `AppShortcuts.xcstrings`, the texts in `Localizable.xcstrings`.
struct WattspurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRideIntent(), phrases: [
            "Start a ride with \(.applicationName)",
            "Start \(.applicationName)",
            "Record a ride with \(.applicationName)",
            "Start a ride with \(\.$device) in \(.applicationName)",
            "Start \(.applicationName) with \(\.$device)",
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
/// With a device (B-286), e.g. “Start a ride with Nugget”; without one, the device of the last ride.
/// With auto-start on (B-311) and no device, it is what the automation “When CarPlay connects”
/// runs: a car or motorcycle (B-370), and the recording waits as “Ready” until it moves.
/// It keeps opening the app: started in the background, iOS stops GPS after a few seconds with
/// “While Using”, also with a Live Activity (tried for B-370 on 22.11.2026).
struct StartRideIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Ride"
    static let description = IntentDescription("Starts recording a ride with GPS.")
    static let openAppWhenRun = true

    @Parameter(title: "Device")
    var device: DeviceEntity?

    @Dependency private var recorder: Recorder

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The iPad has no recording for now (B-292).
        guard RecordingAvailability.isSupported else {
            return .result(dialog: .app("Wattspur cannot record rides on the iPad yet. Record them on the iPhone."))
        }
        if recorder.isRecording {
            return .result(dialog: .app("A ride is already being recorded."))
        }
        // The app asks first what to do with it; starting here would throw it away.
        if recorder.unfinished != nil {
            return .result(dialog: .app("Wattspur has an unfinished ride. Continue it or end it first."))
        }
        if device == nil, AutoStartSettings.isOn {
            recorder.start(device: AutoStartSettings.readyDevice(devices: RecordingChoice.cachedDevices), ready: true)
            return .result(dialog: .app("Ready. The ride begins when you drive off."))
        }
        recorder.start(device: device?.recordingDevice)
        return .result(dialog: .app("Ride started. Have a good ride!"))
    }
}

/// Ends the recording as Stop does: the app opens “Save Ride” to name it and choose the bike. An
/// auto-started ride is saved without opening the app, also on a locked iPhone (B-370); with a ride
/// started by hand “Save Ride” waits until the app is opened.
struct EndRideIntent: AppIntent {
    static let title: LocalizedStringResource = "End Ride"
    static let description = IntentDescription("Ends the recording and opens Save Ride.")
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Dependency private var recorder: Recorder

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard recorder.isRecording else {
            return .result(dialog: .app("No ride is being recorded."))
        }
        // Auto-start (B-339): “Ready” without a ride just ends; an auto-started ride saves by itself
        // when the automation for the end of the connection runs this.
        if recorder.isReady {
            recorder.cancelReady()
            return .result(dialog: .app("Auto-start cancelled. No ride was recorded."))
        }
        if recorder.isAutoStarted, AutoStartSettings.endsOnDisconnect {
            let kept = recorder.recording.map(AutoStart.keeps) ?? false
            await recorder.endAutomatically()
            if !recorder.isRecording {
                return .result(dialog: kept ? .app("Ride saved.") : .app("The ride was shorter than 500 m and was not kept."))
            }
        }
        recorder.endRequested = true
        await comeToFrontIfUnlocked()
        return .result(dialog: .app("Name the ride and save it."))
    }
}

private extension AppIntent {
    /// Opens the app when the iPhone is unlocked. Locked, iOS refuses (“request to open … failed”)
    /// or waits for the unlock until Shortcuts gives up, so then it is not asked (B-370).
    @MainActor
    func comeToFrontIfUnlocked() async {
        let mode = systemContext.currentMode
        guard mode == .background, mode.canContinueInForeground, UIApplication.shared.isProtectedDataAvailable else { return }
        try? await continueInForeground(alwaysConfirm: false)
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

/// A device for “Start a ride with …” (B-286): one of the open devices, or a vehicle type without
/// one (bicycle, car, motorcycle, B-321). Read from the list the library writes at every reload,
/// so Siri finds it at once.
struct DeviceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Device")
    static let defaultQuery = DeviceQuery()

    /// The device's UUID, or `bike` / `car` / `motorcycle` for a vehicle type without a device (B-321).
    var id: String
    var name: String
    var recordingDevice: RecordingDevice

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: recordingDevice.symbol))
    }

    @MainActor
    static var all: [DeviceEntity] {
        let devices = RecordingChoice.cachedDevices.map { bike in
            DeviceEntity(id: bike.id.uuidString, name: bike.name,
                         recordingDevice: RecordingDevice(bikeID: bike.id, kind: BikeKind(rawValue: bike.kind) ?? .bike))
        }
        let without = RecordingDevice.vehicleTypes.map { kind in
            DeviceEntity(id: kind.rawValue, name: kind.localizedName, recordingDevice: .without(kind))
        }
        return devices + without
    }
}

struct DeviceQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [DeviceEntity] {
        DeviceEntity.all.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [DeviceEntity] {
        DeviceEntity.all.filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [DeviceEntity] {
        DeviceEntity.all
    }
}
