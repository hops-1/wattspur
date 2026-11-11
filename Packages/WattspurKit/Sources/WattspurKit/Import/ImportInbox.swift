import Foundation

/// The folder “On My iPhone › Wattspur › Import” (B-300): FIT and GPX files put there in the Files
/// app are imported when the app opens. Afterwards each file moves on, so it is not read twice:
/// to “Importiert” when it was read (a new ride, an addition, a duplicate), to “Fehler” when not.
/// Only the folders; the import itself is `ImportFlow`, as for every other file.
public struct ImportInbox: Sendable {
    /// The folder names, as the Files app shows them; German like the folder “Bewegung” (V-16).
    public static let inboxName = "Import"
    public static let importedName = "Importiert"
    public static let failedName = "Fehler"
    public static let fileExtensions: Set<String> = ["fit", "gpx"]

    /// The app's documents folder, which holds the three folders.
    public let base: URL

    public init(base: URL) {
        self.base = base
    }

    public var inbox: URL { base.appending(path: Self.inboxName, directoryHint: .isDirectory) }
    public var imported: URL { base.appending(path: Self.importedName, directoryHint: .isDirectory) }
    public var failed: URL { base.appending(path: Self.failedName, directoryHint: .isDirectory) }

    /// Makes the inbox, so people find it in the Files app before the first file.
    public func prepare() {
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    }

    /// The FIT and GPX files waiting in the inbox, oldest name first. Other files and folders stay
    /// where they are; iCloud placeholders (“.name.icloud”) are not files yet and wait too.
    public func waitingFiles() -> [URL] {
        prepare()
        let names = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.isRegularFileKey],
                                                                   options: [.skipsHiddenFiles])) ?? []
        return names
            .filter { Self.fileExtensions.contains($0.pathExtension.lowercased()) }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Moves a file out of the inbox: to “Importiert” or, if it could not be read, to “Fehler”.
    /// A name that is taken gets a number (“Fahrt 2.gpx”), so nothing is overwritten.
    @discardableResult
    public func moveAway(_ file: URL, failed didFail: Bool) throws -> URL {
        let folder = didFail ? failed : imported
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = Self.freeName(for: file.lastPathComponent, in: folder)
        try FileManager.default.moveItem(at: file, to: target)
        return target
    }

    /// Moves what the share extension left in `shared` (B-301) into the inbox, where the import
    /// takes it as any other waiting file. The extension puts each share in its own folder there,
    /// written under a hidden name first and renamed when complete, so a share still being written
    /// is skipped. The folders go once they are empty. Returns how many files moved.
    @discardableResult
    public func collectShared(from shared: URL) -> Int {
        let fileManager = FileManager.default
        let folders = (try? fileManager.contentsOfDirectory(at: shared, includingPropertiesForKeys: [.isDirectoryKey],
                                                            options: [.skipsHiddenFiles])) ?? []
        guard !folders.isEmpty else { return 0 }
        prepare()
        var moved = 0
        for folder in folders where (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let files = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                              options: [.skipsHiddenFiles])) ?? []
            for file in files where Self.fileExtensions.contains(file.pathExtension.lowercased()) {
                if (try? fileManager.moveItem(at: file, to: Self.freeName(for: file.lastPathComponent, in: inbox))) != nil {
                    moved += 1
                }
            }
            if ((try? fileManager.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []).isEmpty {
                try? fileManager.removeItem(at: folder)
            }
        }
        return moved
    }

    static func freeName(for name: String, in folder: URL) -> URL {
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appending(path: name)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = folder.appending(path: ext.isEmpty ? "\(stem) \(number)" : "\(stem) \(number).\(ext)")
            number += 1
        }
        return candidate
    }
}
