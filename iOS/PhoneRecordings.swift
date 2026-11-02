import Foundation
import Observation
import WattspurCore

/// The rides recorded on this iPhone (B-212): each one is written as GPX into the folder the Mac
/// watches, and a copy stays in the app for sharing (and in the Files app under “On My iPhone ›
/// Wattspur › Aufnahmen”). The overview lists them until the Mac has taken them over.
@MainActor @Observable
final class PhoneRecordings {
    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        var name: String
        /// The first position; the Mac's ride starts there too.
        var startDate: Date
        /// Metres and seconds, for the list and the totals until the Mac has the ride.
        var distance: Double
        var movingTime: TimeInterval
        var bikeID: UUID?
        /// The file in the folder `Wattspur Import`; `nil` when no folder was chosen.
        var folderFileName: String?
        /// The copy in the app's documents.
        var localFileName: String
    }

    enum Status: Equatable {
        /// No folder chosen: the ride is only on the iPhone.
        case onlyHere
        /// Written into the folder, not uploaded to iCloud yet.
        case waitingForiCloud
        /// In iCloud; the Mac has not imported it yet.
        case waitingForMac
        /// The Mac imported it (the file is in its “Imported” folder, or the ride is in its state).
        case takenOver
        /// The Mac could not read it and moved it to its “Failed” folder.
        case failed
    }

    private(set) var entries: [Entry] = []
    private(set) var statuses: [UUID: Status] = [:]

    private let listURL: URL
    let localFolder: URL

    init(listURL: URL = .applicationSupportDirectory.appending(path: "Aufnahmen.json"),
         localFolder: URL = .documentsDirectory.appending(path: "Aufnahmen")) {
        self.listURL = listURL
        self.localFolder = localFolder
        if let data = try? Data(contentsOf: listURL), let entries = try? JSONDecoder().decode([Entry].self, from: data) {
            self.entries = entries
        }
    }

    /// The recordings the Mac does not have yet, newest first.
    var waiting: [Entry] {
        entries.filter { statuses[$0.id] != .takenOver }.sorted { $0.startDate > $1.startDate }
    }

    func localURL(of entry: Entry) -> URL { localFolder.appending(path: entry.localFileName) }

    // MARK: - Saving

    /// Writes the recording as GPX (creator “Wattspur iOS”, the bike as note and as Wattspur
    /// extension, so the Mac assigns it, B-213) into the folder and keeps a copy.
    func save(_ recording: RideRecording, name: String, bike: RideExchange.Bike?, folder: ImportFolder) throws {
        let note = bike.map { String(localized: "Bike: \($0.name)") }
        let data = GPXWriter.document(name: name, segments: recording.gpxSegments, description: note,
                                      creator: GPXWriter.iPhoneCreator, bikeID: bike?.id)
        let fileName = GPXWriter.fileName(name)

        var folderFileName: String?
        if folder.url != nil {
            let taken = Set((try? folder.contents()) ?? [])
            let unique = Self.uniqueName(fileName, taken: taken)
            try folder.write(data, to: unique)
            folderFileName = unique
        }
        try FileManager.default.createDirectory(at: localFolder, withIntermediateDirectories: true)
        let taken = Set((try? FileManager.default.contentsOfDirectory(atPath: localFolder.path)) ?? [])
        let localName = Self.uniqueName(fileName, taken: taken)
        try data.write(to: localFolder.appending(path: localName), options: .atomic)

        let start = recording.segments.first(where: { !$0.isEmpty })?.first?.fix.date ?? recording.startDate
        entries.append(Entry(name: name, startDate: start, distance: recording.distance,
                             movingTime: recording.movingTime, bikeID: bike?.id,
                             folderFileName: folderFileName, localFileName: localName))
        statuses[entries[entries.count - 1].id] = folderFileName == nil ? .onlyHere : .waitingForiCloud
        store()
    }

    /// Removes the recording from the iPhone, and from the folder while the Mac has not taken it.
    func delete(_ entry: Entry, folder: ImportFolder) {
        try? FileManager.default.removeItem(at: localURL(of: entry))
        if statuses[entry.id] != .takenOver, let name = entry.folderFileName {
            try? folder.withAccess { try FileManager.default.removeItem(at: $0.appending(path: name)) }
        }
        entries.removeAll { $0.id == entry.id }
        statuses[entry.id] = nil
        store()
    }

    // MARK: - Status

    /// Looks where each recording is: in the Mac's state, in its “Imported” folder, uploaded or not.
    func refreshStatuses(state: RideExchange.Library?, folder: ImportFolder) async {
        guard let url = folder.url else {
            for entry in entries where statuses[entry.id] != .takenOver { statuses[entry.id] = .onlyHere }
            return
        }
        let entries = entries
        let checked = await Task.detached(priority: .utility) {
            Self.statuses(of: entries, state: state, folder: url)
        }.value
        statuses.merge(checked) { _, new in new }
    }

    nonisolated private static func statuses(of entries: [Entry], state: RideExchange.Library?, folder: URL) -> [UUID: Status] {
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        let fileManager = FileManager.default
        var result: [UUID: Status] = [:]
        for entry in entries {
            if state?.rides.contains(where: { abs($0.startDate.timeIntervalSince(entry.startDate)) < 60 }) == true {
                result[entry.id] = .takenOver
                continue
            }
            guard let name = entry.folderFileName else {
                result[entry.id] = .onlyHere
                continue
            }
            let file = folder.appending(path: name)
            let movedTo = { (folders: [String]) in
                folders.contains { fileManager.fileExists(atPath: folder.appending(path: "\($0)/\(name)").path) }
            }
            if movedTo(importedFolderNames) {
                result[entry.id] = .takenOver
            } else if movedTo(failedFolderNames) {
                result[entry.id] = .failed
            } else if let uploaded = try? file.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded {
                result[entry.id] = uploaded ? .waitingForMac : .waitingForiCloud
            } else {
                // Not in iCloud (a local folder) or gone: nothing to wait for on this side.
                result[entry.id] = fileManager.fileExists(atPath: file.path) ? .waitingForMac : .takenOver
            }
        }
        return result
    }

    /// The Mac's subfolder for imported files, in the languages the Mac app has.
    nonisolated static let importedFolderNames = ["Importiert", "Imported"]
    nonisolated static let failedFolderNames = ["Fehlerhaft", "Failed"]

    /// The last bike chosen when saving, as the default for the next ride.
    var lastBikeID: UUID? {
        get { UserDefaults.standard.string(forKey: "lastRecordingBike").flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "lastRecordingBike") }
    }

    // MARK: - Helpers

    /// “Ride.gpx”, else “Ride 2.gpx” …
    nonisolated static func uniqueName(_ name: String, taken: Set<String>) -> String {
        guard taken.contains(name) else { return name }
        let base = (name as NSString).deletingPathExtension
        var counter = 2
        while taken.contains("\(base) \(counter).gpx") { counter += 1 }
        return "\(base) \(counter).gpx"
    }

    private func store() {
        try? FileManager.default.createDirectory(at: listURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: listURL, options: .atomic) }
    }
}
