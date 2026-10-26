import Observation
import SwiftUI
import WattspurKit

/// The ride list shows only rides on the route of one ride (B-118, B-119, ROUTE-02…05).
/// Lives in `ContentView`, so it survives opening a ride and switching sections.
struct SimilarRidesFilter: Equatable {
    enum Sort: String, CaseIterable, Identifiable {
        case similarity, date
        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .similarity: "Most similar first"
            case .date: "Newest first"
            }
        }
    }

    var referenceID: UUID
    var threshold: Double
    var includeReverse = false
    var sort: Sort = .similarity

    var query: RouteSimilarityStore.Query {
        .init(reference: referenceID, threshold: threshold, includeReverse: includeReverse)
    }

    /// Can the search start from this ride? Needs a route, and the ride has to count (not the sample
    /// ride, not the trash, not a part of a merged ride).
    static func canStart(from ride: Ride) -> Bool {
        ride.countsForSimilarRoutes && ride.overviewRouteData != nil
    }
}

/// Which rides are on the route of one ride, found in the background and kept for the list (B-118).
///
/// The index of all routes is built on the first search and then only when routes or rides change;
/// asking for another ride or another threshold reuses it (ROUTE-08: under a second for 1 000 rides).
@MainActor
@Observable
final class RouteSimilarityStore {
    struct Query: Hashable {
        var reference: UUID
        var threshold: Double
        var includeReverse: Bool
    }

    struct Outcome {
        var query: Query
        var hits: [RouteIndex.Hit]
        /// `false` if the ride has no usable route (no GPS, a few metres).
        var referenceHasRoute: Bool
    }

    private(set) var outcome: Outcome?
    private(set) var isSearching = false

    @ObservationIgnored private var index = RouteIndex()
    @ObservationIgnored private var indexKey: Int?
    @ObservationIgnored private var pending: (key: Int, query: Query)?
    @ObservationIgnored private var running: Task<Void, Never>?

    /// Searches for `filter` (nothing for `nil`); `rides` are the rides of the list. Cheap if nothing
    /// changed since the last call.
    func refresh(_ filter: SimilarRidesFilter?, rides: [Ride]) {
        guard let filter else {
            running?.cancel()
            running = nil
            pending = nil
            outcome = nil
            isSearching = false
            return
        }
        let query = filter.query
        let key = Self.key(rides)
        if let outcome, outcome.query == query, key == indexKey { return }
        if let pending, pending.key == key, pending.query == query { return }
        running?.cancel()
        pending = (key, query)
        isSearching = true
        let entries = key == indexKey ? nil : RouteIndex.entries(rides)
        let known = index
        running = Task {
            let found = await Task.detached(priority: .userInitiated) { () -> (RouteIndex, [RouteIndex.Hit], Bool) in
                let index = entries.map { RouteIndex($0) } ?? known
                let hits = index.similar(to: query.reference, threshold: query.threshold, includeReverse: query.includeReverse)
                return (index, hits, index.contains(query.reference))
            }.value
            guard !Task.isCancelled else { return }
            index = found.0
            indexKey = key
            outcome = Outcome(query: query, hits: found.1, referenceHasRoute: found.2)
            pending = nil
            isSearching = false
        }
    }

    /// The hits for the filter as it is now. Right away for a stricter threshold than the last search
    /// used (the slider stays smooth); a looser one fills in a moment later. `nil` while the search
    /// for this ride has not finished once.
    func hits(for filter: SimilarRidesFilter) -> [RouteIndex.Hit]? {
        guard let outcome, outcome.query.reference == filter.referenceID else { return nil }
        return outcome.hits.filter {
            $0.score >= filter.threshold && ($0.direction == .same || (filter.includeReverse && $0.direction == .reverse))
        }
    }

    func referenceHasRoute(for filter: SimilarRidesFilter) -> Bool? {
        guard let outcome, outcome.query.reference == filter.referenceID else { return nil }
        return outcome.referenceHasRoute
    }

    /// Changes whenever a route, or whether a ride takes part, changes.
    private static func key(_ rides: [Ride]) -> Int {
        var hasher = Hasher()
        for ride in rides {
            hasher.combine(ride.id)
            hasher.combine(ride.overviewRouteVersion)
            hasher.combine(ride.overviewRouteData?.count)
            hasher.combine(ride.deletedAt)
            hasher.combine(ride.isSample)
            hasher.combine(ride.mergedInto?.id)
        }
        return hasher.finalize()
    }
}

/// The chip above the list with what the list is filtered by: the ride, the number of rides, the
/// similarity, the direction and the order. Its own view, so the map of 1.8 can show it too.
struct SimilarRidesBar: View {
    @Binding var filter: SimilarRidesFilter
    let referenceName: String
    /// Rides on the route at this similarity, before the other filters of the list.
    let found: Int
    /// Rides the list shows, after the bike, source and period filters.
    let shown: Int
    let isSearching: Bool
    let onClose: () -> Void

    private var countText: String {
        shown == found ? found.formatted() : String(localized: "\(shown.formatted()) of \(found.formatted())")
    }

    /// The slider moves in whole percents.
    private var percent: Binding<Double> {
        Binding(get: { filter.threshold },
                set: { filter.threshold = RouteSimilarity.clampedThreshold(($0 * 100).rounded() / 100) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
                Text("Similar to: \(referenceName) (\(countText))")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if isSearching { ProgressView().controlSize(.mini) }
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .help(Text("Show all rides"))
                .accessibilityLabel(Text("Show all rides"))
            }
            .foregroundStyle(Color.accentColor)

            HStack(spacing: 8) {
                Text("Similarity")
                Slider(value: percent, in: RouteSimilarity.thresholdRange, step: 0.01)
                    .controlSize(.small)
                    .accessibilityLabel(Text("Similarity"))
                    .accessibilityValue(Text(verbatim: filter.threshold.formatted(.percent.precision(.fractionLength(0)))))
                Text(verbatim: filter.threshold.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                Toggle(isOn: $filter.includeReverse) {
                    Label("Opposite direction too", systemImage: "arrow.left.arrow.right")
                }
                .toggleStyle(.checkbox)
                .help(Text("Also show rides on this route the other way round"))
                Spacer(minLength: 4)
                Picker("Sort", selection: $filter.sort) {
                    ForEach(SimilarRidesFilter.Sort.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(Text("Sort"))
            }
        }
        .font(.caption)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// In a row of the filtered list: "Reference" on the ride asked about, else how similar the ride is
/// (and "⇄" if it was ridden the other way).
enum SimilarityBadge: Equatable {
    case reference
    case match(score: Double, reverse: Bool)
}

struct SimilarityTag: View {
    let badge: SimilarityBadge

    var body: some View {
        Group {
            switch badge {
            case .reference:
                Text("Reference")
            case .match(let score, let reverse):
                HStack(spacing: 3) {
                    Text(verbatim: score.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit()
                    if reverse { Image(systemName: "arrow.left.arrow.right") }
                }
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary, lineWidth: 1))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: Text {
        switch badge {
        case .reference: Text("Reference ride")
        case .match(let score, let reverse):
            reverse ? Text("\(score.formatted(.percent.precision(.fractionLength(0)))) similar, opposite direction")
                    : Text("\(score.formatted(.percent.precision(.fractionLength(0)))) similar")
        }
    }
}
