import Foundation
import SwiftData

/// A planned tour in the library (B-372), e.g. from komoot: the line with heights, its figures and
/// the original GPX file. Synced like the other models, so everything is optional or has a default
/// and nothing is unique (rule 2); two imports of one file on two devices are merged by
/// `contentKey` (`SyncMergeService`). New in iOS 1.7 / Mac 1.11: a new table, nothing existing changes.
@Model
public final class PlannedRoute {
    public var id: UUID = UUID()
    public var name: String = ""
    /// The name the file gave the tour, to tell a renamed tour after the sync.
    public var originalName: String = ""
    public var createdAt: Date = Date.now
    /// `PlannedTour.Source` raw value.
    public var sourceRawValue: String = PlannedTour.Source.gpx.rawValue
    /// Metres along the line.
    public var distance: Double = 0
    /// Whole metres; `nil` without heights.
    public var ascent: Int?
    public var descent: Int?
    public var pointCount: Int = 0
    public var isLoop: Bool = false
    /// `PlannedTour.encode(_:)`.
    @Attribute(.externalStorage) public var pointsData: Data?
    /// `PlannedTour.contentKey`: the same file gives the same key on every device.
    public var contentKey: String = ""
    /// `PlannedTourReader.parserVersion` the figures were read with.
    public var parserVersion: Int = 0
    /// Set when the tour is in the trash, like a ride (LIST-07/08).
    public var deletedAt: Date?
    /// The original file, for “Share GPX” and for reading it again.
    public var sourceFileName: String = ""
    @Attribute(.externalStorage) public var sourceData: Data?

    public init(name: String, tour: PlannedTour) {
        self.name = name
        originalName = name
        apply(tour)
    }

    func apply(_ tour: PlannedTour) {
        sourceRawValue = tour.source.rawValue
        distance = tour.distance
        ascent = tour.ascent
        descent = tour.descent
        pointCount = tour.points.count
        isLoop = tour.isLoop
        pointsData = PlannedTour.encode(tour.points)
        contentKey = tour.contentKey
        parserVersion = PlannedTourReader.parserVersion
    }

    public var source: PlannedTour.Source { PlannedTour.Source(rawValue: sourceRawValue) ?? .gpx }

    public var isInTrash: Bool { deletedAt != nil }

    /// The points of the line; empty when none are stored or they cannot be read.
    public var points: [PlannedTour.Point] { pointsData.flatMap(PlannedTour.decodePoints) ?? [] }

    /// The tour as a value, for the views and the map.
    public var tour: PlannedTour {
        var tour = PlannedTour(name: name, points: [], source: source)
        tour.points = points
        tour.distance = distance
        tour.ascent = ascent
        tour.descent = descent
        return tour
    }

    /// Tours outside the trash, for `@Query`.
    public static var listedPredicate: Predicate<PlannedRoute> {
        #Predicate<PlannedRoute> { $0.deletedAt == nil }
    }
}
