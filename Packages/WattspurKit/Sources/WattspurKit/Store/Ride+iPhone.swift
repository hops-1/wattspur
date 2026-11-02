import Foundation
import WattspurCore

extension Ride {
    /// `true` for a ride recorded with the Wattspur app on the iPhone (B-213): a GPX whose
    /// `creator` is “Wattspur iOS”. Reads only the first bytes of the stored file.
    public var isFromiPhone: Bool {
        guard source == .gpx, let data = sourceFile?.data else { return false }
        return GPXRideImporter.header(of: data).creator == GPXWriter.iPhoneCreator
    }
}
