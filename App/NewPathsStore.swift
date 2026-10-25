import Observation
import SwiftUI
import WattspurKit

/// "New paths" of every ride (B-115): computed in the background from the overview
/// routes whenever the rides change, and kept for the ride detail and the map.
@MainActor
@Observable
final class NewPathsStore {
    private var results: [UUID: NewPaths.Result] = [:]
    private var key: Int?
    private var running: Task<Void, Never>?

    /// Recomputes when anything that decides "earlier" or the routes has changed.
    func update(_ rides: [Ride]) {
        var hasher = Hasher()
        for ride in rides {
            hasher.combine(ride.id)
            hasher.combine(ride.startDate)
            hasher.combine(ride.overviewRouteVersion)
            hasher.combine(ride.overviewRouteData?.count)
            hasher.combine(ride.deletedAt)
            hasher.combine(ride.isSample)
            hasher.combine(ride.mergedInto?.id)
            hasher.combine(ride.mergedInto?.deletedAt)
        }
        let newKey = hasher.finalize()
        guard newKey != key else { return }
        key = newKey
        let inputs = Ride.newPathInputs(rides)
        running?.cancel()
        running = Task {
            let computed = await Task.detached(priority: .utility) { NewPaths.compute(inputs) }.value
            guard !Task.isCancelled else { return }
            results = computed
        }
    }

    /// A merged ride adds up its parts, each measured against the rides before it.
    func result(for ride: Ride) -> NewPaths.Result? {
        if ride.isMerged {
            let parts = ride.sortedParts.compactMap { results[$0.id] }
            guard !parts.isEmpty else { return nil }
            return NewPaths.Result(routeLength: parts.reduce(0) { $0 + $1.routeLength },
                                   newLength: parts.reduce(0) { $0 + $1.newLength },
                                   stretches: parts.flatMap(\.stretches))
        }
        return results[ride.id]
    }

    /// Kilometres on new paths as a share of the Bosch distance, so they fit the
    /// ride's totals (the overview route is a little shorter than the ride).
    func newDistance(for ride: Ride) -> Double? {
        result(for: ride).map { $0.share * ride.distance }
    }
}

/// "New paths 23 % · 4.5 km" in the ride detail (B-115), with what it means.
struct NewPathsFigure: View {
    let share: Double
    let distance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("New paths")
                Text("new")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .background(Color.newPaths.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: share.formatted(.percent.precision(.fractionLength(0)))).font(.system(size: 28, weight: .semibold))
                Text(verbatim: "· \(RideFormat.distance(distance))").foregroundStyle(.secondary)
            }
            Text("Share of the distance where no earlier ride had passed (50 m grid).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.newPaths.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.newPaths.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }
}

extension Color {
    /// New stretches on the ride's map and their figure: orange, apart from the
    /// accent-coloured route (at least 3:1 against the map, NFR-16).
    static let newPaths = Color.adaptive(light: 0xC2410C, dark: 0xFF8A4C)
}
