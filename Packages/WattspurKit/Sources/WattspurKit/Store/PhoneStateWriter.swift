import Foundation
import SwiftData
import WattspurCore

/// Writes the state for the iPhone (B-208) in the exchange format (B-178) into the subfolder
/// `iPhone` of the import folder: `Stand.json` with the rides and bikes, and one file per route
/// in `Routen`.
///
/// Routes are written first and only when their file is missing; the file name carries a
/// fingerprint of what the route is made from, so a changed ride gets a new file. `Stand.json`
/// comes last and is replaced in one step, so the iPhone never sees a half-written state or one
/// that names a route not there yet. Route files no longer named are removed afterwards.
@MainActor
public struct PhoneStateWriter {
    public struct Result: Sendable, Equatable {
        public var rides = 0
        public var routesWritten = 0
        public var routesRemoved = 0
    }

    public let context: ModelContext
    let fileManager: FileManager

    /// Seconds between a change and the write, so a burst of changes is written once.
    public static let changeDelay: TimeInterval = 5
    /// Seconds between two writes at least: iCloud uploads every write.
    public static let minimumInterval: TimeInterval = 60

    /// How long to wait before writing after a change: the delay, or the rest of the minute since
    /// the last write. `nil` when nothing was written yet.
    public static func delay(sinceLastWrite: TimeInterval?) -> Duration {
        guard let sinceLastWrite, sinceLastWrite < minimumInterval else { return .seconds(changeDelay) }
        return .seconds(max(changeDelay, minimumInterval - sinceLastWrite))
    }

    public init(context: ModelContext, fileManager: FileManager = .default) {
        self.context = context
        self.fileManager = fileManager
    }

    /// Writes into `importFolder/iPhone`. `generator` names the app, e.g. “Wattspur 1.9 (Mac)”.
    @discardableResult
    public func write(to importFolder: URL, generator: String, now: Date = .now) throws -> Result {
        let folder = importFolder.appending(path: RideExchange.folderName, directoryHint: .isDirectory)
        let routesFolder = folder.appending(path: RideExchange.routesFolderName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: routesFolder, withIntermediateDirectories: true)
        let existing = Set((try? fileManager.contentsOfDirectory(atPath: routesFolder.path)) ?? [])

        var result = Result()
        var exchangeRides: [RideExchange.Ride] = []
        var referenced: Set<String> = []
        let encoder = RideExchange.encoder()
        for ride in try listedRides() {
            var routeFile: String?
            if ride.mayHaveRoute {
                let name = RideExchange.routeFileName(rideID: ride.id, fingerprint: ride.routeFingerprint)
                if existing.contains(name) {
                    routeFile = name
                } else {
                    let route = RideExchange.Route(rideID: ride.id, recordings: ride.gpxSegments.map(\.samples))
                    if route.pointCount > 0 {
                        try encoder.encode(route).write(to: routesFolder.appending(path: name), options: .atomic)
                        result.routesWritten += 1
                        routeFile = name
                    }
                }
            }
            if let routeFile { referenced.insert(routeFile) }
            exchangeRides.append(ride.exchangeRide(routeFile: routeFile))
        }

        let library = RideExchange.Library(generatedAt: now, generator: generator,
                                           bikes: try context.fetch(FetchDescriptor<Bike>()).map(\.exchangeBike),
                                           rides: exchangeRides)
        try encoder.encode(library).write(to: folder.appending(path: RideExchange.libraryFileName), options: .atomic)
        result.rides = exchangeRides.count

        for name in existing.subtracting(referenced) where name.hasSuffix(".json") {
            if (try? fileManager.removeItem(at: routesFolder.appending(path: name))) != nil {
                result.routesRemoved += 1
            }
        }
        return result
    }

    /// The rides of the list: not in the trash, not part of a merged ride, no sample ride.
    func listedRides() throws -> [Ride] {
        try context.fetch(FetchDescriptor<Ride>(predicate: Ride.listedPredicate)).filter { !$0.isSample }
    }
}

extension Ride {
    /// `false` only when the stored overview route says the ride has no GPS.
    var mayHaveRoute: Bool {
        guard let overviewRoute else { return true }
        return !overviewRoute.isEmpty
    }

    /// Changes whenever the route of the ride can have changed: an update from a file, a merge
    /// or a split. Cheap: it reads no time series. Only inline values: the time series lives in a
    /// file of its own, and reading it for every ride while iCloud replaces that file crashed the
    /// iPhone (B-276).
    var routeFingerprint: UInt64 {
        RideExchange.fingerprint(routeFingerprintText)
    }

    private var routeFingerprintText: String {
        if isMerged {
            return sortedParts.map(\.routeFingerprintText).joined(separator: "+")
        }
        return "\(id.uuidString)|\(startDate.timeIntervalSince1970)|\(distance)|\(elapsedTime)|\(overviewRouteData.map { RideExchange.fingerprint(bytes: $0) } ?? 0)|\(overviewRouteVersion)|\(attachedSourceName ?? "")|\(RideExchange.routeSpacing)"
    }

    func exchangeRide(routeFile: String?) -> RideExchange.Ride {
        RideExchange.Ride(id: id, name: name, startDate: startDate, timeZone: timeZoneIdentifier,
                          bikeID: bike?.id, source: sourceFormat, estimated: summaryEstimatedFromGPS,
                          timerTime: timerTime, elapsedTime: elapsedTime, distance: distance,
                          averageSpeed: averageSpeed, maxSpeed: maxSpeed,
                          averagePower: averagePower, maxPower: maxPower, averageCadence: averageCadence,
                          totalAscent: totalAscent, totalDescent: totalDescent,
                          minAltitude: minAltitude, maxAltitude: maxAltitude,
                          work: hasPowerData ? workKilojoules : nil, routeFile: routeFile)
    }
}

extension Bike {
    var exchangeBike: RideExchange.Bike {
        RideExchange.Bike(id: id, name: name, kind: kindRawValue, color: colorRawValue,
                          isEbike: isEbike, isArchived: isArchived)
    }
}
