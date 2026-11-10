import Foundation
import Observation
import UniformTypeIdentifiers
import WattspurCore
import WattspurKit

/// FIT and GPX files on the iPhone, all through the same import as on the Mac (`ImportFlow`, B-188):
/// duplicates, a Bosch FIT for a GPS recording (B-273), several Bosch parts of one tour (B-274),
/// the bike of a GPX file. They come three ways:
/// - opened with Wattspur or shared to it, one at a time (B-071);
/// - chosen in the file picker, several at once, also from iCloud Drive (B-300);
/// - put into “On My iPhone › Wattspur › Import”, read when the app opens (B-300); afterwards each
///   file moves to “Importiert” or “Fehler”.
/// Many files go one by one with a progress, and a summary comes at the end.
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
    let flow: ImportFlow
    var notice: Notice?
    /// What the last imports did, once every question is answered (B-300).
    var summary: ImportFlow.Summary?
    /// Shows the file picker (B-300), from “Rides” and “More › iCloud & Library”.
    var choosingFiles = false
    /// Copies of the files, kept while the flow may still need them.
    private var copies: [URL] = []
    /// Files of the folder “Import” by their copy; they move once the copy is read.
    private var inboxFiles: [URL: URL] = [:]
    /// Files that could not even be copied; they join the summary.
    private var unreadable: [String] = []

    static let fileExtensions = ImportInbox.fileExtensions
    static let contentTypes: [UTType] = [UTType(filenameExtension: "fit") ?? .data, UTType(filenameExtension: "gpx") ?? .xml]

    /// The folder “Import” and its neighbours in the app's documents, as the Files app shows them.
    static var inbox: ImportInbox { ImportInbox(base: .documentsDirectory) }

    init() {
        flow = ImportFlow()
        flow.stepsThroughFiles = true
    }

    /// Takes a file the system handed to the app (“Open with”, “Share”).
    func open(_ url: URL, library: PhoneLibrary) {
        guard Self.fileExtensions.contains(url.pathExtension.lowercased()) else { return }
        importFiles([url], library: library)
    }

    /// Files chosen in the file picker or opened with the app; several at once (B-300).
    func importFiles(_ urls: [URL], library: PhoneLibrary) {
        let copied = urls.compactMap { url -> URL? in
            let copy = copyIn(url)
            // Only once the file is safe elsewhere: removed before, a failed copy lost it (R-49).
            if copy != nil { Self.removeFromInbox(url) }
            return copy
        }
        start(copied, library: library)
    }

    /// The files waiting in “On My iPhone › Wattspur › Import”, when the app opens (B-300).
    func importWaitingFiles(library: PhoneLibrary) {
        let inbox = Self.inbox
        let waiting = inbox.waitingFiles().filter { original in !inboxFiles.values.contains(original) }
        guard !waiting.isEmpty, library.database != nil else { return }
        var copied: [URL] = []
        for original in waiting {
            if let copy = copyIn(original) {
                inboxFiles[copy] = original
                copied.append(copy)
            } else {
                _ = try? inbox.moveAway(original, failed: true)
            }
        }
        start(copied, library: library)
    }

    private func start(_ copied: [URL], library: PhoneLibrary) {
        // Without the store (it did not open, B-264) the app shows only the way out, so this stays a guard.
        guard let database = library.database else { return }
        guard !copied.isEmpty else {
            finishIfDone(library: library)
            return
        }
        copies += copied
        flow.onImported = { [weak library] _ in library?.reloadAfterImport() }
        flow.start(copied, library: database.library) { [weak self] result, url in
            self?.read(url, failed: { if case .failed = result.outcome { true } else if case .unsupported = result.outcome { true } else { false } }())
        }
    }

    /// A copy was read: its original from the folder “Import” moves on.
    private func read(_ copy: URL, failed: Bool) {
        guard let original = inboxFiles.removeValue(forKey: copy) else { return }
        _ = try? Self.inbox.moveAway(original, failed: failed)
    }

    /// The library after a decision (bike, update, new ride).
    func decided(library: PhoneLibrary) {
        library.reloadAfterImport()
        finishIfDone(library: library)
    }

    /// Once nothing runs or asks: the summary, and the copies go.
    func finishIfDone(library: PhoneLibrary) {
        guard !flow.isBusy else { return }
        library.reloadAfterImport()
        // The flow's own messages make way for the summary.
        flow.report = nil
        flow.attached = nil
        var summary = flow.takeSummary()
        summary.failedFileNames = unreadable + summary.failedFileNames
        unreadable = []
        if !summary.isEmpty { self.summary = summary }
        for copy in copies { try? FileManager.default.removeItem(at: copy) }
        copies = []
    }

    // MARK: - Files

    /// A copy of our own outlives the system's inbox and needs no access rights; each in its own
    /// folder, so two files of the same name do not meet.
    private func copyIn(_ url: URL) -> URL? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let folder = FileManager.default.temporaryDirectory.appending(path: "Opened").appending(path: UUID().uuidString)
        let copy = folder.appending(path: url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // Coordinated, so a file from iCloud Drive is downloaded first.
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readable in
                do { try FileManager.default.copyItem(at: readable, to: copy) } catch { copyError = error }
            }
            if let error = coordinationError ?? copyError { throw error }
            return copy
        } catch {
            unreadable.append(url.lastPathComponent)
            return nil
        }
    }

    /// A file shared from another app lands in Documents/Inbox; once copied it can go, so it does
    /// not show up in the Files app under “On My iPhone › Wattspur”.
    private static func removeFromInbox(_ url: URL) {
        guard url.deletingLastPathComponent().lastPathComponent == "Inbox" else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
