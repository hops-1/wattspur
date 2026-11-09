import Foundation

/// The way out when the library does not open (B-264, R-41): a damaged file, a failed migration or a
/// bad backup. Before, the app stopped with `fatalError` at every start; now it shows a view with
/// "Show Backups", "Create Diagnostics" and "Start with an Empty Library".
extension LibraryBackup {
    /// The name of the folder that keeps a library set aside by `setAsideDamaged`.
    static let damagedFolderPrefix = "Damaged Library"

    /// Moves the library (file, journal files and blob folder) into a new folder "Damaged Library …"
    /// beside it, so the next open starts with an empty one. Nothing is deleted. Returns the folder, or
    /// `nil` if there was no library file. If a move fails, what was moved goes back.
    @discardableResult
    public static func setAsideDamaged(storeURL: URL, now: Date = .now) throws -> URL? {
        let fm = FileManager.default
        let parent = storeURL.deletingLastPathComponent()
        let names = libraryFileNames(for: storeURL).filter { fm.fileExists(atPath: parent.appending(path: $0).path) }
        guard !names.isEmpty else { return nil }
        let folder = uniqueFolder(named: "\(damagedFolderPrefix) \(timestamp(now))", in: parent)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        var moved: [String] = []
        do {
            for name in names {
                try fm.moveItem(at: parent.appending(path: name), to: folder.appending(path: name))
                moved.append(name)
            }
        } catch {
            for name in moved {
                try? fm.moveItem(at: folder.appending(path: name), to: parent.appending(path: name))
            }
            try? fm.removeItem(at: folder)
            throw error
        }
        return folder
    }

    /// Folders beside the library that hold an older state: backups before iCloud, libraries replaced by a
    /// restore and libraries set aside as damaged; newest first by name.
    public static func keptFolders(storeURL: URL) -> [URL] {
        let fm = FileManager.default
        let parent = storeURL.deletingLastPathComponent()
        var result: [URL] = []
        let backups = LibrarySync.backupFolder(for: storeURL)
        if let items = try? fm.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil) {
            result += items.filter { $0.lastPathComponent.hasPrefix("Wattspur Backup") }
        }
        if let items = try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil) {
            result += items.filter {
                $0.lastPathComponent.hasPrefix("Library Before Restore") || $0.lastPathComponent.hasPrefix(damagedFolderPrefix)
            }
        }
        return result.sorted { $0.lastPathComponent.dropFirst(prefixLength($0)) > $1.lastPathComponent.dropFirst(prefixLength($1)) }
    }

    /// Length of the name before the time stamp, so the folders sort by time across the three kinds.
    private static func prefixLength(_ url: URL) -> Int {
        let name = url.lastPathComponent
        for prefix in ["Wattspur Backup ", "Library Before Restore ", "\(damagedFolderPrefix) "] where name.hasPrefix(prefix) {
            return prefix.count
        }
        return 0
    }
}
