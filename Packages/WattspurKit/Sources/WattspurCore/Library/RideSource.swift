import Foundation

/// The kinds of source file a ride can come from. The raw value is what
/// `Ride.sourceFormat` stores: the lowercase file extension.
public enum RideSource: String, CaseIterable, Sendable {
    case fit, gpx

    /// The source for a file extension, ignoring case; `nil` if it is neither.
    public init?(fileExtension: String) {
        self.init(rawValue: fileExtension.lowercased())
    }
}
