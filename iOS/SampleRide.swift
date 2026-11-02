import Foundation
import WattspurCore

/// What the overview shows of a ride: read straight from the FIT file with the readers in
/// WattspurCore, without a SwiftData store (the iPhone keeps no library of its own in 0.1).
struct RideItem: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var start: Date
    var summary: RideSummary
    /// The simplified GPS track for the small map.
    var route: [RoutePoint]
}

/// The anonymized sample ride that ships with the app (V-05), shared with the Mac app as a
/// resource (`App/SampleRide.fit`).
enum SampleRide {
    static func load(bundle: Bundle = .main) -> RideItem? {
        guard let url = bundle.url(forResource: "SampleRide", withExtension: "fit"),
              let data = try? Data(contentsOf: url),
              let ride = try? FITRideImporter().parse(data) else { return nil }
        return RideItem(name: String(localized: "Sample Ride"),
                        start: ride.startDate,
                        summary: ride.summary,
                        route: OverviewRoute(samples: ride.samples).segments.first ?? [])
    }
}
