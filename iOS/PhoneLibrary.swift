import Foundation
import Observation
import WattspurCore

/// The rides from the Mac (B-209): reads the state the Mac writes into `Wattspur Import/iPhone`
/// (B-208) and keeps a copy in the app, so the list also shows without a connection. The iPhone
/// only reads; it never changes a ride.
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
    private let cacheFolder: URL
    private var cachedStateURL: URL { cacheFolder.appending(path: RideExchange.libraryFileName) }
    private var cachedRoutesFolder: URL { cacheFolder.appending(path: RideExchange.routesFolderName) }

    init(folder: ImportFolder, cacheFolder: URL = .applicationSupportDirectory.appending(path: "Stand vom Mac")) {
        self.folder = folder
        self.cacheFolder = cacheFolder
        if let data = try? Data(contentsOf: cachedStateURL) {
            state = try? RideExchange.library(from: data)
        }
    }

    var status: Status {
        if state != nil { return .loaded }
        return folder.url == nil ? .noFolder : .noState
    }

    /// Reads the state from the folder again (at launch, when the app comes back, on pull to refresh).
    func refresh() async {
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

    /// The route of a ride: from this session, the copy, or the folder.
    func route(for ride: RideExchange.Ride) async -> RideExchange.Route? {
        guard let file = ride.routeFile else { return nil }
        if let route = routes[file] { return route }
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
