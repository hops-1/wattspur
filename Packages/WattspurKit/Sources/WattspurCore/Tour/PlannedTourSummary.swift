import Foundation

/// A planned tour as the list shows it (B-373): the figures and a thinned line for the preview,
/// as a plain value, so the iPhone reads it once off the main thread and never in a view's body.
public struct PlannedTourSummary: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var source: PlannedTour.Source
    /// Metres along the line.
    public var distance: Double
    public var ascent: Int?
    public var descent: Int?
    public var isLoop: Bool
    public var pointCount: Int
    /// At most `PlannedTour.previewPointCount` points of the line, for the small preview.
    public var preview: [PlannedTour.Point]

    public init(id: UUID, name: String, createdAt: Date, source: PlannedTour.Source, distance: Double,
                ascent: Int?, descent: Int?, isLoop: Bool, pointCount: Int, preview: [PlannedTour.Point]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.source = source
        self.distance = distance
        self.ascent = ascent
        self.descent = descent
        self.isLoop = isLoop
        self.pointCount = pointCount
        self.preview = preview
    }
}

/// A planned tour in the trash, with when it was trashed (B-373), like `PhoneDatabase.TrashedRide`.
public struct TrashedPlannedTour: Sendable, Equatable, Identifiable {
    public var tour: PlannedTourSummary
    public var deletedAt: Date
    public var id: UUID { tour.id }

    public init(tour: PlannedTourSummary, deletedAt: Date) {
        self.tour = tour
        self.deletedAt = deletedAt
    }

    /// Days until it is deleted for good, rounded up: `days` right after trashing.
    public func daysLeft(days: Int = 30, now: Date = .now) -> Int {
        let end = deletedAt.addingTimeInterval(TimeInterval(days) * 86_400)
        return max(0, Int((end.timeIntervalSince(now) / 86_400).rounded(.up)))
    }
}

/// Search and filter pills of the tour list (B-373): the name, the distance, loop or one way, and
/// where the tour comes from. Shared by iPhone and iPad.
public struct PlannedTourFilter: Sendable, Equatable {
    /// Loop or from A to B.
    public enum Shape: String, CaseIterable, Identifiable, Sendable {
        case all, loop, oneWay
        public var id: Self { self }
    }

    public var text = ""
    public var distance = RideDistanceBand.all
    public var shape = Shape.all
    /// `nil` for every source.
    public var source: PlannedTour.Source?

    public init(text: String = "", distance: RideDistanceBand = .all, shape: Shape = .all, source: PlannedTour.Source? = nil) {
        self.text = text
        self.distance = distance
        self.shape = shape
        self.source = source
    }

    /// Whether a pill is set (the search does not count).
    public var hasFilters: Bool { distance != .all || shape != .all || source != nil }
    public var isActive: Bool { hasFilters || !trimmedText.isEmpty }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    public func matches(_ tour: PlannedTourSummary) -> Bool {
        let search = trimmedText
        if !search.isEmpty, !tour.name.localizedStandardContains(search) { return false }
        if !distance.contains(tour.distance) { return false }
        switch shape {
        case .all: break
        case .loop: if !tour.isLoop { return false }
        case .oneWay: if tour.isLoop { return false }
        }
        if let source, tour.source != source { return false }
        return true
    }

    /// The tours that pass, in the given order.
    public func apply(_ tours: [PlannedTourSummary]) -> [PlannedTourSummary] {
        tours.filter(matches)
    }
}

extension PlannedTour {
    /// Points of the list's preview: enough for a small line, little to keep in memory.
    public static let previewPointCount = 64

    /// Every n-th point so that at most `count` remain; first and last always stay.
    public static func thinned(_ points: [Point], to count: Int) -> [Point] {
        guard count >= 2, points.count > count else { return points }
        let step = Double(points.count - 1) / Double(count - 1)
        return (0..<count).map { points[Int((Double($0) * step).rounded())] }
    }

    /// One point of the elevation profile.
    public struct ProfilePoint: Sendable, Equatable {
        /// Metres from the start.
        public var distance: Double
        /// Metres above sea level.
        public var altitude: Double
    }

    /// The heights over the distance (B-373), thinned to about `count` points evenly along the
    /// distance; empty when the line has fewer than two heights.
    public static func profile(of points: [Point], count: Int = 300) -> [ProfilePoint] {
        var all: [ProfilePoint] = []
        all.reserveCapacity(points.count)
        var along = 0.0
        var previous: Point?
        for point in points {
            if let previous {
                along += GPXGeo.distance(previous.latitude, previous.longitude, point.latitude, point.longitude)
            }
            previous = point
            if let altitude = point.altitude { all.append(ProfilePoint(distance: along, altitude: altitude)) }
        }
        guard all.count >= 2 else { return [] }
        guard all.count > count, count >= 2, let total = all.last?.distance, total > 0 else { return all }
        // The first point at or after each step along the distance, so long flat parts do not get
        // more points than short steep ones.
        var result: [ProfilePoint] = []
        result.reserveCapacity(count)
        var next = 0.0
        let step = total / Double(count - 1)
        for point in all where point.distance >= next {
            result.append(point)
            next = point.distance + step
        }
        if let last = all.last, result.last != last { result.append(last) }
        return result
    }

    /// The lowest and highest point of the line; `nil` without heights.
    public static func altitudeRange(of points: [Point]) -> ClosedRange<Double>? {
        let heights = points.compactMap(\.altitude)
        guard let low = heights.min(), let high = heights.max() else { return nil }
        return low...high
    }
}
