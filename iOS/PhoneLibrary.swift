import CoreData
import CoreTransferable
import UniformTypeIdentifiers
import Foundation
import Observation
import WattspurCore
import WattspurKit

/// The rides the iPhone shows, from its own store (B-216, `PhoneDatabase`), with or without iCloud.
/// It gives them as `RideExchange` values, so the views stay the same as when they showed the Mac's
/// state from a folder (iOS 0.2 to 0.5, ended with 0.6, B-263). Recordings become rides and rides
/// can go to the trash (B-217).
@MainActor @Observable
final class PhoneLibrary {
    /// The last state read from the store; `nil` before the first reading and when the store did not open.
    private(set) var state: RideExchange.Library?
    /// What went wrong when reading last.
    private(set) var problem: String?
    /// Routes loaded in this session, by file name.
    private var routes: [String: RideExchange.Route] = [:]

    /// The iPhone's own store; `nil` only when it did not open (B-264), then `LibraryErrorView` shows.
    let database: PhoneDatabase?
    /// With or without iCloud.
    let mode: PhoneDatabase.Mode
    /// Last sync and problems in iCloud mode (B-220); `nil` otherwise.
    private(set) var syncMonitor: SyncMonitor?
    /// The trash of the store (B-217), newest first.
    private(set) var trash: [PhoneDatabase.TrashedRide] = []

    init(database: PhoneDatabase?, mode: PhoneDatabase.Mode = .local) {
        self.database = database
        self.mode = mode
        // The rides of the Mac's state from iOS 0.2 to 0.5; not read since 0.6 (B-263).
        try? FileManager.default.removeItem(at: .applicationSupportDirectory.appending(path: "Stand vom Mac"))
        guard database != nil else { return }
        reload()
        if mode == .iCloud {
            watchICloud()
            startSyncMerge()
            syncMonitor = SyncMonitor.forLibrary()
            syncMonitor?.start()
        }
    }

    /// Reads the store again (at launch, when the app comes back, on pull to refresh).
    func refresh() async {
        syncMonitor?.refreshAccount()
        reload()
    }

    /// The route of a ride, from this session or the store.
    func route(for ride: RideExchange.Ride) async -> RideExchange.Route? {
        guard let file = ride.routeFile else { return nil }
        if let route = routes[file] { return route }
        let route = database?.route(forRideID: ride.id)
        routes[file] = route
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
    /// Only changes from outside count (R-64): the store's remote changes and the end of an import.
    /// This iPhone's own uploads (exports) and the start of events change nothing to show.
    private func watchICloud() {
        iCloudWatching.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange).map({ _ in () }) {
                self?.scheduleReload()
            }
        })
        iCloudWatching.append(Task { [weak self] in
            let importsEnded = NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification)
                .compactMap { note -> Bool? in
                    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return nil }
                    return event.type == .import && event.endDate != nil ? true : nil
                }
            for await _ in importsEnded {
                self?.scheduleReload()
            }
        })
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

    /// Whether a ride can be shared as GPX: one with GPS.
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
    /// cadence, heart rate and altitude, averaged like on the Mac. Empty for the sample ride.
    func chartPoints(for ride: RideExchange.Ride, axis: ChartAxis = .distance) -> [ChartPoint] {
        database?.chartPoints(forRideID: ride.id, axis: axis) ?? []
    }

    /// Lean, acceleration and sprint and the track by lean angle (B-246); `nil` for the sample
    /// ride and for rides without motion values.
    func motion(for ride: RideExchange.Ride)
        -> (figures: RideMotion, lean: [RideMotion.LeanStretch], surface: [RideMotion.SurfaceStretch])? {
        database?.motion(forRideID: ride.id)
    }

    /// Charts, track and motion of a ride from one reading of its time series (R-33); empty for the
    /// sample ride.
    func detail(for ride: RideExchange.Ride) -> PhoneDatabase.Detail {
        database?.detail(forRideID: ride.id) ?? PhoneDatabase.Detail()
    }

    /// The time series of a ride, to show the spot under the finger on the chart on the map (B-221).
    /// Empty for the sample ride.
    func track(for ride: RideExchange.Ride) -> RideTrack {
        database?.track(forRideID: ride.id) ?? RideTrack(samples: [])
    }

    /// Reads the store again after a file was imported with “Open with” (B-071).
    func reloadAfterImport() {
        reload()
    }

    #if DEBUG
    /// For trying the charts in the simulator: the anonymized sample ride (V-05) as a real ride of the
    /// store, with speed, power, cadence and elevation. Debug builds only, started with
    /// `-WattspurDemoRide YES`; the duplicate check keeps it from coming twice.
    func importSampleRideForTesting() {
        guard let database, let url = Bundle.main.url(forResource: "SampleRide", withExtension: "fit"),
              let data = try? Data(contentsOf: url) else { return }
        database.library.importFile(data: data, fileName: "Testfahrt Beispiel.fit")
        reload()
    }

    /// For trying the map of all rides with many rides (B-227): `-WattspurDemoRides 300` adds that many
    /// copies of the sample ride, one week apart and shifted a little, so the heat map has places
    /// ridden often and seldom. Debug builds only; copies already there are skipped as duplicates.
    func importDemoCopiesForTesting(_ count: Int) {
        guard count > 0, let database, let url = Bundle.main.url(forResource: "SampleRide", withExtension: "fit"),
              let data = try? Data(contentsOf: url) else { return }
        for week in 1...count {
            let shift = Double(week % 7) * 0.004
            guard let copy = try? FITAnonymizer(latitudeOffset: shift, longitudeOffset: Double(week % 5) * 0.006,
                                                trimDistance: 0, weeks: -week).anonymize(data) else { continue }
            database.library.importFile(data: copy, fileName: "Demo \(week).fit")
        }
        reload()
    }
    #endif

    /// The rides for the map of all rides (B-227), filtered like on the Mac; empty without the store.
    func mapOverview(filter: MapFilter) -> MapOverview {
        database?.mapOverview(filter: filter) ?? MapOverview(rides: [])
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
