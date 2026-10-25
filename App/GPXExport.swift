import AppKit
import UniformTypeIdentifiers
import WattspurKit

/// "Export as GPX…" in the ride detail and the list's context menu (B-112, IMP-09):
/// asks where to save the track, then writes it.
@MainActor
enum GPXExport {
    static let contentType = UTType(filenameExtension: "gpx") ?? .xml

    static func save(_ ride: Ride) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = GPXWriter.fileName(ride.name)
        panel.message = String(localized: "The track with time, elevation, power and cadence, e.g. for komoot or a navigation device.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // The bike goes into the file as a note, so other programs show it too (B-136).
        let bike = ride.bike?.name.nonEmpty.map { String(localized: "Bike: \($0)") }
        let data = GPXWriter.document(name: ride.name, segments: ride.gpxSegments, description: bike)
        do {
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
