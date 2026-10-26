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
            case .similarity: "Most similar"
            case .date: "Newest"
            }
        }
    }

    /// What the rides are compared with: one ride, or a saved route (B-121).
    enum Subject: Hashable {
        case ride(UUID)
        case route(UUID)
    }

    var subject: Subject
    var threshold: Double
    var includeReverse = false
    var sort: Sort = .similarity

    init(referenceID: UUID, threshold: Double) {
        subject = .ride(referenceID)
        self.threshold = threshold
    }

    init(routeID: UUID, threshold: Double, includeReverse: Bool) {
        subject = .route(routeID)
        self.threshold = threshold
        self.includeReverse = includeReverse
    }

    /// The ride asked about; `nil` for a saved route.
    var referenceID: UUID? {
        if case .ride(let id) = subject { id } else { nil }
    }

    /// The saved route asked about; `nil` for a ride.
    var routeID: UUID? {
        if case .route(let id) = subject { id } else { nil }
    }

    var query: RouteSimilarityStore.Query {
        .init(subject: subject, threshold: threshold, includeReverse: includeReverse)
    }

    /// Can the search start from this ride? Needs a route, and the ride has to count (not the sample
    /// ride, not the trash, not a part of a merged ride).
    static func canStart(from ride: Ride) -> Bool {
        ride.countsForSimilarRoutes && ride.overviewRouteData != nil
    }
}

/// Which rides are on the route of one ride or of a saved route, found in the background and kept
/// for the list (B-118); and which rides could become a saved route (B-121).
///
/// The index of all routes is built on the first search and then only when routes or rides change;
/// asking for another ride or another threshold reuses it (ROUTE-08: under a second for 1 000 rides).
@MainActor
@Observable
final class RouteSimilarityStore {
    struct Query: Hashable {
        var subject: SimilarRidesFilter.Subject
        var threshold: Double
        var includeReverse: Bool
    }

    struct Outcome {
        var query: Query
        var key: Int
        var hits: [RouteIndex.Hit]
        /// `false` if the ride or route has no usable shape (no GPS, a few metres).
        var referenceHasRoute: Bool
    }

    /// The saved routes and the rides that could become one, computed in the background.
    struct RouteOverview {
        /// Rides on the same route that belong to no saved route yet, largest first.
        var suggestions: [RouteGrouping.Suggestion]
        /// Ride → the saved route it belongs to.
        var routeOfRide: [UUID: UUID]

        func count(in routeID: UUID) -> Int { routeOfRide.values.filter { $0 == routeID }.count }
    }

    private(set) var outcome: Outcome?
    private(set) var isSearching = false
    private(set) var routes: RouteOverview?

    /// The routes of all rides that count, built once per state of the library.
    private struct Built: Sendable {
        var index: RouteIndex
        var ids: [UUID]
    }

    @ObservationIgnored private var build: (key: Int, task: Task<Built, Never>)?
    @ObservationIgnored private var pending: (key: Int, query: Query)?
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var routesKey: Int?
    @ObservationIgnored private var routesRunning: Task<Void, Never>?

    /// The index for the current rides; builds it in the background unless it is there already.
    private func built(for rides: [Ride]) -> (key: Int, task: Task<Built, Never>) {
        let key = Self.key(rides)
        if let build, build.key == key { return build }
        let entries = RouteIndex.entries(rides)
        let task = Task.detached(priority: .userInitiated) {
            Built(index: RouteIndex(entries), ids: entries.map(\.id))
        }
        build = (key, task)
        return (key, task)
    }

