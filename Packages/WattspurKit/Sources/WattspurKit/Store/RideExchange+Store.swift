import Foundation
import SwiftData
import WattspurCore

/// The iPhone's views show the library in the exchange format (`RideExchange`, B-178). Until iPhone
/// 0.6 the Mac wrote that format into the import folder for the iPhone (B-208); since the folder
/// exchange ended (B-263) only `PhoneDatabase.snapshot` builds it, from the iPhone's own store.
@MainActor
enum ExchangeRides {
    /// The rides of the list: not in the trash, not part of a merged ride, no sample ride.
    static func listed(in context: ModelContext) throws -> [Ride] {
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
