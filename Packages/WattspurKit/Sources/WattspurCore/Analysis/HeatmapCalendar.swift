import Foundation

/// The calendar arithmetic of the year's heatmap (B-356, S-20), the same on the Mac and the iPad.
/// Without texts: the apps take the names of months and weekdays from their calendar.
public enum HeatmapCalendar {
    /// The days of `year` in weeks of seven, each week a column: empty cells before 1 January
    /// (from the calendar's first weekday on) and after 31 December, so every week is full.
    public static func weeks(year: Int, calendar: Calendar) -> [[Date?]] {
        guard let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let next = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return [] }
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.dateComponents([.day], from: first, to: next).day ?? 365
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<dayCount { cells.append(calendar.date(byAdding: .day, value: offset, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// The month (1 … 12) whose first day lies in `week`, where the heatmap names it; `nil` otherwise.
    public static func monthStarting(in week: [Date?], calendar: Calendar) -> Int? {
        guard let first = week.compactMap({ $0 }).first(where: { calendar.component(.day, from: $0) == 1 }) else { return nil }
        return calendar.component(.month, from: first)
    }
}

extension RideRecord {
    /// How long a record stays marked "New" after the ride that set it was imported.
    public static let newForDays = 7.0

    /// Whether a ride imported in the last `newForDays` days holds the record. `importedAt` gives
    /// the import time of a ride, `nil` for an unknown ride.
    public func isNew(now: Date = .now, importedAt: (UUID) -> Date?) -> Bool {
        let since = now.addingTimeInterval(-Self.newForDays * 86_400)
        return rideIDs.contains { (importedAt($0) ?? .distantPast) > since }
    }
}
