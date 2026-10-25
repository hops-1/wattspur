import Foundation

extension DuplicateFacts {
    public init(ride: Ride) {
        self.init(source: ride.source, startDate: ride.startDate, distance: ride.distance, rideTime: ride.timerTime,
                  ascent: ride.totalAscent, averagePower: ride.averagePower, pointCount: ride.samples.count,
                  estimated: ride.summaryEstimatedFromGPS)
    }
}
