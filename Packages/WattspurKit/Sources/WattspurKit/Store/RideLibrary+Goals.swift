import Foundation
import SwiftData

/// Goals and the saves that views used to do themselves (B-053).
extension RideLibrary {
    @discardableResult
    public func addGoal(metric: GoalMetric, period: GoalPeriod, target: Double) -> Goal {
        let goal = Goal(metric: metric, period: period, target: target)
        context.insert(goal)
        save()
        return goal
    }

    public func update(_ goal: Goal, metric: GoalMetric, period: GoalPeriod, target: Double) {
        goal.metric = metric
        goal.period = period
        goal.target = target
        save()
    }

    public func delete(_ goal: Goal) {
        context.delete(goal)
        save()
    }

    /// Writes changes a caller made to a model object (a bike being edited, the rider's name).
    public func save() {
        try? context.save()
    }

    /// Rides whose start has not been looked up for a time zone yet (B-006).
    public func ridesWithoutTimeZone() -> [Ride] {
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.timeZoneIdentifier == nil })
        return (try? context.fetch(descriptor)) ?? []
    }
}
