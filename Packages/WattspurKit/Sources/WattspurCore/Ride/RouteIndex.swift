import Foundation

/// The routes of many rides, searchable by place (B-116, ROUTE-03, ROUTE-08).
///
/// Every route is sorted into the 50 m cells of the earth it touches, and each cell remembers
/// which routes pass through it. A search starts with the routes that share cells with the one
/// asked about and only compares those exactly (`RouteSimilarity`). That keeps "show similar
/// rides" under a second for a library of a thousand rides, although it compares geometry.
/// Lives in memory; build it once, then `insert` and `remove` as rides change.
public struct RouteIndex: Sendable {
    /// One ride that is similar to the one asked about.
    public struct Hit: Sendable, Equatable, Identifiable {
        public var id: UUID
        /// 0…1 (`RouteSimilarity.Match.score`).
        public var score: Double
        public var direction: RouteSimilarity.Direction

        public init(id: UUID, score: Double, direction: RouteSimilarity.Direction) {
            self.id = id
            self.score = score
            self.direction = direction
        }
    }

    /// A route needs at least this share of its cells near the cells of the other route to be
    /// compared exactly. Deliberately low: the exact comparison decides.
    static let candidateShare = 0.4

    private var slots: [UUID?] = []
    private var signatures: [RouteSignature?] = []
    private var slotOfID: [UUID: Int32] = [:]
    private var freeSlots: [Int32] = []
    /// Cell of the earth → the slots of the routes that touch it.
    private var cells: [Int64: [Int32]] = [:]

    public init() {}

    public var count: Int { slotOfID.count }

    public func contains(_ id: UUID) -> Bool { slotOfID[id] != nil }

    public func signature(of id: UUID) -> RouteSignature? {
        slotOfID[id].flatMap { signatures[Int($0)] }
    }

    /// Adds a ride, or replaces its route. A route without a usable shape (no GPS, a few metres)
    /// removes the ride instead.
    public mutating func insert(_ id: UUID, route: OverviewRoute) {
        remove(id)
        guard let signature = RouteSignature(route) else { return }
        let slot: Int32
        if let free = freeSlots.popLast() {
            slot = free
            slots[Int(slot)] = id
            signatures[Int(slot)] = signature
        } else {
            slot = Int32(slots.count)
            slots.append(id)
            signatures.append(signature)
        }
        slotOfID[id] = slot
        for key in signature.globalCells { cells[key, default: []].append(slot) }
    }

    public mutating func remove(_ id: UUID) {
        guard let slot = slotOfID.removeValue(forKey: id), let signature = signatures[Int(slot)] else { return }
        for key in signature.globalCells {
            guard var list = cells[key] else { continue }
            list.removeAll { $0 == slot }
            if list.isEmpty { cells[key] = nil } else { cells[key] = list }
        }
        slots[Int(slot)] = nil
        signatures[Int(slot)] = nil
        freeSlots.append(slot)
    }

    /// The rides whose route is similar to the one of ride `id`, best first. The ride itself is
    /// not in the list. Empty if the ride is not in the index.
    public func similar(to id: UUID, threshold: Double = RouteSimilarity.defaultThreshold,
                        includeReverse: Bool = false) -> [Hit] {
        guard let signature = signature(of: id) else { return [] }
        return similar(to: signature, excluding: id, threshold: threshold, includeReverse: includeReverse)
    }

    /// Like `similar(to:threshold:includeReverse:)` for a route that is not in the index.
    public func similar(to signature: RouteSignature, excluding excluded: UUID? = nil,
                        threshold: Double = RouteSimilarity.defaultThreshold, includeReverse: Bool = false) -> [Hit] {
        var hits: [Hit] = []
        for slot in candidates(for: signature) {
            guard let id = slots[Int(slot)], id != excluded, let other = signatures[Int(slot)] else { continue }
            guard let match = RouteSimilarity.compare(signature, other, atLeast: threshold),
                  match.isSimilar(threshold: threshold, includeReverse: includeReverse) else { continue }
            hits.append(Hit(id: id, score: match.score, direction: match.direction))
        }
        return hits.sorted { ($0.score, $1.id.uuidString) > ($1.score, $0.id.uuidString) }
    }

    /// The slots of the routes that run through enough of the cells of `signature` (or next to
    /// them). Only a pre-selection.
    func candidates(for signature: RouteSignature) -> [Int32] {
        let queryCells = signature.globalCells
        guard !queryCells.isEmpty else { return [] }
        var shared = [Int32](repeating: 0, count: slots.count)
        var lastCell = [Int32](repeating: -1, count: slots.count)
        for (position, key) in queryCells.enumerated() {
            for neighbour in RouteSignature.globalNeighbours(of: key) {
                guard let list = cells[neighbour] else { continue }
                for slot in list where lastCell[Int(slot)] != Int32(position) {
                    lastCell[Int(slot)] = Int32(position)
                    shared[Int(slot)] += 1
                }
            }
        }
        let needed = Int((Self.candidateShare * Double(queryCells.count)).rounded(.up))
        return shared.indices.compactMap { shared[$0] >= needed && shared[$0] > 0 ? Int32($0) : nil }
    }
}
