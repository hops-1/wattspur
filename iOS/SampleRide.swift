import Foundation
import WattspurCore

/// The anonymized sample ride that ships with the app (V-05), shared with the Mac app as a
/// resource (`App/SampleRide.fit`). Until the Mac has written a state, the overview shows it, in
/// the same form as a ride from the Mac, so the tiles look like they will.
enum SampleRide {
    static func load(bundle: Bundle = .main) -> (ride: RideExchange.Ride, route: RideExchange.Route)? {
        guard let url = bundle.url(forResource: "SampleRide", withExtension: "fit"),
              let data = try? Data(contentsOf: url),
              let parsed = try? FITRideImporter().parse(data) else { return nil }
        let id = UUID()
        let s = parsed.summary
        let metrics = RideMetrics(ride: parsed)
        let ride = RideExchange.Ride(id: id, name: String(localized: "Sample Ride"), startDate: parsed.startDate,
                                     source: "fit", timerTime: s.timerTime, elapsedTime: s.elapsedTime,
                                     distance: s.distance, averageSpeed: s.averageSpeed, maxSpeed: s.maxSpeed,
                                     averagePower: s.averagePower, maxPower: s.maxPower,
                                     averageCadence: s.averageCadence,
                                     totalAscent: s.totalAscent, totalDescent: s.totalDescent,
                                     minAltitude: metrics.minAltitude, maxAltitude: metrics.maxAltitude,
                                     work: metrics.workKilojoules)
        return (ride, RideExchange.Route(rideID: id, recordings: [parsed.samples]))
    }
}
