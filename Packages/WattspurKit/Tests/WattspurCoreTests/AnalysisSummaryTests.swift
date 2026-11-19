import Foundation
import Testing
@testable import WattspurCore

@Suite("Analysis summary, bar metric, highlights summary and comparison marks (B-294)")
struct AnalysisSummaryTests {
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

    func ride(_ y: Int, _ m: Int, _ d: Int, km: Double) -> RideFigures {
        RideFigures(startDate: date(y, m, d), distance: km * 1000, timerTime: km * 150, totalAscent: Int(km * 5),
                    workKilojoules: km * 15)
    }

    var rides: [RideFigures] {
        [ride(2026, 10, 18, km: 20), ride(2026, 10, 5, km: 10), ride(2026, 9, 12, km: 30), ride(2025, 6, 1, km: 40)]
    }

    @Test("A month has its rides, the month before to compare, and buckets over the month")
    func month() throws {
        let summary = AnalysisSummary(all: rides, selected: nil, period: AnalysisPeriod(kind: .month),
                                      groupingChoice: nil, calendar: calendar, now: now)
        #expect(!summary.isSelection)
        #expect(summary.kind == .month)
        #expect(summary.current.rideCount == 2)
        #expect(summary.current.distance == 30_000)
        #expect(summary.previous?.rideCount == 1)
        #expect(summary.previous?.distance == 30_000)
        #expect(summary.change(\.distance) == 0)
        let interval = try #require(summary.interval)
        #expect(interval.start == date(2026, 10, 1, hour: 0))
        #expect(summary.chartInterval == interval)
        #expect(summary.grouping == AnalysisPeriodKind.month.defaultGrouping)
        #expect(!summary.buckets.isEmpty)
        #expect(summary.figures.map(\.startDate) == [date(2026, 10, 5), date(2026, 10, 18)])
    }

    @Test("All rides: no previous period, the chart spans every ride")
    func all() {
        let summary = AnalysisSummary(all: rides, selected: nil, period: AnalysisPeriod(kind: .all),
                                      groupingChoice: .month, calendar: calendar, now: now)
        #expect(summary.current.rideCount == 4)
        #expect(summary.previous == nil)
        #expect(summary.change(\.distance) == nil)
        #expect(summary.grouping == .month)
        #expect(summary.chartInterval?.start ?? .distantFuture <= date(2025, 6, 1))
    }

    @Test("A selection counts only the chosen rides, by week, from the week of the first one")
    func selection() throws {
        let chosen = [rides[2], rides[0]]
        let summary = AnalysisSummary(all: rides, selected: chosen, period: AnalysisPeriod(kind: .month),
                                      groupingChoice: nil, calendar: calendar, now: now)
        #expect(summary.isSelection)
        #expect(summary.interval == nil)
        #expect(summary.previous == nil)
        #expect(summary.current.rideCount == 2)
        #expect(summary.grouping == .week)
        let chart = try #require(summary.chartInterval)
        #expect(chart.start == calendar.dateInterval(of: .weekOfYear, for: rides[2].startDate)?.start)
        #expect(chart.end > rides[0].startDate)
        #expect(summary.figures.first?.startDate == rides[2].startDate)
    }

    @Test("An empty selection has no chart")
    func emptySelection() {
        let summary = AnalysisSummary(all: rides, selected: [], period: AnalysisPeriod(kind: .week),
                                      groupingChoice: nil, calendar: calendar, now: now)
        #expect(summary.current.rideCount == 0)
        #expect(summary.chartInterval == nil)
        #expect(summary.buckets.isEmpty)
    }

    @Test("Bar metric values in km, hours and metres; the stored raw values stay")
    func barMetric() {
        let aggregate = RideAggregate([ride(2026, 10, 18, km: 20)])
        #expect(BarMetric.distance.value(aggregate) == 20)
        #expect(BarMetric.time.value(aggregate) == 3000.0 / 3600)
        #expect(BarMetric.ascent.value(aggregate) == 100)
        #expect(BarMetric.allCases.map(\.rawValue) == ["distance", "time", "ascent"])
        #expect(BarMetric.allCases.map(\.axisUnit) == ["km", "h", "m"])
    }

    @Test("Highlights summary: records and years with the current one, newest first")
    func highlights() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let highlight = rides.map { HighlightRide(figures: $0, timeZone: berlin) }
        let summary = HighlightsSummary(rides: highlight, calendar: calendar)
        #expect(summary.rides == highlight)
        #expect(summary.records == RideRecords.records(highlight, calendar: calendar))
        #expect(summary.years(including: 2027) == [2027, 2026, 2025])
        #expect(summary.years(including: 2026) == [2026, 2025])
    }

    @Test("Comparison marks repeat after four rides; the first line is solid")
    func marks() {
        #expect(ComparisonMarks.dash(0).isEmpty)
        #expect(ComparisonMarks.dash(5) == ComparisonMarks.dash(1))
        #expect(ComparisonMarks.marker(4) == "circle.fill")
        #expect(Set(ComparisonMarks.markers).count == 4)
    }
}
