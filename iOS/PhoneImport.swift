import Foundation
import Observation
import WattspurCore
import WattspurKit

/// FIT and GPX files opened with Wattspur on the iPhone (B-071), e.g. shared from the Flow app or
/// opened in the Files app. With the iPhone's own store they go through the same import as on the
/// Mac (`ImportFlow`, B-188): duplicates, a Bosch FIT for a GPX ride, the bike of a GPX file.
@MainActor
@Observable
final class PhoneImport {
    /// Why nothing could happen.
    struct Notice: Identifiable {
        let id = UUID()
        var title: String
        var message: String
    }

    /// The decisions of the import.
    let flow = ImportFlow()
    var notice: Notice?
    /// Copies of the opened files, kept while the flow may still need them.
    private var copies: [URL] = []

    static let fileExtensions: Set<String> = ["fit", "gpx"]

    /// Takes a file the system handed to the app.
    func open(_ url: URL, library: PhoneLibrary) {
        guard Self.fileExtensions.contains(url.pathExtension.lowercased()) else { return }
        guard let data = Self.read(url) else {
            notice = Notice(title: String(localized: "Import Failed"),
                            message: String(localized: "\(url.lastPathComponent) could not be read."))
            return
        }
        // Without the store (it did not open, B-264) the app shows only the way out, so this stays a guard.
        guard let database = library.database else { return }
        let taken = importIntoStore(data, fileName: url.lastPathComponent, database: database, library: library)
        // Only once the file is safe elsewhere: removed before, a failed copy lost it (R-49).
        if taken { Self.removeFromInbox(url) }
    }

    private func importIntoStore(_ data: Data, fileName: String, database: PhoneDatabase, library: PhoneLibrary) -> Bool {
        // The flow works with files; a copy of our own outlives the system's inbox and needs no access rights.
        let folder = FileManager.default.temporaryDirectory.appending(path: "Opened")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appending(path: fileName)
        try? FileManager.default.removeItem(at: copy)
        do {
            try data.write(to: copy)
        } catch {
            notice = Notice(title: String(localized: "Import Failed"), message: error.localizedDescription)
            return false
        }
        copies.append(copy)
        flow.onImported = { [weak library] _ in library?.reloadAfterImport() }
        flow.start([copy], library: database.library) { _, _ in }
        library.reloadAfterImport()
        return true
    }

    /// The library after a decision (bike, update, new ride); the copies go once nothing is open.
    func decided(library: PhoneLibrary) {
        library.reloadAfterImport()
        guard flow.bikeQuestion == nil, flow.comparisons.isEmpty, flow.plainDuplicates == nil else { return }
        for copy in copies { try? FileManager.default.removeItem(at: copy) }
        copies = []
    }

    // MARK: - Files

    private static func read(_ url: URL) -> Data? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }

    /// A file shared from another app lands in Documents/Inbox; once read it can go, so it does
    /// not show up in the Files app under “On My iPhone › Wattspur”.
    private static func removeFromInbox(_ url: URL) {
        guard url.deletingLastPathComponent().lastPathComponent == "Inbox" else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
