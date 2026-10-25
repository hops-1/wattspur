import Foundation
import Testing
@testable import WattspurKit

@Suite("Highlights: records, streak, year in review, goals")
struct HighlightsTests {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!
    static let lisbon = TimeZone(identifier: "Europe/Lisbon")!

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = Self.berlin
        return GoalPeriod.calendar(from: c)
    }

    /// Wednesday, 21 October 2026, 18:00 in Berlin.
    var now: Date { date(2026, 10, 21, hour: 18) }

    func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 14, minute: Int = 0, in zone: TimeZone = berlin) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    func ride(_ start: Date, km: Double, minutes: Double = 60, ascent: Int? = nil, speed: Double? = nil,
              power: Int? = nil, zone: TimeZone = berlin) -> HighlightRide {
        HighlightRide(figures: RideFigures(startDate: start, distance: km * 1000, timerTime: minutes * 60,
                                           totalAscent: ascent, averageSpeed: speed, averagePower: power),
                      timeZone: zone)
    }

    // MARK: Records

    @Test("Each record comes from the best ride; ties stay with the earlier ride")
    func records() {
        let early = ride(date(2026, 5, 2), km: 101.6, minutes: 336, ascent: 420, speed: 5.0, power: 140)
        let hilly = ride(date(2026, 8, 16), km: 48.2, minutes: 150, ascent: 612, speed: 5.4, power: 150)
        let fast = ride(date(2026, 10, 19), km: 19.5, minutes: 43, ascent: 166, speed: 7.58, power: 168)
        let sameLength = ride(date(2026, 10, 20), km: 101.6, minutes: 300)
        let records = RideRecords.records([fast, sameLength, hilly, early], calendar: calendar)
        let byKind = Dictionary(uniqueKeysWithValues: records.map { ($0.kind, $0) })

        #expect(records.map(\.kind) == RecordKind.allCases)
        #expect(byKind[.longestDistance]?.rideIDs == [early.id])
        #expect(byKind[.longestDuration]?.rideIDs == [early.id])
        #expect(byKind[.mostAscent]?.value == 612)
        #expect(byKind[.highestAverageSpeed]?.rideIDs == [fast.id])
        #expect(byKind[.highestAveragePower]?.value == 168)
        #expect(byKind[.longestStreak]?.value == 2)
    }

    @Test("Averages of rides under 5 km set no record")
    func shortRidesSetNoAverageRecord() {
        let short = ride(date(2026, 6, 1), km: 4.9, minutes: 8, speed: 10, power: 300)
        let normal = ride(date(2026, 6, 3), km: 20, minutes: 50, speed: 6.6, power: 140)
        let records = RideRecords.records([short, normal], calendar: calendar)
        let speed = records.first { $0.kind == .highestAverageSpeed }
        let power = records.first { $0.kind == .highestAveragePower }
        #expect(speed?.rideIDs == [normal.id])
        #expect(power?.value == 140)
        #expect(RideRecords.records([short], calendar: calendar).contains { $0.kind == .highestAverageSpeed } == false)
    }

    @Test("The streak counts calendar days; two rides on one day count once, a free day ends it")
    func streak() {
        let rides = [
            ride(date(2026, 8, 10, hour: 8), km: 10),
            ride(date(2026, 8, 10, hour: 18), km: 12),
            ride(date(2026, 8, 11), km: 20),
            ride(date(2026, 8, 12), km: 30),
            // 13 August without a ride
            ride(date(2026, 8, 14), km: 5),
            ride(date(2026, 8, 15), km: 5),
        ]
        let streak = RideRecords.longestStreak(rides, calendar: calendar)
        #expect(streak?.days == 3)
        #expect(streak?.rideIDs.count == 4)
        #expect(streak?.firstDay == date(2026, 8, 10, hour: 0))
        #expect(streak?.lastDay == date(2026, 8, 12, hour: 0))
        // A single day is no streak.
        #expect(RideRecords.longestStreak([rides[0]], calendar: calendar) == nil)
    }

    @Test("A ride belongs to the local day where it started, not to the Mac's day")
    func streakUsesLocalDay() {
        // 23:30 in Lisbon is already 00:30 on the next day in Berlin.
        let lateInLisbon = ride(date(2026, 7, 1, hour: 23, minute: 30, in: Self.lisbon), km: 10, zone: Self.lisbon)
        let nextDay = ride(date(2026, 7, 2, hour: 9, in: Self.lisbon), km: 10, zone: Self.lisbon)
        let streak = RideRecords.longestStreak([lateInLisbon, nextDay], calendar: calendar)
        #expect(streak?.days == 2)
    }

    @Test("A new record is announced only when it beats an earlier one")
    func newRecords() {
        let old = ride(date(2026, 9, 1), km: 30, minutes: 80, ascent: 200, speed: 6.25, power: 130)
        let imported = ride(date(2026, 10, 19), km: 19.5, minutes: 43, ascent: 166, speed: 7.58, power: 149)
        let breaks = RideRecords.newRecords(existing: [old], imported: [imported], calendar: calendar)
        #expect(breaks.map(\.kind) == [.highestAverageSpeed, .highestAveragePower])
        #expect(breaks.first?.previousValue == 6.25)
        #expect(breaks.first?.rideID == imported.id)

        // The very first rides announce nothing.
        #expect(RideRecords.newRecords(existing: [], imported: [old, imported], calendar: calendar).isEmpty)
        // Re-importing a ride that is already counted changes nothing.
        #expect(RideRecords.newRecords(existing: [old, imported], imported: [imported], calendar: calendar)
            == RideRecords.newRecords(existing: [old], imported: [imported], calendar: calendar))
    }

    @Test("A longer streak through an imported ride is a new record")
    func newStreakRecord() {
        let monday = ride(date(2026, 10, 12), km: 10)
        let tuesday = ride(date(2026, 10, 13), km: 10)
        let thursday = ride(date(2026, 10, 15), km: 10)
        let wednesday = ride(date(2026, 10, 14), km: 10)
        let breaks = RideRecords.newRecords(existing: [monday, tuesday, thursday], imported: [wednesday], calendar: calendar)
        let streak = breaks.first { $0.kind == .longestStreak }
        #expect(streak?.value == 4)
        #expect(streak?.previousValue == 2)
        #expect(streak?.rideID == wednesday.id)
    }

    @Test("The badge shows only ride records the ride holds now")
    func badge() {
        let a = ride(date(2026, 10, 1), km: 40, minutes: 100, speed: 6.7)
        let b = ride(date(2026, 10, 2), km: 20, minutes: 40, speed: 8.3)
        let records = RideRecords.records([a, b], calendar: calendar)
        #expect(RideRecords.kinds(heldBy: a.id, in: records) == [.longestDistance, .longestDuration])
        #expect(RideRecords.kinds(heldBy: b.id, in: records) == [.highestAverageSpeed])
    }

    // MARK: Year in review

    @Test("Year: sums, months, riding days, change against the year before")
    func yearReview() {
        let rides = [
            ride(date(2025, 6, 1), km: 100),
            ride(date(2026, 3, 5, hour: 8), km: 8, ascent: 50),
            ride(date(2026, 3, 5, hour: 17), km: 12, ascent: 70),
            ride(date(2026, 8, 16), km: 60, ascent: 612),
            ride(date(2026, 10, 19), km: 40),
        ]
        let review = YearReview(rides, year: 2026, calendar: calendar)
        let expectedChange: Double = 0.2
        let march: Double = 20_000
        #expect(review.aggregate.rideCount == 4)
        #expect(review.aggregate.distance == 120_000)
        #expect(review.aggregate.ascent == 732)
        #expect(review.ridingDayCount == 3)
        #expect(review.months[2].distance == march)
        #expect(review.bestMonth == 7)
        #expect(abs((review.distanceChange ?? 0) - expectedChange) < 1e-9)
        #expect(review.days.first?.rideIDs.count == 2)
        #expect(review.days.first?.level == 2)
        #expect(review.records.first { $0.kind == .mostAscent }?.value == 612)
        #expect(YearReview.years(of: rides, calendar: calendar) == [2026, 2025])
    }

    @Test("A year without rides before has no change")
    func yearWithoutPrevious() {
        let review = YearReview([ride(date(2026, 1, 3), km: 10)], year: 2026, calendar: calendar)
        #expect(review.previousYearDistance == nil)
        #expect(review.distanceChange == nil)
        #expect(YearReview([], year: 2026, calendar: calendar).bestMonth == nil)
    }

    @Test("Heatmap levels: none, under 10, 10–25, 25–50, 50 km and more")
    func heatLevels() {
        #expect(HeatLevel.level(forDistance: 0) == 0)
        #expect(HeatLevel.level(forDistance: 9_999) == 1)
        #expect(HeatLevel.level(forDistance: 10_000) == 2)
        #expect(HeatLevel.level(forDistance: 25_000) == 3)
        #expect(HeatLevel.level(forDistance: 49_999) == 3)
        #expect(HeatLevel.level(forDistance: 50_000) == 4)
    }

    // MARK: Goals

    @Test("Weekly goal: Monday to Sunday, progress, time passed, when it was reached")
    func weeklyGoal() {
        let rides = [
            ride(date(2026, 10, 18), km: 50),          // Sunday before: last week
            ride(date(2026, 10, 19, hour: 7), km: 30), // Monday
            ride(date(2026, 10, 20, hour: 7), km: 32), // Tuesday
        ]
        let goal = GoalProgress(metric: .distance, period: .week, target: 100_000, rides: rides, now: now, calendar: calendar)
        let current: Double = 62_000
        let remaining: Double = 38_000
        // Daylight saving time ends on Sunday, 25 October: this week has 169 hours.
        let elapsed: Double = (2 * 24 + 18) / (7 * 24 + 1)
        #expect(goal.current.interval.start == date(2026, 10, 19, hour: 0))
        #expect(goal.current.value == current)
        #expect(goal.remaining == remaining)
        #expect(!goal.current.isReached)
        #expect(goal.reachedAt == nil)
        #expect(abs(goal.elapsedFraction - elapsed) < 1e-9)
        #expect(goal.isOnTrack)
        #expect(goal.history.count == 8)
        #expect(goal.history.last?.value == 50_000)
        #expect(goal.history.last?.interval.end == goal.current.interval.start)
    }

    @Test("Monthly ride goal is reached by the ride that crosses the target")
    func monthlyGoalReached() {
        let rides = (1...12).map { ride(date(2026, 10, $0 + 7), km: 10) }
        let goal = GoalProgress(metric: .rides, period: .month, target: 12, rides: rides, now: now, calendar: calendar)
        #expect(goal.current.isReached)
        #expect(goal.reachedAt == date(2026, 10, 19))
        #expect(goal.remaining == 0)
    }

    @Test("Yearly ascent goal keeps three years of history")
    func yearlyGoal() {
        let rides = [ride(date(2025, 5, 1), km: 30, ascent: 12_500), ride(date(2026, 5, 1), km: 30, ascent: 9_870)]
        let goal = GoalProgress(metric: .ascent, period: .year, target: 12_500, rides: rides, now: now, calendar: calendar)
        #expect(goal.current.value == 9_870)
        #expect(goal.history.map(\.isReached) == [false, false, true])
        #expect(!goal.isOnTrack) // 79 % of the goal, but 80 % of the year has passed
    }

    @Test("Free combinations leave out goals that exist")
    func freeCombinations() {
        let goals = [Goal(metric: .distance, period: .week, target: 100_000), Goal(metric: .ascent, period: .year, target: 12_000)]
        let free = Goal.freeCombinations(besides: goals)
        #expect(free.count == 7)
        #expect(!free.contains { $0.period == .week && $0.metric == .distance })
        #expect(Goal.sorted(goals.reversed()).map(\.period) == [.week, .year])
    }
}
