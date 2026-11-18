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

    /// The key of a sport's week (B-289): cycling keeps the key of before, so a widget placed earlier
    /// shows the same; the other sports get their own.
    private static func key(for sport: Sport) -> String { sport == .cycling ? key : "\(key).\(sport.rawValue)" }

    static func load(_ sport: Sport = .cycling) -> WeekSnapshot? {
        guard let data = defaults?.data(forKey: key(for: sport)) else { return nil }
        return try? JSONDecoder().decode(WeekSnapshot.self, from: data)
    }

    /// Returns whether something new was written, so the app reloads the widget only then.
    @discardableResult
    static func save(_ snapshot: WeekSnapshot, for sport: Sport = .cycling) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot),
              defaults.data(forKey: key(for: sport)) != data else { return false }
        defaults.set(data, forKey: key(for: sport))
        return true
    }
}
