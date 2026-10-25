import AppKit
import Foundation
import Observation
import SwiftData
import WattspurKit

/// Watches the import folder (IMP-05, B-040): imports new files at launch and
/// whenever the folder changes, as long as Wattspur is open.
///
/// The sandbox only allows access to a folder the user picked once; a
/// security-scoped bookmark keeps that permission across launches (NFR-05).
@MainActor
@Observable
final class FolderWatcher {
    /// The folder, if one was chosen and can be opened.
    private(set) var folderURL: URL?
    private(set) var lastChecked: Date?
    private(set) var lastSummary = FolderImport.Summary()
    /// Shown when the folder cannot be opened (moved, deleted, no permission).
    private(set) var problem: String?

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            isEnabled ? start() : stop()
        }
    }

    var hasFolder: Bool { UserDefaults.standard.data(forKey: Keys.bookmark) != nil }

    /// "iCloud Drive › Wattspur Import" or the path below the home folder.
    var displayPath: String? {
        guard let folderURL else { return nil }
        let path = folderURL.path
        let iCloud = Self.iCloudDriveURL.path
        if path.hasPrefix(iCloud) {
            let rest = path.dropFirst(iCloud.count).split(separator: "/").joined(separator: " › ")
            return rest.isEmpty ? "iCloud Drive" : "iCloud Drive › \(rest)"
        }
        return path.replacingOccurrences(of: Self.realHomeURL.path, with: "~")
    }

    private let library: RideLibrary
    private var source: DispatchSourceFileSystemObject?
    private var accessing = false
    private var pendingScan: Task<Void, Never>?
    private var periodicScan: Task<Void, Never>?

    private enum Keys {
        static let enabled = "watchFolderEnabled"
        static let bookmark = "watchFolderBookmark"
    }

    init(context: ModelContext) {
        library = RideLibrary(context: context)
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
    }

    // MARK: - Folder

    /// Uses `url` as the watched folder (from an open panel) and switches watching on.
    func useFolder(_ url: URL) {
        stop()
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Keys.bookmark)
            problem = nil
        } catch {
            problem = String(localized: "Wattspur could not remember this folder.")
            return
        }
        if isEnabled { start() } else { isEnabled = true }
    }

    /// Asks for a folder. With `createImportFolder`, a "Wattspur Import" folder is
    /// created inside the chosen one (unless the user picked such a folder already).
    func chooseFolder(startingAt directory: URL? = nil, createImportFolder: Bool = false) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory ?? Self.iCloudDriveURL
        panel.prompt = String(localized: "Choose")
        panel.message = createImportFolder
            ? String(localized: "Choose where the “Wattspur Import” folder should be. iCloud Drive lets you save exports straight from your iPhone.")
            : String(localized: "Choose the folder that Wattspur watches for new rides.")
        guard panel.runModal() == .OK, var url = panel.url else { return }
        if createImportFolder, url.lastPathComponent != Self.importFolderName {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let child = url.appendingPathComponent(Self.importFolderName, isDirectory: true)
            try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            url = child
        }
        useFolder(url)
    }

    static let importFolderName = "Wattspur Import"

    /// The user's real home folder (in the sandbox, `homeDirectoryForCurrentUser`
    /// points into the app container).
    static var realHomeURL: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var iCloudDriveURL: URL {
        realHomeURL.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    // MARK: - Watching

    /// Opens the folder, imports what is there and watches for changes.
    func start() {
        guard isEnabled, source == nil else { return }
        guard let url = resolveBookmark() else { return }
        accessing = url.startAccessingSecurityScopedResource()
        folderURL = url

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            problem = String(localized: "The folder cannot be opened. Was it moved or deleted?")
            return
        }
        problem = nil
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleScan() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source

        checkNow()
        // Safety net: iCloud sometimes finishes downloads without a folder event.
        periodicScan = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                self?.checkNow()
            }
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        pendingScan?.cancel()
        periodicScan?.cancel()
        if accessing, let folderURL { folderURL.stopAccessingSecurityScopedResource() }
        accessing = false
    }

    /// Imports the files that are in the folder now.
    func checkNow() {
        guard isEnabled, let folderURL else { return }
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            problem = String(localized: "The folder cannot be opened. Was it moved or deleted?")
            return
        }
        let importer = FolderImport(
            library: library, folder: folderURL,
            importedFolderName: String(localized: "folder.imported", defaultValue: "Imported",
                                       comment: "Subfolder of the watched folder for imported files"),
            failedFolderName: String(localized: "folder.failed", defaultValue: "Failed",
                                     comment: "Subfolder of the watched folder for files that could not be read"))
        lastSummary = importer.run()
        lastChecked = .now
    }

    /// Several changes in a row (a file being written, iCloud downloads) lead to one scan.
    private func scheduleScan() {
        pendingScan?.cancel()
        pendingScan = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.checkNow()
        }
    }

    private func resolveBookmark() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: Keys.bookmark) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else {
            problem = String(localized: "The folder cannot be opened. Was it moved or deleted?")
            return nil
        }
        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: Keys.bookmark)
        }
        return url
    }

    // MARK: - Finder

    func showInFinder(relativePath: String? = nil) {
        guard let folderURL else { return }
        if let relativePath {
            NSWorkspace.shared.activateFileViewerSelecting([folderURL.appendingPathComponent(relativePath)])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        }
    }
}
