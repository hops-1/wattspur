import Foundation

/// Imports the files in the watched folder (IMP-05, B-040).
///
/// - Imported rides and duplicates move to the "imported" subfolder, so a ride
///   deleted later is not imported again. A GPX for a Bosch ride is attached to it, a
///   Bosch FIT for a ride that is only a GPX updates that ride, both without asking (B-143).
/// - Files that cannot be read move to the "failed" subfolder.
/// - Files of an unknown type (e.g. GPX for now) stay where they are and are
///   noted in the log only once, so they can be imported once the type is supported.
/// - iCloud placeholders (not downloaded yet) are requested and picked up next time.
@MainActor
public struct FolderImport {
    public struct Summary: Sendable, Equatable {
        public var imported = 0
        public var duplicates = 0
        /// GPX files attached to a Bosch ride that was already there (B-143).
        public var attached = 0
        /// Rides that were only a GPX track and now have the Bosch values of a FIT (B-143).
        public var updated = 0
        public var failed = 0
        /// Unsupported files seen for the first time.
        public var newlyUnsupported = 0
        /// iCloud files that are still downloading.
        public var downloading = 0
        /// IDs of the rides imported in this run.
        public var importedRideIDs: [UUID] = []

        public init() {}
    }

    public let library: RideLibrary
    public let folder: URL
    /// Name of the subfolder for imported files, e.g. "Importiert".
    public var importedFolderName: String
    /// Name of the subfolder for unreadable files, e.g. "Fehlerhaft".
    public var failedFolderName: String
    let fileManager: FileManager

    public init(library: RideLibrary, folder: URL, importedFolderName: String = "Imported",
                failedFolderName: String = "Failed", fileManager: FileManager = .default) {
        self.library = library
        self.folder = folder
        self.importedFolderName = importedFolderName
        self.failedFolderName = failedFolderName
        self.fileManager = fileManager
    }

    /// Looks at every file directly in the folder once. Reading a file's bytes happens off the main
    /// actor (a GPX can be hundreds of megabytes); everything that touches the library stays on it.
    @discardableResult
    public func run(now: Date = .now) async -> Summary {
        var summary = Summary()
        let contents = (try? fileManager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [])) ?? []

        for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = url.lastPathComponent
            if let placeholderFor = Self.iCloudPlaceholderName(name) {
                // ".Ride.fit.icloud" stands for "Ride.fit", which is not downloaded yet.
                try? fileManager.startDownloadingUbiquitousItem(at: folder.appendingPathComponent(placeholderFor))
                summary.downloading += 1
                continue
            }
            guard !name.hasPrefix("."),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }

            guard library.canImport(fileName: name) else {
                if !library.hasRecordedUnsupportedFile(named: name) {
                    library.record(ImportResult(fileName: name, outcome: .unsupported), source: .folder, date: now)
                    summary.newlyUnsupported += 1
                }
                continue
            }

            guard let data = await Self.readData(at: url) else { continue }
            let result = library.importFile(data: data, fileName: name)
            switch result.outcome {
            case .imported(let id):
                summary.imported += 1
                summary.importedRideIDs.append(id)
                library.record(result, source: .folder, movedTo: move(url, to: importedFolderName), date: now)
            case .duplicate:
                summary.duplicates += 1
                library.record(result, source: .folder, movedTo: move(url, to: importedFolderName), date: now)
            case .attached:
                summary.attached += 1
                library.record(result, source: .folder, movedTo: move(url, to: importedFolderName), date: now)
            case .fitForGPX(let id):
                // In the watched folder nobody is asked: the Bosch file replaces the estimate, the
                // name, notes, bike and flags stay (IMP-04).
                if let ride = library.ride(withID: id), (try? library.update(ride, with: data, fileName: name)) != nil {
                    summary.updated += 1
                    library.recordUpdate(of: id, fileName: name, source: .folder, date: now)
                    _ = move(url, to: importedFolderName)
                } else {
                    summary.failed += 1
                    library.record(ImportResult(fileName: name, outcome: .failed(.noRideData)), source: .folder,
                                   movedTo: move(url, to: failedFolderName), date: now)
                }
            case .failed:
                summary.failed += 1
                library.record(result, source: .folder, movedTo: move(url, to: failedFolderName), date: now)
            case .unsupported:
                break // handled above
            }
        }
        return summary
    }

    /// Reads a file on a background thread.
    private static func readData(at url: URL) async -> Data? {
        await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
    }

    /// Moves a file into a subfolder, renaming it ("Ride 2.fit") if the name is taken.
    /// Returns the new path relative to the watched folder, or `nil` if moving failed.
    func move(_ url: URL, to subfolder: String) -> String? {
        let target = folder.appendingPathComponent(subfolder, isDirectory: true)
        try? fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        let base = (url.lastPathComponent as NSString).deletingPathExtension
        let ext = url.pathExtension
        var destination = target.appendingPathComponent(url.lastPathComponent)
        var counter = 2
        while fileManager.fileExists(atPath: destination.path) {
            destination = target.appendingPathComponent(ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)")
            counter += 1
        }
        do {
            try fileManager.moveItem(at: url, to: destination)
            return "\(subfolder)/\(destination.lastPathComponent)"
        } catch {
            return nil
        }
    }

    /// "Ride.fit" for ".Ride.fit.icloud", else `nil`.
    static func iCloudPlaceholderName(_ name: String) -> String? {
        guard name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > ".icloud".count + 1 else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }
}

extension RideLibrary {
    /// `true` if an importer handles this file's extension.
    public func canImport(fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return importers.contains { $0.fileExtensions.contains(ext) }
    }
}
