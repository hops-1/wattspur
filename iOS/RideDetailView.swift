import SwiftUI
import WattspurCore

/// A simple detail of a ride (B-205): a larger map you can move, and the key figures.
/// The full tour detail with the elevation profile is B-210 (iOS 0.2).
struct RideDetailView: View {
    var ride: RideItem

    var body: some View {
        List {
            Section {
                RouteMap(route: ride.route, interactive: true)
                    .frame(height: 280)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                LabeledContent("Date", value: RideFormat.date(ride.start))
                LabeledContent("Distance", value: RideFormat.distance(ride.summary.distance))
                LabeledContent("Riding Time", value: RideFormat.duration(ride.summary.timerTime))
                LabeledContent("Total Time", value: RideFormat.duration(ride.summary.elapsedTime))
                if let ascent = ride.summary.totalAscent {
                    LabeledContent("Ascent", value: RideFormat.ascent(ascent))
                }
                if let descent = ride.summary.totalDescent {
                    LabeledContent("Descent", value: RideFormat.ascent(descent))
                }
                if let speed = ride.summary.averageSpeed {
                    LabeledContent("Average Speed", value: Measurement(value: speed, unit: UnitSpeed.metersPerSecond)
                        .formatted(.measurement(width: .abbreviated, usage: .general,
                                                numberFormatStyle: .number.precision(.fractionLength(1)))))
                }
                if let power = ride.summary.averagePower {
                    LabeledContent("Average Power", value: "\(power) W")
                }
            }
        }
        .navigationTitle(ride.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
