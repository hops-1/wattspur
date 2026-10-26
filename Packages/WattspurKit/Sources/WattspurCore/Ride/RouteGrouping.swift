import Foundation

/// Recurring routes: which rides belong to a saved route, and which rides could become one
/// (B-121, ROUTE-07, ROUTE-08).
///
/// A saved route is a reference route plus a threshold and a choice about the other direction.
/// Which rides belong to it is *computed* from the similarity to the reference route, never
/// stored, so a new ride joins on its own and nothing can get out of date. Works on a `RouteIndex`
/// and values only.
public enum RouteGrouping {
    /// At least this many rides on the same route (the reference ride included) are offered as a
    /// route to save (ROUTE-07).
    public static let minimumSuggestion = 3

    /// A saved route, as far as the computation needs to know it.
    public struct Spec: Sendable, Equatable {
        public var id: UUID
        public var route: OverviewRoute
        public var threshold: Double
        public var includeReverse: Bool

        public init(id: UUID, route: OverviewRoute, threshold: Double, includeReverse: Bool) {
            self.id = id
            self.route = route
            self.threshold = threshold
            self.includeReverse = includeReverse
        }
    }

    /// Rides that run on the same route and are not in a saved route yet.
    public struct Suggestion: Sendable, Equatable, Identifiable {
        /// The "middle" ride of the group: the one most similar to the others. Its route becomes
        /// the reference route when the group is saved.
        public var reference: UUID
        /// All rides of the group, the reference ride included; best match first after the reference.
        public var members: [UUID]
        /// Mean similarity of the rides to the reference route, 0…1.
        public var meanScore: Double

        public var id: UUID { reference }
        public var count: Int { members.count }

        public init(reference: UUID, members: [UUID], meanScore: Double) {
            self.reference = reference
            self.members = members
            self.meanScore = meanScore
        }
    }

    // MARK: - Membership

    /// For every ride that belongs to a saved route: which one. A ride that fits several goes to
    /// the one it matches best; at equal scores to the first in `specs`.
    public static func memberships(of specs: [Spec], in index: RouteIndex) -> [UUID: UUID] {
        var best: [UUID: (group: UUID, score: Double)] = [:]
        for spec in specs {
            guard let signature = RouteSignature(spec.route) else { continue }
            for hit in index.similar(to: signature, threshold: spec.threshold, includeReverse: spec.includeReverse) {
                if let known = best[hit.id], known.score >= hit.score { continue }
                best[hit.id] = (spec.id, hit.score)
            }
        }
        return best.mapValues(\.group)
    }

    /// The rides of one saved route with their score and direction, best first.
    public static func members(of spec: Spec, in index: RouteIndex) -> [RouteIndex.Hit] {
        guard let signature = RouteSignature(spec.route) else { return [] }
        return index.similar(to: signature, threshold: spec.threshold, includeReverse: spec.includeReverse)
    }

    // MARK: - Suggestions

    /// Groups of rides on the same route (the same way) among `candidates`, largest first.
    ///
    /// `candidates` are the rides that may be offered (the caller leaves out rides that already
    /// belong to a saved route and rides that do not count). Greedy: a ride that still has no group
    /// looks for its neighbours; with enough of them they form a group, the group's "middle" ride
    /// becomes the reference, and the group is what lies near that reference. The next group is
    /// made from what is left. One question to the index per group (and per ride that has no
    /// group), so it stays cheap for a library of a thousand rides (ROUTE-08).
    public static func suggest(
        in index: RouteIndex, candidates: [UUID], threshold: Double = RouteSimilarity.defaultThreshold,
        minimum: Int = RouteGrouping.minimumSuggestion
    ) -> [Suggestion] {
        var open = Set(candidates.filter(index.contains))
        guard open.count >= minimum else { return [] }

        var suggestions: [Suggestion] = []
        // In the order of the ids, so the result does not depend on the order the caller used.
        for seed in open.sorted(by: { $0.uuidString < $1.uuidString }) where open.contains(seed) {
            let neighbours = index.similar(to: seed, threshold: threshold).filter { open.contains($0.id) }
            guard neighbours.count + 1 >= minimum else { continue }
            let reference = middle(of: [seed] + neighbours.map(\.id), in: index)
            // What the saved route would show: the rides near the reference route, still open.
            let hits = reference == seed
                ? neighbours
                : index.similar(to: reference, threshold: threshold).filter { open.contains($0.id) }
            guard hits.count + 1 >= minimum else { continue }
            let members = [reference] + hits.map(\.id)
            open.subtract(members)
            suggestions.append(Suggestion(
                reference: reference, members: members,
                meanScore: hits.reduce(0) { $0 + $1.score } / Double(hits.count)
            ))
        }
        return suggestions.sorted { ($0.count, $1.reference.uuidString) > ($1.count, $0.reference.uuidString) }
    }

    /// The ride most similar to the others: the highest mean similarity. For a large group it is
    /// measured against a spread sample of the others, so the cost stays small.
    static func middle(of group: [UUID], in index: RouteIndex, sample: Int = 24) -> UUID {
        let step = max(1, group.count / sample)
        let others = group.enumerated().filter { $0.offset % step == 0 }.map(\.element)
        var best = group[0]
        var bestMean = -1.0
        for id in group {
            guard let signature = index.signature(of: id) else { continue }
            var sum = 0.0, count = 0
            for other in others where other != id {
                guard let otherSignature = index.signature(of: other) else { continue }
                sum += RouteSimilarity.compare(signature, otherSignature).score
                count += 1
            }
            let mean = count > 0 ? sum / Double(count) : 0
            // Equal means: the smaller id, so the choice does not depend on the order.
            if mean > bestMean || (mean == bestMean && id.uuidString < best.uuidString) {
                best = id
                bestMean = mean
            }
        }
        return best
    }
}
