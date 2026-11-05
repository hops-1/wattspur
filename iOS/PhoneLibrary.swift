import CoreData
import CoreTransferable
import UniformTypeIdentifiers
import Foundation
import Observation
import WattspurCore
import WattspurKit

/// The rides the iPhone shows, from one of two places (`PhoneDatabase.Mode`):
/// - **Folder** (iOS 0.2, B-209): the state the Mac writes into `Wattspur Import/iPhone` (B-208), with
///   a copy in the app, so the list also shows without a connection. The iPhone only reads.
/// - **Database** (B-216): the iPhone's own store. It gives the same `RideExchange` values, so the
///   views stay the same; recordings become rides and rides can go to the trash (B-217).
@MainActor @Observable
final class PhoneLibrary {
    enum Status: Equatable {
        /// No folder chosen yet.
        case noFolder
        /// The folder has no state: the setting on the Mac is off.
        case noState
        case loaded
    }

    /// The last state read, from the folder or from the copy.
    private(set) var state: RideExchange.Library?
    private(set) var isLoading = false
    /// What went wrong when reading last; the list then shows the copy.
    private(set) var problem: String?
    /// Routes loaded in this session, by file name.
    private var routes: [String: RideExchange.Route] = [:]

    private let folder: ImportFolder
    /// The iPhone's own store; `nil` in folder mode.
    let database: PhoneDatabase?
    /// Where the rides come from, set at build time.
    let mode: PhoneDatabase.Mode
    /// Last sync and problems in iCloud mode (B-220); `nil` otherwise.
    private(set) var syncMonitor: SyncMonitor?
    /// The trash of the store (B-217), newest first; empty in folder mode.
    private(set) var trash: [PhoneDatabase.TrashedRide] = []
    private let cacheFolder: URL
    private var cachedStateURL: URL { cacheFolder.appending(path: RideExchange.libraryFileName) }
    private var cachedRoutesFolder: URL { cacheFolder.appending(path: RideExchange.routesFolderName) }

    init(folder: ImportFolder, database: PhoneDatabase? = nil, mode: PhoneDatabase.Mode = .folder,
         cacheFolder: URL = .applicationSupportDirectory.appending(path: "Stand vom Mac")) {
        self.folder = folder
        self.database = database
        self.mode = database == nil ? .folder : mode
        self.cacheFolder = cacheFolder
        if database != nil {
            reload()
            if self.mode == .iCloud {
                watchICloud()
                startSyncMerge()
                syncMonitor = SyncMonitor.forLibrary()
                syncMonitor?.start()
            }
        } else if let data = try? Data(contentsOf: cachedStateURL) {
            state = try? RideExchange.library(from: data)
        }
    }

    var usesDatabase: Bool { database != nil }

    var status: Status {
        if state != nil { return .loaded }
        return folder.url == nil ? .noFolder : .noState
    }

    /// Reads the state from the folder again (at launch, when the app comes back, on pull to refresh).
    func refresh() async {
        if database != nil {
            syncMonitor?.refreshAccount()
            reload()
            return
        }
        guard folder.url != nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await folder.readInBackground("\(RideExchange.folderName)/\(RideExchange.libraryFileName)")
            let fresh = try RideExchange.library(from: data)
            state = fresh
            problem = nil
            saveCopy(data, keeping: fresh)
        } catch RideExchange.ReadError.newerSchema {
            problem = String(localized: "The Mac wrote a newer format. Update Wattspur on the iPhone.")
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // The Mac has not written yet; a copy from another folder must not stay.
            if state == nil { problem = nil }
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Forgets the state when another folder is chosen.
    func folderChanged() async {
        state = nil
        routes = [:]
        try? FileManager.default.removeItem(at: cacheFolder)
        await refresh()
    }

    /// The route of a ride: from the store, or from this session, the copy, or the folder.
    func route(for ride: RideExchange.Ride) async -> RideExchange.Route? {
        guard let file = ride.routeFile else { return nil }
        if let route = routes[file] { return route }
        if let database {
            let route = database.route(forRideID: ride.id)
            routes[file] = route
            return route
        }
        let cached = cachedRoutesFolder.appending(path: file)
        if let data = try? Data(contentsOf: cached), let route = try? RideExchange.route(from: data) {
            routes[file] = route
            return route
        }
        guard let data = try? await folder.readInBackground(
            "\(RideExchange.folderName)/\(RideExchange.routesFolderName)/\(file)"),
              let route = try? RideExchange.route(from: data) else { return nil }
        routes[file] = route
        try? FileManager.default.createDirectory(at: cachedRoutesFolder, withIntermediateDirectories: true)
        try? data.write(to: cached, options: .atomic)
        return route
    }

    // MARK: - Database (B-216, B-217)

    /// Reads the rides and the trash from the store again, after every change.
    private func reload() {
        guard let database else { return }
        do {
            state = try database.snapshot(generator: "Wattspur iOS")
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
        trash = database.trash()
    }

    /// The pending reload after changes from iCloud.
    private var pendingReload: Task<Void, Never>?

    /// Reloads when iCloud brought changes from the Mac (B-216). CloudKit imports in batches, and the
    /// links between rides (merged parts) can come a moment after the rides, so the list waits until
    /// the changes have been quiet for a second instead of drawing every half state.
    private func watchICloud() {
        let names: [Notification.Name] = [.NSPersistentStoreRemoteChange, NSPersistentCloudKitContainer.eventChangedNotification]
        for name in names {
            iCloudWatching.append(Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
                    self?.scheduleReload()
                }
            })
        }
    }

