import Foundation

/// How far the recording map is zoomed out (B-363). A fresh `MKMapView` starts with a view of whole
/// continents. When the recording is resumed after a crash, the first fix can come before MapKit's
/// follow mode zooms in; the map then kept that view for the rest of the ride. A distance far beyond
/// any ride counts as "not chosen by the rider" and goes back to the standard zoom around the position.
public enum RecordingMapZoom {
    /// The zoom of a new recording map, in metres from the ground.
    public static let standardDistance = 1_500.0
    /// More than this shows a whole region, not a ride (about 300 km from the ground).
    public static let maximumDistance = 300_000.0

    /// Whether the map shows far more than a ride, or its distance is not known.
    public static func showsTooMuch(_ distance: Double) -> Bool {
        !(distance.isFinite && distance > 0 && distance <= maximumDistance)
    }

    /// The distance to keep while the map turns: the rider's zoom, or the standard one.
    public static func distance(_ current: Double) -> Double {
        showsTooMuch(current) ? standardDistance : current
    }
}
