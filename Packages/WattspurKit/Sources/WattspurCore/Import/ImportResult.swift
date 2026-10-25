import Foundation

/// Result of importing one file (feeds the import log, IMP-06).
public struct ImportResult: Sendable, Identifiable {
    public enum Outcome: Sendable {
        case imported(rideID: UUID)
        /// The same ride is already there (same Bosch ID, or the same start and distance; two GPX
        /// files of one tour). The caller decides whether to update it (IMP-02).
        case duplicate(existingRideID: UUID)
        /// A GPX file for a Bosch ride that is already there: the GPX was attached to it (heart rate,
        /// temperature, the source noted) without asking (B-143).
        case attached(rideID: UUID)
        /// A Bosch FIT for a ride that is there as GPX only (B-143). Nothing is changed yet: the app
        /// asks, the watched folder updates the ride with `update(_:with:fileName:)`.
        case fitForGPX(existingRideID: UUID)
        case unsupported
        case failed(RideImportError)

        /// The ride a `duplicate` or `fitForGPX` result refers to.
        public var existingRideID: UUID? {
            switch self {
            case .duplicate(let id), .fitForGPX(let id): id
            default: nil
            }
        }
    }

    public let id = UUID()
    public let fileName: String
    public let outcome: Outcome

    public init(fileName: String, outcome: Outcome) {
        self.fileName = fileName
        self.outcome = outcome
    }
}
