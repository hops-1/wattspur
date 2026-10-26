import Foundation
import Testing
@testable import WattspurCore

@Suite("Route history")
struct RouteHistoryTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func ride(day: Int, minutes: Double, speed: Double? = 6, power: Int? = nil, cadence: Int? = nil,
                      id: UUID = UUID()) -> HighlightRide {
        HighlightRide(id: id, figures: RideFigures(startDate: start.addingTimeInterval(Double(day) * 86_400),
                                                   distance: 12_000, timerTime: minutes * 60,
                                                   averageSpeed: speed, averagePower: power, averageCadence: cadence),
                      timeZone: .gmt)
    }

    @Test("Rides are put in order; the best time is the shortest, the latest the newest")
    func ordersAndMarks() {
        let a = ride(day: 3, minutes: 30), b = ride(day: 1, minutes: 33), c = ride(day: 2, minutes: 28)
        let series = RouteHistory([a, b, c]).series(.duration)
        #expect(series.rideIDs == [b.id, c.id, a.id])
        let expected: [Double] = [1980, 1680, 1800]
        #expect(series.points.map(\.value) == expected)
        #expect(series.bestIndex == 1)
        #expect(series.best?.value == 1680)
        #expect(series.lastIndex == 2)
        #expect(series.isComplete && series.total == 3)
    }

    @Test("For speed and power the highest is the best")
    func highestIsBest() {
        let rides = [ride(day: 0, minutes: 30, speed: 6, power: 120), ride(day: 1, minutes: 30, speed: 7, power: 150),
                     ride(day: 2, minutes: 30, speed: 6.5, power: 140)]
        let history = RouteHistory(rides)
        #expect(history.series(.averageSpeed).bestIndex == 1)
        #expect(history.series(.averagePower).bestIndex == 1)
    }

    @Test("Rides without a value are left out and counted as missing")
    func missingValues() {
        let rides = [ride(day: 0, minutes: 30, power: 100), ride(day: 1, minutes: 30), ride(day: 2, minutes: 30, power: 140)]
        let series = RouteHistory(rides).series(.averagePower)
        #expect(series.count == 2 && series.total == 3 && !series.isComplete)
        #expect(series.mean == 120)
        // The latest ride with a value, not the latest ride.
        #expect(series.lastIndex == 1)
        #expect(RouteHistory(rides).series(.averageCadence).points.isEmpty)
        #expect(RouteHistory(rides).series(.averageCadence).best == nil)
    }

    @Test("The latest ride is compared with the mean of all values")
    func changeOfLast() throws {
        let series = RouteHistory([ride(day: 0, minutes: 30), ride(day: 1, minutes: 33), ride(day: 2, minutes: 27)]).series(.duration)
        #expect(series.mean == 1800)
        let change = try #require(series.changeOfLast)
        #expect(abs(change + 0.1) < 1e-9)
        // One ride has nothing to compare with.
        #expect(RouteHistory([ride(day: 0, minutes: 30)]).series(.duration).changeOfLast == nil)
        #expect(RouteHistory([]).series(.duration).changeOfLast == nil)
    }

    @Test("A tie keeps the earlier ride as the best; the moving average follows the values")
    func tiesAndAverage() {
        let series = RouteHistory([ride(day: 0, minutes: 30), ride(day: 1, minutes: 30), ride(day: 2, minutes: 36)]).series(.duration, window: 2)
        #expect(series.bestIndex == 0)
        let expected: [Double] = [1800, 1800, 1980]
        #expect(series.points.map(\.movingAverage) == expected)
    }

    @Test("A ride without time has no ride time")
    func noTime() {
        #expect(RouteHistory([ride(day: 0, minutes: 0)]).series(.duration).points.isEmpty)
    }
}
