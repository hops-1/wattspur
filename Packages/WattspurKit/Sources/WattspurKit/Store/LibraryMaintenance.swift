import Foundation

/// The housekeeping that used to run before the first window: it now starts once the window is up,
/// one step at a time, so the window does not wait for it. Each step still runs on the main actor
/// (the model context is not thread-safe); the pauses between them let the window draw.
@MainActor
public final class LibraryMaintenance {
    private var started = false

    public init() {}

    public func run(library: RideLibrary) async {
        guard !started else { return }
        started = true
        await Task.yield()
        // Rides in the trash for more than 30 days are deleted for good (LIST-08).
        library.purgeTrash()
        await Task.yield()
        // Rides imported with an older parser are re-read from their original file (NFR-17).
        library.reparseOutdatedRides()
        await Task.yield()
        // The import log is a help, not an archive (IMP-06).
        library.trimImportLog()
        await Task.yield()
        // Rides imported before v1.4 get their simplified route for the map, in batches (B-104).
        await library.prepareOverviewRoutes()
    }
}
