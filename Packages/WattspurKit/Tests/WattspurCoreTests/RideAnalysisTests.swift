import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

@Suite("Analysis: sums, averages, periods, buckets, trends")
struct RideAnalysisTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        c.firstWeekday = 2 // Monday
        c.minimumDaysInFirstWeek = 4
        return c
    }

    /// Tuesday, 20 October 2026, 10:00 in Berlin.
    var now: Date { date(2026, 10, 20, hour: 10) }

    func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 14) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func interval(_ from: (Int, Int, Int), _ to: (Int, Int, Int)) -> DateInterval {
        DateInterval(start: date(from.0, from.1, from.2, hour: 0), end: date(to.0, to.1, to.2, hour: 0))
    }

    /// The reference ride (B-005) and a short one.
    var reference: RideFigures {
        RideFigures(startDate: date(2026, 10, 18), distance: 19_543, timerTime: 2916, totalAscent: 166,
                    workKilojoules: 320, averageSpeed: 6.703, averagePower: 135, averageCadence: 60)
    }
    var short: RideFigures {
        RideFigures(startDate: date(2026, 9, 26), distance: 3_900, timerTime: 640, totalAscent: nil,
                    workKilojoules: 90, averageSpeed: 6.1, averagePower: 150, averageCadence: nil)
    }

    @Test("Sums add up; calories and CO₂ use the factors")
    func sums() {
        let a = RideAggregate([reference, short])
        #expect(a.rideCount == 2)
        #expect(a.distance == 23_443)
        #expect(a.timerTime == 3556)
        #expect(a.ascent == 166) // missing ascent counts as 0
        #expect(a.workKilojoules == 410)
        let flowKcal: Double = 410 * 0.97 + 64.0 * 3556.0 / 3600.0 // the Flow formula over the summed work and time
        #expect(abs(a.kilocalories - flowKcal) < 1e-9)
        #expect(abs(a.co2SavedKilograms - 23.443 * 0.159) < 1e-9)
        #expect(a.distancePerRide == 11_721.5)
        #expect(a.timerTimePerRide == 1778)
    }

    @Test("Averages are weighted by ride time and skip rides without the value")
    func weightedAverages() {
        let a = RideAggregate([reference, short])
        #expect(abs(a.averagePower! - (135.0 * 2916 + 150 * 640) / 3556) < 1e-9)
        #expect(abs(a.averageSpeed! - (6.703 * 2916 + 6.1 * 640) / 3556) < 1e-9)
        #expect(a.averageCadence == 60) // only the reference ride has cadence
        #expect(RideAggregate([]).averagePower == nil)
        #expect(RideAggregate([]).distancePerRide == nil)
    }

    @Test("Relative change, nothing to compare when the previous value is missing or zero")
    func change() {
        #expect(Change.relative(from: 100, to: 112) == 0.12)
        #expect(Change.relative(from: 100, to: 75) == -0.25)
        #expect(Change.relative(from: 0, to: 5) == nil)
        #expect(Change.relative(from: nil, to: 5) == nil)
    }

    @Test("Week, month and year step back; the previous period is the whole one before")
    func periods() {
        let week = AnalysisPeriod(kind: .week)
        #expect(week.interval(now: now, calendar: calendar) == interval((2026, 10, 19), (2026, 10, 26)))
        #expect(week.previousInterval(now: now, calendar: calendar) == interval((2026, 10, 12), (2026, 10, 19)))
        #expect(AnalysisPeriod(kind: .week, offset: -2).interval(now: now, calendar: calendar)
                == interval((2026, 10, 5), (2026, 10, 12)))

        let month = AnalysisPeriod(kind: .month)
        #expect(month.interval(now: now, calendar: calendar) == interval((2026, 10, 1), (2026, 11, 1)))
        #expect(month.previousInterval(now: now, calendar: calendar) == interval((2026, 9, 1), (2026, 10, 1)))
        #expect(AnalysisPeriod(kind: .month, offset: -10).interval(now: now, calendar: calendar)
                == interval((2025, 12, 1), (2026, 1, 1)))

        let year = AnalysisPeriod(kind: .year, offset: -1)
        #expect(year.interval(now: now, calendar: calendar) == interval((2025, 1, 1), (2026, 1, 1)))
        #expect(year.previousInterval(now: now, calendar: calendar) == interval((2024, 1, 1), (2025, 1, 1)))

        #expect(AnalysisPeriod(kind: .all).interval(now: now, calendar: calendar) == nil)
        #expect(AnalysisPeriod(kind: .all).previousInterval(now: now, calendar: calendar) == nil)
        #expect(AnalysisPeriod(kind: .month, offset: 3).offset == 0) // no future periods
    }

    @Test("A custom period compares with the same length directly before")
    func customPeriod() {
        let custom = AnalysisPeriod(kind: .custom, customInterval: interval((2026, 9, 1), (2026, 9, 11)))
        #expect(custom.previousInterval(now: now, calendar: calendar) == interval((2026, 8, 22), (2026, 9, 1)))
    }

    @Test("Buckets cover the whole interval, including empty ones")
    func buckets() {
        let rides = [reference, short, RideFigures(startDate: date(2026, 10, 19), distance: 10_000, timerTime: 1800)]
        let weeks = RideAnalysis.buckets(rides, grouping: .week, in: interval((2026, 9, 21), (2026, 10, 26)), calendar: calendar)
        #expect(weeks.map(\.interval.start) == [date(2026, 9, 21, hour: 0), date(2026, 9, 28, hour: 0), date(2026, 10, 5, hour: 0),
                                                date(2026, 10, 12, hour: 0), date(2026, 10, 19, hour: 0)])
        #expect(weeks.map(\.aggregate.rideCount) == [1, 0, 0, 1, 1])
        #expect(weeks[3].aggregate.distance == 19_543)

        let months = RideAnalysis.buckets(rides, grouping: .month, in: interval((2026, 1, 1), (2027, 1, 1)), calendar: calendar)
        #expect(months.count == 12)
        #expect(months[8].aggregate.rideCount == 1)
        #expect(months[9].aggregate.rideCount == 2)

        let days = RideAnalysis.buckets(rides, grouping: .day, in: interval((2026, 10, 19), (2026, 10, 26)), calendar: calendar)
        #expect(days.count == 7)
        #expect(RideAnalysis.buckets(rides, grouping: .day, in: interval((2000, 1, 1), (2026, 1, 1)), calendar: calendar, limit: 50).count == 50)
    }

    @Test("Rides are filtered by interval and sorted oldest first")
    func filtering() {
        let inOctober = RideAnalysis.rides([reference, short], in: interval((2026, 10, 1), (2026, 11, 1)))
        #expect(inOctober == [reference])
        #expect(RideAnalysis.rides([reference, short], in: nil) == [short, reference])
    }

    @Test("Moving average is trailing over the window")
    func movingAverage() {
        #expect(RideAnalysis.movingAverage([2, 4, 6, 8, 10], window: 3) == [2, 3, 4, 6, 8])
        #expect(RideAnalysis.movingAverage([5, 7], window: 5) == [5, 6])
        #expect(RideAnalysis.movingAverage([], window: 5).isEmpty)
        #expect(RideAnalysis.movingAverage([1, 3], window: 0) == [1, 3]) // window below 1 acts as 1
    }

    @Test("Trend points per ride, oldest first, rides without the value skipped")
    func trend() {
        let third = RideFigures(startDate: date(2026, 10, 19), distance: 10_000, timerTime: 1800, averagePower: 120, averageCadence: 66)
        let power = RideAnalysis.trend([reference, third, short], metric: .averagePower, window: 2)
        #expect(power.map(\.value) == [150, 135, 120])
        #expect(power.map(\.movingAverage) == [150, 142.5, 127.5])

        let cadence = RideAnalysis.trend([reference, third, short], metric: .averageCadence)
        #expect(cadence.map(\.value) == [60, 66])
        #expect(TrendMetric.averageSpeed.value(of: RideAggregate([reference])) == 6.703)
    }
}