    /// Searches for `filter` (nothing for `nil`); `rides` are the rides of the list. Cheap if nothing
    /// changed since the last call.
    func refresh(_ filter: SimilarRidesFilter?, rides: [Ride], groups: [RouteGroup]) {
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
        if let outcome, outcome.query == query, outcome.key == key { return }
        if let pending, pending.key == key, pending.query == query { return }
        running?.cancel()
        pending = (key, query)
        isSearching = true
        // A saved route is searched by its own copy of the route.
        let route = filter.routeID.flatMap { id in groups.first { $0.id == id }?.referenceRoute }
        let build = built(for: rides)
        running = Task {
            let built = await build.task.value
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) { () -> ([RouteIndex.Hit], Bool) in
                switch query.subject {
                case .ride(let id):
                    return (built.index.similar(to: id, threshold: query.threshold, includeReverse: query.includeReverse),
                            built.index.contains(id))
                case .route:
                    guard let route, let signature = RouteSignature(route) else { return ([], false) }
                    return (built.index.similar(to: signature, threshold: query.threshold, includeReverse: query.includeReverse), true)
                }
            }.value
            guard !Task.isCancelled else { return }
            outcome = Outcome(query: query, key: key, hits: found.0, referenceHasRoute: found.1)
            pending = nil
            isSearching = false
        }
    }

    /// The saved routes' rides and the suggestions for new ones. `threshold` is the similarity new
    /// suggestions use (the setting).
    func refreshRoutes(rides: [Ride], groups: [RouteGroup], threshold: Double) {
        var hasher = Hasher()
        hasher.combine(Self.key(rides))
        hasher.combine(threshold)
        for group in groups {
            hasher.combine(group.id)
            hasher.combine(group.threshold)
            hasher.combine(group.includeReverse)
        }
        let key = hasher.finalize()
        if routesKey == key { return }
        routesKey = key
        routesRunning?.cancel()
        let specs = groups.map(\.spec)
        let build = built(for: rides)
        routesRunning = Task {
            let built = await build.task.value
            guard !Task.isCancelled else { return }
            let overview = await Task.detached(priority: .utility) { () -> RouteOverview in
                let routeOfRide = RouteGrouping.memberships(of: specs, in: built.index)
                let open = built.ids.filter { routeOfRide[$0] == nil }
                return RouteOverview(suggestions: RouteGrouping.suggest(in: built.index, candidates: open, threshold: threshold),
                                     routeOfRide: routeOfRide)
            }.value
            guard !Task.isCancelled else { return }
            routes = overview
        }
    }

    /// How many rides would be on a route at this similarity (for the dialog that saves it). Does
    /// not touch the list.
    func countMatches(of route: OverviewRoute, threshold: Double, includeReverse: Bool, rides: [Ride]) async -> Int {
        let build = built(for: rides)
        let built = await build.task.value
        return await Task.detached(priority: .userInitiated) {
            guard let signature = RouteSignature(route) else { return 0 }
            return built.index.similar(to: signature, threshold: threshold, includeReverse: includeReverse).count
        }.value
    }

    /// The hits for the filter as it is now. Right away for a stricter threshold than the last search
    /// used (the slider stays smooth); a looser one fills in a moment later. `nil` while the search
    /// for this ride has not finished once.
    func hits(for filter: SimilarRidesFilter) -> [RouteIndex.Hit]? {
        guard let outcome, outcome.query.subject == filter.subject else { return nil }
        return outcome.hits.filter {
            $0.score >= filter.threshold && ($0.direction == .same || (filter.includeReverse && $0.direction == .reverse))
        }
    }

    func referenceHasRoute(for filter: SimilarRidesFilter) -> Bool? {
        guard let outcome, outcome.query.subject == filter.subject else { return nil }
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

/// The chip above the list with what the list is filtered by: the ride or saved route, the number of
/// rides, the similarity, the direction and the order. Its own view, so the map of 1.8 can show it too.
struct SimilarRidesBar<MenuContent: View>: View {
    @Binding var filter: SimilarRidesFilter
    let referenceName: String
    /// Rides on the route at this similarity, before the other filters of the list.
    let found: Int
    /// Rides the list shows, after the bike, source and period filters.
    let shown: Int
    let isSearching: Bool
    /// Called when the slider is let go or the direction changes: a saved route keeps what was set.
    var onCommit: () -> Void = {}
    let onClose: () -> Void
    /// The entries of the "⋯" menu: save as a route, rename, dissolve, the saved routes.
    @ViewBuilder let menu: () -> MenuContent

    private var countText: String {
        shown == found ? found.formatted() : String(localized: "\(shown.formatted()) of \(found.formatted())")
    }

    private var title: Text {
        filter.routeID == nil
            ? Text("Similar to: \(referenceName) (\(countText))")
            : Text("Route: \(referenceName) (\(countText))")
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
                title
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if isSearching { ProgressView().controlSize(.mini) }
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(Text("Routes"))
                .accessibilityLabel(Text("Routes"))
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
                Slider(value: percent, in: RouteSimilarity.thresholdRange, step: 0.01) { editing in
                    if !editing { onCommit() }
                }
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
                    Label("Both directions", systemImage: "arrow.left.arrow.right")
                        .lineLimit(1)
                        .fixedSize()
                }
                .toggleStyle(.checkbox)
                .help(Text("Also show rides on this route the other way round"))
                .onChange(of: filter.includeReverse) { onCommit() }
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
                Image(systemName: "scope")
            case .match(let score, let reverse):
                HStack(spacing: 3) {
                    Text(verbatim: score.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit()
                    if reverse { Image(systemName: "arrow.left.arrow.right") }
                }
            }
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary, lineWidth: 1))
        .foregroundStyle(.secondary)
        .help(label)
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
