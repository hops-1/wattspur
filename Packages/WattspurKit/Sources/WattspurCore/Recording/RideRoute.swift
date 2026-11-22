import Foundation

/// The places of a recorded ride, for the name Wattspur suggests (B-368): from one town to
/// another, a round trip, or only the start when the end was not found. Only the places; the app
/// writes the name (“Darmstadt – Frankfurt – 14:32”, “Reinheim Round Trip – 14:32”).
public enum RideRoute: Equatable, Sendable {
    case oneWay(from: String, to: String)
    case roundTrip(String)
    case start(String)

    /// The route from the town names at start and end; `nil` without a start.
    public init?(start: String?, end: String?) {
        let start = start?.trimmingCharacters(in: .whitespaces), end = end?.trimmingCharacters(in: .whitespaces)
        guard let start, !start.isEmpty else { return nil }
        guard let end, !end.isEmpty else {
            self = .start(start)
            return
        }
        self = end == start ? .roundTrip(start) : .oneWay(from: start, to: end)
    }
}
