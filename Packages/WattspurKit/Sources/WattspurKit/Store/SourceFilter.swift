import Foundation

/// Which source a list, the analysis, the map or the highlights show (B-145, IMP-04): all rides,
/// the ones from a Bosch FIT (with or without an attached GPX) or the ones from a GPX file only.
/// Each area keeps its own choice like the bike filter, stored as `rawValue`.
public enum SourceFilter: String, CaseIterable, Identifiable, Sendable {
    case all = ""
    case fit
    case gpx

    public var id: Self { self }

    public var isActive: Bool { self != .all }

    /// Whether a ride from this kind of file passes the filter. A ride without a known source
    /// (the sample ride, old data) counts as a Bosch ride.
    public func admits(source: RideSource?) -> Bool {
        switch self {
        case .all: true
        case .fit: source != .gpx
        case .gpx: source == .gpx
        }
    }

    /// The filter that applies given the rides there are: without a ride from a GPX file there is
    /// nothing to filter and the menu is hidden, so a choice made earlier must not keep working
    /// unseen (the same rule as `BikeFilter.resolved`).
    public func resolved(hasGPXRides: Bool) -> SourceFilter {
        hasGPXRides ? self : .all
    }
}

/// What the symbol of a ride says about where it comes from (B-145). A Bosch FIT alone has none.
public enum RideSourceBadge: Sendable, Equatable {
    /// The ride was imported from a GPX file.
    case gpx
    /// A Bosch FIT ride with a GPX attached (B-143).
    case attachedGPX
}

extension Ride {
    /// Whether the ride passes a source filter.
    public func isFromSource(_ filter: SourceFilter) -> Bool { filter.admits(source: source) }

    /// The symbol of the ride in the list; `nil` for a plain Bosch FIT.
    public var sourceBadge: RideSourceBadge? {
        if source == .gpx { return .gpx }
        return attachedSourceFormat == RideSource.gpx.rawValue ? .attachedGPX : nil
    }

    /// `true` if the file held power, so values that come from it (power, work, calories) are there.
    public var hasPowerData: Bool { averagePower != nil || maxPower != nil }
}