    private var iCloudWatching: [Task<Void, Never>] = []

    /// Stops watching iCloud when the app switches to the other way (B-218).
    func close() {
        iCloudWatching.forEach { $0.cancel() }
        iCloudWatching = []
        pendingReload?.cancel()
        syncMerge?.stop()
        syncMonitor?.stop()
    }

    /// Merges the rider and "My eBike" this iPhone made with those from the Mac (B-216).
    private var syncMerge: SyncMergeWatcher?

    private func startSyncMerge() {
        guard let database else { return }
        let watcher = SyncMergeWatcher(library: database.library)
        watcher.onMerge = { [weak self] _ in self?.reload() }
        watcher.start()
        syncMerge = watcher
    }

    private func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    /// Makes a finished recording a ride (B-216): the GPX goes through the Kit's import, as on the Mac.
    /// Returns the id of the new ride, or that of the ride it duplicates.
    @discardableResult
    func saveRecording(gpx: Data, fileName: String) throws -> UUID {
        guard let database else { throw CocoaError(.featureUnsupported) }
        defer { reload() }
        switch database.saveRecording(gpx: gpx, fileName: fileName).outcome {
        case .imported(let id), .attached(let id), .duplicate(let id), .fitForGPX(let id): return id
        case .unsupported: throw CocoaError(.fileReadCorruptFile)
        case .failed(let error): throw error
        }
    }

    /// Whether a ride can be shared as GPX: one of the iPhone's own store with GPS.
    func canShare(_ ride: RideExchange.Ride) -> Bool {
        database != nil && ride.routeFile != nil
    }

    /// The ride as GPX for the share sheet, built only when the user shares.
    func sharedGPX(for ride: RideExchange.Ride) -> SharedGPX {
        SharedGPX(fileName: GPXWriter.fileName(ride.name)) { [weak self] in
            guard let file = self?.database?.gpx(forRideID: ride.id, note: { String(localized: "Bike: \($0)") }) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return file.data
        }
    }

    /// The measurements of a ride for the charts (B-241), from the iPhone's own store: speed, power,
    /// cadence, heart rate and altitude, averaged like on the Mac. Empty in folder mode, whose state
    /// from the Mac has no time series, and for the sample ride.
    func chartPoints(for ride: RideExchange.Ride, axis: ChartAxis = .distance) -> [ChartPoint] {
        database?.chartPoints(forRideID: ride.id, axis: axis) ?? []
    }

    /// Renames a ride and changes its bike (B-240); over iCloud the Mac gets both.
    func edit(_ ride: RideExchange.Ride, name: String, bikeID: UUID?) {
        guard database?.edit(rideID: ride.id, name: name, bikeID: bikeID) == true else { return }
        reload()
    }

    func moveToTrash(_ ride: RideExchange.Ride) {
        database?.moveToTrash(rideID: ride.id)
        reload()
    }

    func restore(_ ride: RideExchange.Ride) {
        database?.restore(rideID: ride.id)
        reload()
    }

    func deletePermanently(_ ride: RideExchange.Ride) {
        database?.deletePermanently(rideID: ride.id)
        routes[ride.id.uuidString] = nil
        reload()
    }

    /// Stores the state and drops routes it no longer names.
    private func saveCopy(_ data: Data, keeping state: RideExchange.Library) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: cachedRoutesFolder, withIntermediateDirectories: true)
        try? data.write(to: cachedStateURL, options: .atomic)
        let named = Set(state.rides.compactMap(\.routeFile))
        for file in (try? fileManager.contentsOfDirectory(atPath: cachedRoutesFolder.path)) ?? [] where !named.contains(file) {
            try? fileManager.removeItem(at: cachedRoutesFolder.appending(path: file))
        }
        routes = routes.filter { named.contains($0.key) }
    }
}

/// A ride as GPX in the share sheet (AirDrop to the Mac, komoot, Files). The file is written when
/// the user picks where it goes, not when the button is drawn.
struct SharedGPX: Transferable {
    static let contentType = UTType(filenameExtension: "gpx") ?? .xml

    let fileName: String
    let make: @MainActor () throws -> Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: contentType) { item in
            try await MainActor.run { try item.make() }
        }
        .suggestedFileName { $0.fileName }
    }
}
