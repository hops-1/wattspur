import Foundation
import SwiftData
import WattspurCore

extension PlannedRoute {
    /// The tour as the list shows it (B-373), with a thinned line for the preview.
    public var summary: PlannedTourSummary {
        PlannedTourSummary(id: id, name: name, createdAt: createdAt, source: source, distance: distance,
                           ascent: ascent, descent: descent, isLoop: isLoop, pointCount: pointCount,
                           preview: PlannedTour.thinned(points, to: PlannedTour.previewPointCount))
    }
}

/// Planned tours on the iPhone and iPad (B-373): what the detail loads and what the rider changes.
/// The list itself comes with `LibraryReading`. Writes go through `RideLibrary`, as on the Mac.
extension PhoneDatabase {
    /// The whole line and its elevation profile, for the detail; read once when it opens.
    public struct PlannedTourDetail: Sendable, Equatable {
        public var points: [PlannedTour.Point]
        public var profile: [PlannedTour.ProfilePoint]
        public var altitudes: ClosedRange<Double>?
    }

    public func plannedTourDetail(id: UUID) -> PlannedTourDetail? {
        guard let route = library.plannedRoute(withID: id) else { return nil }
        let points = route.points
        return PlannedTourDetail(points: points, profile: PlannedTour.profile(of: points),
                                 altitudes: PlannedTour.altitudeRange(of: points))
    }

    /// A blank name keeps the old one. Returns whether the name changed.
    @discardableResult
    public func renamePlannedTour(id: UUID, to name: String) -> Bool {
        guard let route = library.plannedRoute(withID: id) else { return false }
        let old = route.name
        library.rename(route, to: name)
        return route.name != old
    }

    /// Into the trash for 30 days, like a ride; over iCloud on the other devices too.
    public func movePlannedTourToTrash(id: UUID, at date: Date = .now) {
        guard let route = library.plannedRoute(withID: id), !route.isInTrash else { return }
        library.moveToTrash([route], at: date)
    }

    public func restorePlannedTour(id: UUID) {
        guard let route = library.plannedRoute(withID: id), route.isInTrash else { return }
        library.restore([route])
    }

    /// Deletes one tour from the trash for good, with its original file.
    public func deletePlannedTourPermanently(id: UUID) {
        guard let route = library.plannedRoute(withID: id), route.isInTrash else { return }
        context.delete(route)
        LibrarySave.save(context)
    }

    /// The file for “Share GPX”: the original file as it came (komoot's own), named after the tour.
    /// `nil` when the file is not there (yet), e.g. before iCloud brought it.
    public func plannedTourGPX(id: UUID) -> (fileName: String, data: Data)? {
        guard let route = library.plannedRoute(withID: id), let data = route.sourceData, !data.isEmpty else { return nil }
        return (GPXWriter.fileName(route.name), data)
    }
}
