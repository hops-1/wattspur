import Foundation

/// The subset of the FIT profile that Wattspur reads.
/// Numbers follow the Garmin FIT SDK profile (Profile.xlsx).
public enum FITProfile {
    public enum Message {
        public static let fileID: UInt16 = 0
        public static let session: UInt16 = 18
        public static let lap: UInt16 = 19
        public static let record: UInt16 = 20
        public static let event: UInt16 = 21
        public static let deviceInfo: UInt16 = 23
        public static let activity: UInt16 = 34
    }

    /// Field 253 is the timestamp in every message that has one.
    public static let timestampField: UInt8 = 253

    public enum FileID {
        public static let type: UInt8 = 0
        public static let manufacturer: UInt8 = 1
        public static let product: UInt8 = 2
        public static let serialNumber: UInt8 = 3
        public static let timeCreated: UInt8 = 4
    }

    public enum Record {
        public static let positionLat: UInt8 = 0
        public static let positionLong: UInt8 = 1
        public static let altitude: UInt8 = 2
        public static let heartRate: UInt8 = 3
        public static let cadence: UInt8 = 4
        public static let distance: UInt8 = 5
        public static let speed: UInt8 = 6
        public static let power: UInt8 = 7
        public static let enhancedSpeed: UInt8 = 73
        public static let enhancedAltitude: UInt8 = 78
    }

    public enum Session {
        public static let startTime: UInt8 = 2
        public static let sport: UInt8 = 5
        public static let totalElapsedTime: UInt8 = 7
        public static let totalTimerTime: UInt8 = 8
        public static let totalDistance: UInt8 = 9
        public static let avgSpeed: UInt8 = 14
        public static let maxSpeed: UInt8 = 15
        public static let avgCadence: UInt8 = 18
        public static let maxCadence: UInt8 = 19
        public static let avgPower: UInt8 = 20
        public static let maxPower: UInt8 = 21
        public static let totalAscent: UInt8 = 22
        public static let totalDescent: UInt8 = 23
        public static let enhancedAvgSpeed: UInt8 = 124
        public static let enhancedMaxSpeed: UInt8 = 125
    }

    /// Seconds between the Unix epoch and the FIT epoch (1989-12-31 00:00:00 UTC).
    public static let epochOffset: TimeInterval = 631_065_600

    /// Converts semicircles (FIT position unit) to degrees.
    public static func degrees(fromSemicircles value: Double) -> Double {
        value * (180.0 / 2_147_483_648.0)
    }
}

extension Date {
    /// Creates a date from a FIT timestamp (seconds since the FIT epoch).
    public init(fitTimestamp: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(fitTimestamp) + FITProfile.epochOffset)
    }
}
