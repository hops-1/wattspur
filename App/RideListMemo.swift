import Foundation
import WattspurKit

/// Remembers the last result of a calculation together with its inputs (B-270, R-61).
///
/// SwiftUI evaluates the body of the ride list on every click, selection or hover. Before, each pass
/// filtered, sorted and grouped all rides and worked out the records again; with 1 000 rides the list
/// became sluggish. Now that happens only when the inputs change. A class, held in `@State`, so that
/// storing a result does not make the view draw again.
@MainActor
final class Memo<Key: Equatable, Value> {
    private var last: (key: Key, value: Value)?

    func value(for key: Key, compute: () -> Value) -> Value {
        if let last, last.key == key { return last.value }
        let value = compute()
        last = (key, value)
        return value
    }
}

/// What the ride list filters, sorts and groups by, and what its record stars come from, read from a ride
/// once per pass. Comparing these is cheap; when they are equal, nothing the list shows can have changed.
struct RideListFact: Equatable {
    let id: UUID
    let name: String
    let bikeID: UUID?
    let source: RideSource?
    /// Start, distance, riding time, ascent, average power and curves.
    let sortKey: RideSortKey
    let countsInTotals: Bool
    /// The other values a record is made of (`RideFigures`), so a changed value moves the star.
    let averageSpeed: Double?
    let maxSpeed: Double?
    let maxPower: Int?
    let maxCadence: Int?
    let bestPower1Min: Int?
    let steepestClimb: Double?
    let steepestDescent: Double?

    @MainActor
    init(_ ride: Ride) {
        id = ride.id
        name = ride.name
        bikeID = ride.bike?.id
        source = ride.source
        sortKey = ride.sortKey
        countsInTotals = ride.countsInTotals
        averageSpeed = ride.averageSpeed
        maxSpeed = ride.maxSpeed
        maxPower = ride.maxPower
        maxCadence = ride.maxCadence
        bestPower1Min = ride.bestPower1Min
        steepestClimb = ride.steepestClimb
        steepestDescent = ride.steepestDescent
    }

    var startDate: Date { sortKey.startDate }
    var distance: Double { sortKey.distance }
}

/// The facts of the rides, read once at the start of each pass of the list's body and used by everything
/// in that pass. A class in `@State`, like `Memo`.
@MainActor
final class RideListPass {
    var facts: [RideListFact] = []
}

/// Everything the shown rides depend on besides the rides themselves.
struct RideListInputs: Equatable {
    var facts: [RideListFact]
    var filter: RideFilter
    var source: SourceFilter
    var sortOrder: RideSortOrder
    var scope: Set<UUID>?
    var day: Set<UUID>?
    var similar: SimilarRidesFilter?
    var hits: [UUID: RouteIndex.Hit]?
}
