import Foundation

/// The sport an area shows (B-288 on the Mac, B-289 on the iPhone; `DESIGN-SPORTARTEN.md`).
///
/// The switch appears only once there is more than one sport, in devices or in rides. Each device
/// remembers its own choice; it is not synced. A choice of a sport that is no longer there falls
/// back to the first sport there is, so nobody looks at an empty area without a switch to leave it.
public enum SportChoice {
    /// The sports with an open device or a ride, in the order cycling, vehicles, running.
    /// Without any, cycling, the sport of a new library.
    ///
    /// - Parameters:
    ///   - deviceKinds: raw `BikeKind` values of the open (not archived) devices.
    ///   - rideSports: the sports of the rides that count (not in the trash, not the sample).
    public static func available(deviceKinds: some Sequence<String>, rideSports: some Sequence<Sport>) -> [Sport] {
        var present = Set(rideSports)
        for kind in deviceKinds { present.insert((BikeKind(rawValue: kind) ?? .bike).sport) }
        let sports = Sport.allCases.filter(present.contains)
        return sports.isEmpty ? [.cycling] : sports
    }

    /// The sport shown: the stored choice while it is there, else the first sport there is.
    public static func resolved(_ stored: Sport?, available: [Sport]) -> Sport {
        if let stored, available.contains(stored) { return stored }
        return available.first ?? .cycling
    }

    /// Whether the switch is shown: only from the second sport on.
    public static func showsSwitch(available: [Sport]) -> Bool { available.count > 1 }
}

extension BikeFilter {
    /// The filter within one sport: a device of another sport counts as "all", as does a choice
    /// among fewer than two devices of the sport (see `resolved(knownBikeIDs:)`).
    ///
    /// - Parameter devices: id and raw `BikeKind` of every device, archived ones included.
    public func resolved(sport: Sport, devices: some Sequence<(id: UUID, kind: String)>) -> BikeFilter {
        let ids = devices.filter { (BikeKind(rawValue: $0.kind) ?? .bike).sport == sport }.map(\.id)
        return resolved(knownBikeIDs: Set(ids))
    }
}
