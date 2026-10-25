import CoreLocation
import MapKit
import SwiftData
import WattspurKit

/// Looks up the time zone of each ride's start location (B-006).
/// Bosch writes `local_timestamp` in UTC, so the file does not tell us the local time.
@MainActor
enum TimeZoneResolver {
    static func resolveMissing(using library: RideLibrary) async {
        for ride in library.ridesWithoutTimeZone() {
            guard let start = ride.startCoordinate,
                  let request = MKReverseGeocodingRequest(location: CLLocation(latitude: start.latitude, longitude: start.longitude)),
                  let zone = try? await request.mapItems.first?.timeZone else { continue }
            ride.timeZoneIdentifier = zone.identifier
        }
        library.save()
    }
}
