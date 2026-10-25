import Foundation

/// Summary values as delivered by the source file (for Bosch: the FIT `session`).
/// These are the source of truth for display (Requirements 3.3).
public struct RideSummary: Sendable, Equatable {
    public var timerTime: TimeInterval
    public var elapsedTime: TimeInterval
    /// Metres.
    public var distance: Double
    /// Metres per second.
    public var averageSpeed: Double?
    public var maxSpeed: Double?
    /// Watts; Bosch excludes zero values (coasting).
    public var averagePower: Int?
    public var maxPower: Int?
    /// Revolutions per minute; Bosch excludes zero values.
    public var averageCadence: Int?
    public var maxCadence: Int?
    /// Metres.
    public var totalAscent: Int?
    public var totalDescent: Int?

    public init(timerTime: TimeInterval, elapsedTime: TimeInterval, distance: Double,
                averageSpeed: Double? = nil, maxSpeed: Double? = nil,
                averagePower: Int? = nil, maxPower: Int? = nil,
                averageCadence: Int? = nil, maxCadence: Int? = nil,
                totalAscent: Int? = nil, totalDescent: Int? = nil) {
        self.timerTime = timerTime
        self.elapsedTime = elapsedTime
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.averagePower = averagePower
        self.maxPower = maxPower
        self.averageCadence = averageCadence
        self.maxCadence = maxCadence
        self.totalAscent = totalAscent
        self.totalDescent = totalDescent
    }
}

/// One point of the merged time series (at most one per second).
public struct RideSample: Sendable, Equatable, Codable {
    /// Seconds since the ride start.
    public var time: TimeInterval
    public var latitude: Double?
    public var longitude: Double?
    /// Metres.
    public var altitude: Double?
    /// Metres since start.
    public var distance: Double?
    /// Metres per second.
    public var speed: Double?
    /// Watts.
    public var power: Int?
    /// Cadence for display: the last measured value is held until the next one
    /// (Requirements 3.3), so charts have no gaps.
    public var cadence: Int?
    /// `true` only where the source actually measured cadence. Statistics and
    /// zones must use only these samples.
    public var cadenceMeasured: Bool
    /// Beats per minute, where a source has them (B-141, prepared for the GPX import).
    /// Not written into stored data while `nil`, so rides stored before stay byte for byte.
    public var heartRate: Int?
    /// Degrees Celsius, where a source has them (B-141).
    public var temperature: Double?

    public init(time: TimeInterval, latitude: Double? = nil, longitude: Double? = nil,
                altitude: Double? = nil, distance: Double? = nil, speed: Double? = nil,
                power: Int? = nil, cadence: Int? = nil, cadenceMeasured: Bool = false,
                heartRate: Int? = nil, temperature: Double? = nil) {
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.distance = distance
        self.speed = speed
        self.power = power
        self.cadence = cadence
        self.cadenceMeasured = cadenceMeasured
        self.heartRate = heartRate
        self.temperature = temperature
    }
}

/// A ride read from a source file, before it is stored.
public struct ParsedRide: Sendable {
    public var startDate: Date
    public var summary: RideSummary
    public var samples: [RideSample]
    /// `file_id.serial_number`. Not a bike identifier: Bosch exports carry a new value each time.
    public var deviceSerialNumber: UInt64?
    /// Version of the parser that produced this ride (NFR-17).
    public var parserVersion: Int
    /// Rider's mechanical work in kJ, summed over the raw records (each record = 1 s).
    /// `nil` if the source has no power data.
    public var workKilojoules: Double?
    /// `true` if the totals were computed from the track because the source has none of its own,
    /// as with GPX (B-141): the app marks them "estimated".
    public var summaryEstimated: Bool
    /// A name the file suggests (GPX: the track name); `nil` to use the file name.
    public var suggestedName: String?

    public init(startDate: Date, summary: RideSummary, samples: [RideSample],
                deviceSerialNumber: UInt64?, parserVersion: Int, workKilojoules: Double? = nil,
                summaryEstimated: Bool = false, suggestedName: String? = nil) {
        self.startDate = startDate
        self.summary = summary
        self.samples = samples
        self.deviceSerialNumber = deviceSerialNumber
        self.parserVersion = parserVersion
        self.workKilojoules = workKilojoules
        self.summaryEstimated = summaryEstimated
        self.suggestedName = suggestedName
    }
}
