import Foundation
import SwiftData

/// Goals (B-053) and the saves that views used to do themselves.
struct GoalService: LibraryService {
    let env: LibraryEnvironment
    init(_ env: LibraryEnvironment) { self.env = env }

    @discardableResult
    func addGoal(metric: GoalMetric, period: GoalPeriod, target: Double) -> Goal {
        let goal = Goal(metric: metric, period: period, target: target)
        context.insert(goal)
        save()
        return goal
    }

    func update(_ goal: Goal, metric: GoalMetric, period: GoalPeriod, target: Double) {
        goal.metric = metric
        goal.period = period
        goal.target = target
        save()
    }

    func delete(_ goal: Goal) {
        context.delete(goal)
        save()
    }

    /// Writes changes a caller made to a model object (a bike being edited, the rider's name).
    func save() {
        try? context.save()
    }

    /// Rides whose start has not been looked up for a time zone yet (B-006).
    func ridesWithoutTimeZone() -> [Ride] {
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.timeZoneIdentifier == nil })
        return (try? context.fetch(descriptor)) ?? []
    }
}
