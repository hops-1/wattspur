import Foundation

/// The stable exchange format (B-178): what the Mac writes for the iPhone (B-208) and the iPhone
/// reads (B-209). JSON with fixed field names, SI units and ISO 8601 dates; documented in
/// `docs/reference/data-exchange.md`. Unlike the backup, it promises to stay readable: new fields
/// may be added, but a field is never renamed or given a new meaning without raising `schemaVersion`.
///
/// The library file holds the rides with their key figures and the bikes; each ride's route is a
/// file of its own, so the list stays small and the iPhone loads a route only when it shows it.
public enum RideExchange {
    /// Raise when a field is removed or changes its meaning (not when one is added).
    public static let schemaVersion = 1
    /// Distance between two route points in metres (B-178: “about one point per 20 m”).
    public static let routeSpacing = 20.0

    /// The rides and bikes of the library, without the time series (`Stand.json`).
    public struct Library: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        /// When the Mac wrote this state.
        public var generatedAt: Date
        /// The writing app, e.g. “Wattspur 1.9 (Mac)”.
        public var generator: String
        public var bikes: [Bike]
        /// Newest first.
        public var rides: [Ride]

        public init(generatedAt: Date, generator: String, bikes: [Bike], rides: [Ride]) {
            self.schemaVersion = RideExchange.schemaVersion
            self.generatedAt = generatedAt
            self.generator = generator
            self.bikes = bikes
            self.rides = rides.sorted { $0.startDate > $1.startDate }
        }
    }

    public struct Bike: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var name: String
        /// `BikeKind` raw value, e.g. “bike” or “cargo”.
        public var kind: String
        /// `BikeColor` raw value, e.g. “blue”.
        public var color: String
        public var isEbike: Bool
        public var isArchived: Bool

        public init(id: UUID, name: String, kind: String, color: String, isEbike: Bool, isArchived: Bool) {
            self.id = id
            self.name = name
            self.kind = kind
            self.color = color
            self.isEbike = isEbike
            self.isArchived = isArchived
        }
    }

    public struct Ride: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var name: String
        public var startDate: Date
        /// Time zone of the start, e.g. “Europe/Berlin”, for showing the local start time.
        public var timeZone: String?
        public var bikeID: UUID?
        /// `RideSource` raw value: “fit” or “gpx”.
        public var source: String
        /// Figures estimated from GPS (GPX without a bike computer).
        public var estimated: Bool
        /// Seconds.
        public var timerTime: Double
        public var elapsedTime: Double
        /// Metres.
        public var distance: Double
        /// Metres per second.
        public var averageSpeed: Double?
        public var maxSpeed: Double?
        /// Watts.
        public var averagePower: Int?
        public var maxPower: Int?
        /// Revolutions per minute.
        public var averageCadence: Int?
        /// Metres.
        public var totalAscent: Int?
        public var totalDescent: Int?
        public var minAltitude: Double?
        public var maxAltitude: Double?
        /// Kilojoules.
        public var work: Double?
        /// Name of the route file in the folder `Routen`, `nil` for a ride without GPS. The name
        /// changes when the route changes, so a reader may keep a route it has already loaded.
        public var routeFile: String?

        public init(id: UUID, name: String, startDate: Date, timeZone: String? = nil, bikeID: UUID? = nil,
                    source: String, estimated: Bool = false,
                    timerTime: Double, elapsedTime: Double, distance: Double,
                    averageSpeed: Double? = nil, maxSpeed: Double? = nil,
                    averagePower: Int? = nil, maxPower: Int? = nil, averageCadence: Int? = nil,
                    totalAscent: Int? = nil, totalDescent: Int? = nil,
                    minAltitude: Double? = nil, maxAltitude: Double? = nil,
                    work: Double? = nil, routeFile: String? = nil) {
            self.id = id
            self.name = name
            self.startDate = startDate
            self.timeZone = timeZone
            self.bikeID = bikeID
            self.source = source
            self.estimated = estimated
            self.timerTime = timerTime
            self.elapsedTime = elapsedTime
            self.distance = distance
            self.averageSpeed = averageSpeed
            self.maxSpeed = maxSpeed
            self.averagePower = averagePower
            self.maxPower = maxPower
            self.averageCadence = averageCadence
            self.totalAscent = totalAscent
            self.totalDescent = totalDescent
            self.minAltitude = minAltitude
            self.maxAltitude = maxAltitude
            self.work = work
            self.routeFile = routeFile
        }
    }

    /// A simplified route for the map and the elevation profile: one point about every 20 m.
    /// One segment per recording, so a merged ride keeps the gap between its parts.
    public struct Route: Codable, Sendable, Equatable {
        public var rideID: UUID
        public var segments: [Segment]

        /// Parallel arrays instead of one object per point: a third of the size in JSON.
        public struct Segment: Codable, Sendable, Equatable {
            /// Degrees, 6 decimals (about 0.1 m).
            public var latitude: [Double]
            public var longitude: [Double]
            /// Metres above sea level, 1 decimal; `nil` where the recording has no altitude.
            public var altitude: [Double?]
            /// Metres from the start of the ride (not of the segment), 1 decimal.
            public var distance: [Double]

            public init(latitude: [Double], longitude: [Double], altitude: [Double?], distance: [Double]) {
                self.latitude = latitude
                self.longitude = longitude
                self.altitude = altitude
                self.distance = distance
            }

            public var count: Int { latitude.count }
        }

        public init(rideID: UUID, segments: [Segment]) {
            self.rideID = rideID
            self.segments = segments.filter { $0.count > 0 }
        }

        /// Thins the recordings of a ride to one point every `spacing` metres along the track.
        /// The distance is the file's own (the wheel sensor of a Bosch ride), so the profile ends
        /// at the ride's distance; where a point has none, the distance between the positions is
        /// added. The recordings of a merged ride count on from where the one before ended. The
        /// first and last point of every recording stay.
        public init(rideID: UUID, recordings: [[RideSample]], spacing: Double = RideExchange.routeSpacing) {
            var segments: [Segment] = []
            var offset = 0.0
            for samples in recordings {
                var segment = Segment(latitude: [], longitude: [], altitude: [], distance: [])
                var previous: (lat: Double, lon: Double, distance: Double)?
                var lastKept = -Double.infinity
                var pending: (lat: Double, lon: Double, alt: Double?, distance: Double)?
                for sample in samples {
                    guard let lat = sample.latitude, let lon = sample.longitude else { continue }
                    let distance = sample.distance.map { offset + $0 }
                        ?? previous.map { $0.distance + GPXGeo.distance($0.lat, $0.lon, lat, lon) }
                        ?? offset
                    previous = (lat, lon, distance)
                    // A little slack, so points exactly 20 m apart are not missed by rounding.
                    if distance - lastKept >= spacing * 0.999 {
                        segment.append(lat, lon, sample.altitude, distance)
                        lastKept = distance
                        pending = nil
                    } else {
                        pending = (lat, lon, sample.altitude, distance)
                    }
                }
                if let pending { segment.append(pending.lat, pending.lon, pending.alt, pending.distance) }
                if let previous { offset = previous.distance }
                segments.append(segment)
            }
            self.init(rideID: rideID, segments: segments)
        }

        public var pointCount: Int { segments.reduce(0) { $0 + $1.count } }
    }

    // MARK: - Files

    /// The subfolder of the import folder that the Mac writes for the iPhone. The folder import
    /// looks only at files directly in the import folder, so it never touches this one.
    public static let folderName = "iPhone"
    public static let libraryFileName = "Stand.json"
    public static let routesFolderName = "Routen"

    /// The route file of a ride: its ID and a fingerprint of what the route is made from.
    public static func routeFileName(rideID: UUID, fingerprint: UInt64) -> String {
        "\(rideID.uuidString)-\(String(fingerprint, radix: 16)).json"
    }

    /// FNV-1a over the given text: stable across launches, unlike `Hasher`.
    public static func fingerprint(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public enum ReadError: Error, Equatable {
        /// Written by a newer app; the reader should ask for an update.
        case newerSchema(Int)
    }

    /// Reads a library file; refuses a newer schema instead of showing wrong values.
    public static func library(from data: Data) throws -> Library {
        struct Header: Decodable { var schemaVersion: Int }
        let header = try decoder().decode(Header.self, from: data)
        guard header.schemaVersion <= schemaVersion else { throw ReadError.newerSchema(header.schemaVersion) }
        return try decoder().decode(Library.self, from: data)
    }

    public static func route(from data: Data) throws -> Route {
        try decoder().decode(Route.self, from: data)
    }
}

extension RideExchange.Route.Segment {
    mutating func append(_ lat: Double, _ lon: Double, _ alt: Double?, _ distance: Double) {
        latitude.append(Self.round(lat, 6))
        longitude.append(Self.round(lon, 6))
        altitude.append(alt.map { Self.round($0, 1) })
        self.distance.append(Self.round(distance, 1))
    }

    static func round(_ value: Double, _ decimals: Int) -> Double {
        let factor = pow(10, Double(decimals))
        return (value * factor).rounded() / factor
    }
}
