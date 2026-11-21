import CoreLocation
import Foundation
import MapKit
import UserNotifications
import WattspurCore

/// The town of a position, for the name of an auto-ended ride (B-339): “Darmstadt – Frankfurt”.
/// Apple's map service looks it up; without a network or a result it is `nil`.
enum PlaceName {
    static func of(_ fix: RideRecording.Fix?) async -> String? {
        guard let fix else { return nil }
        let location = CLLocation(latitude: fix.latitude, longitude: fix.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        return item.addressRepresentations?.cityName ?? item.name
    }
}

/// The notification after an auto-ended ride was saved (B-339); a tap opens it.
enum RideSavedNotice {
    /// Asked when auto-start is switched on, so the first ride's notice is not lost to the question.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(name: String, distance: Double) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ride Saved")
        content.body = String(localized: "\(name), \(RideFormat.distance(distance)). Tap to open it.")
        content.sound = .default
        content.userInfo = ["opens": "lastRide"]
        let request = UNNotificationRequest(identifier: "rideSaved", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Shows the notification also while Wattspur is in front, and opens the newest ride on a tap: the
/// ride just saved.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let intents: IntentRouter

    init(intents: IntentRouter) {
        self.intents = intents
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["opens"] as? String == "lastRide" else { return }
        let intents = self.intents
        await MainActor.run { intents.request = .lastRide }
    }
}
