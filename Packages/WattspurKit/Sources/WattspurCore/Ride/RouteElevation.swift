import Foundation

/// The route in pieces by height (B-063, B-283): from blue at the lowest point of the ride to red at
/// the highest, in `levels` steps, for the map on the Mac and the iPhone. Same pieces as the route by
/// lean angle or surface (`RideMotion.Stretch`), so the maps draw them the same way.
public enum RouteElevation {
    /// Steps of the colour scale.
    public static let levels = 8
    /// A ride flatter than this gets a scale of this height around its middle, so a few metres of
    /// noise on a flat ride do not run through all colours.
    public static let minimumRange = 20.0
    /// Seconds between two samples from which the coloured line breaks. Not the 5 s of the lean angle:
    /// a GPX file from another device often has a point only every 5 to 10 s (a ride of 29.10.2026:
    /// median 7 s, 230 of 361 gaps over 5 s), and with 5 s most pieces had one point and were not
    /// drawn. Only the gap between the parts of a merged ride is this long.
    public static let maxGap = 300.0

    /// The colours of the steps as RGB, from blue (low) through green and yellow to red (high), the
    /// same on the Mac and the iPhone and in light and dark.
    public static let palette: [UInt32] = [0x1E5BD8, 0x1C8FD9, 0x16A9B3, 0x3DB86A, 0xA6C93A, 0xF2C230, 0xF08A24, 0xD9342B]

    /// A piece of the route: `band` is the step from 0 (lowest) to `levels - 1` (highest), `nil` where
    /// the samples have no height (grey on the map).
    public typealias Stretch = RideMotion.Stretch<Int?>

    /// The heights the colours stand for.
    public struct Scale: Sendable, Equatable {
        /// The lowest and the highest height of the ride, in metres, for the legend.
        public var lowest: Double
        public var highest: Double
        /// The heights the first and the last step start from; at least `minimumRange` apart.
        public var low: Double
        public var high: Double

        public init(lowest: Double, highest: Double) {
            self.lowest = lowest
            self.highest = highest
            let missing = max(0, RouteElevation.minimumRange - (highest - lowest))
            low = lowest - missing / 2
            high = highest + missing / 2
        }

        /// The step of a height, 0 to `levels - 1`.
        public func level(of altitude: Double) -> Int {
            let share = (altitude - low) / (high - low)
            return min(RouteElevation.levels - 1, max(0, Int(share * Double(RouteElevation.levels))))
        }
    }

    public struct Result: Sendable, Equatable {
        public var scale: Scale
        public var stretches: [Stretch]
    }

    /// The route in pieces of the same step, broken at pauses like the other colourings; `nil` when no
    /// sample has both a position and a height. The scale goes from the lowest to the highest height
    /// of the samples given, so during a recording it follows the heights ridden so far.
    public static func stretches(_ samples: [RideSample]) -> Result? {
        let heights = samples.compactMap { $0.latitude != nil && $0.longitude != nil ? $0.altitude : nil }
        guard let lowest = heights.min(), let highest = heights.max() else { return nil }
        let scale = Scale(lowest: lowest, highest: highest)
        let stretches = RideMotion.stretches(samples, maxGap: maxGap) { sample -> Int? in sample.altitude.map(scale.level(of:)) }
        return Result(scale: scale, stretches: stretches)
    }

    /// The same from the route the iPhone draws (B-283): the route of a ride, or of the recording so
    /// far, which keeps a point every 10 m with its height. The segments stay apart.
    public static func stretches(_ route: RideExchange.Route) -> Result? {
        var samples: [RideSample] = []
        var time = 0.0
        for segment in route.segments {
            for index in segment.latitude.indices where index < segment.longitude.count {
                let altitude = index < segment.altitude.count ? segment.altitude[index] : nil
                samples.append(RideSample(time: time, latitude: segment.latitude[index],
                                          longitude: segment.longitude[index], altitude: altitude))
                time += 1
            }
            // A gap longer than a pause, so the next segment starts a new piece.
            time += maxGap * 2
        }
        return stretches(samples)
    }
}
