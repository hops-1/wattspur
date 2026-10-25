import Foundation

/// Time periods for filtering the list (LIST-05) and, later, the analysis (AGG-03).
public enum RidePeriod: String, CaseIterable, Identifiable, Sendable {
    case all, thisWeek, thisMonth, thisYear, last30Days, last365Days

    public var id: Self { self }

    /// The date interval of the period relative to `now`; `nil` means no limit.
    public func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .all:
            return nil
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
        case .last30Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -30, to: now) ?? now, end: now)
        case .last365Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -365, to: now) ?? now, end: now)
        }
    }

    public func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let interval = interval(now: now, calendar: calendar) else { return true }
        return interval.contains(date)
    }
}

/// Sort orders for the ride list (LIST-05).
public enum RideSortOrder: String, CaseIterable, Identifiable, Sendable {
    case date, distance, duration, ascent, averagePower

    public var id: Self { self }
}

/// The values a ride is sorted by; lets the sorting be tested without SwiftData.
public struct RideSortKey: Sendable, Equatable {
    public var startDate: Date
    public var distance: Double
    public var timerTime: TimeInterval
    public var totalAscent: Int?
    public var averagePower: Int?

    public init(startDate: Date, distance: Double, timerTime: TimeInterval, totalAscent: Int?, averagePower: Int?) {
        self.startDate = startDate
        self.distance = distance
        self.timerTime = timerTime
        self.totalAscent = totalAscent
        self.averagePower = averagePower
    }
}

extension RideSortOrder {
    /// `true` if `a` comes before `b`. All orders are descending (largest/newest first);
    /// missing values go last, ties fall back to the newest ride.
    public func areInIncreasingOrder(_ a: RideSortKey, _ b: RideSortKey) -> Bool {
        func compare<T: Comparable>(_ x: T?, _ y: T?) -> Bool? {
            switch (x, y) {
            case let (x?, y?) where x != y: return x > y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return nil
            }
        }
        let result: Bool?
        switch self {
        case .date: result = compare(a.startDate, b.startDate)
        case .distance: result = compare(a.distance, b.distance)
        case .duration: result = compare(a.timerTime, b.timerTime)
        case .ascent: result = compare(a.totalAscent, b.totalAscent)
        case .averagePower: result = compare(a.averagePower, b.averagePower)
        }
        return result ?? (a.startDate > b.startDate)
    }
}

