import Foundation
import WattspurCore

/// The App Group the app and the widget extension share (B-224): the app writes the week there,
/// the widget “This Week” reads it. Both entitlements files name the same group.
enum WidgetShare {
    static let appGroup = "group.io.github.hops-1.wattspur"
    /// The kind of the widget, for reloading its timeline from the app.
    static let weekWidgetKind = "WeekWidget"
    private static let key = "weekSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load() -> WeekSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeekSnapshot.self, from: data)
    }

    /// Returns whether something new was written, so the app reloads the widget only then.
    @discardableResult
    static func save(_ snapshot: WeekSnapshot) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot),
              defaults.data(forKey: key) != data else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
