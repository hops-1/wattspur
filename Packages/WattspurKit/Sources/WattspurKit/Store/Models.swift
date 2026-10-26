import Foundation
import SwiftData

// Persistent model (B-003). Kept CloudKit-compatible from the start
// (Requirements chapter 7): no unique constraints, every attribute optional or
// with a default, all relationships optional, large blobs as external storage.

/// The local user profile (ACC-01, PROF-01). There is exactly one; several riders
/// and switching between them come later (PROF-02).
@Model
public final class Rider {
    public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \Ride.rider)
    public var rides: [Ride]? = []
    /// The rider's bikes, including archived ones (PROF-03).
    @Relationship(deleteRule: .nullify, inverse: \Bike.rider)
    public var bikes: [Bike]? = []

    // Body data for the calorie estimate "with profile" (PROF-01, B-067). All optional.
    public var weightKg: Double?
    public var heightCm: Double?
    /// Only the year: the age of a ride follows from it and the ride's date.
    public var birthYear: Int?
    /// `RiderSex` raw value.
    public var sexRawValue: String = RiderSex.unspecified.rawValue
    /// The avatar photo; without one the app shows the initial.
    @Attribute(.externalStorage) public var photoData: Data?

    /// The bike new rides are assigned to (B-134). A plain id, not a second
    /// relationship to `Bike`, to keep the inverses unambiguous for CloudKit.
    /// Use `RideLibrary.activeBike()`, which falls back if the bike is gone.
    public var activeBikeID: UUID?

    public init(name: String = "") {
        self.name = name
    }

    public var sex: RiderSex {
        get { RiderSex(rawValue: sexRawValue) ?? .unspecified }
        set { sexRawValue = newValue.rawValue }
    }
}

/// An eBike (PROF-03). A rider can have several; a ride belongs to one. Bosch
/// exports carry no stable bike identifier, so rides are assigned by hand: new
/// rides go to the rider's active bike, later each ride can be moved (B-135).
@Model
public final class Bike {
    public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date.now
    /// Not read from FIT files: `file_id.serial_number` in Bosch exports changes
    /// with every export. Only earlier versions stored one per bike; such a bike
    /// is merged by `RideLibrary.mergeBikes()`.
    public var serialNumber: Int64?
    @Relationship(deleteRule: .nullify, inverse: \Ride.bike)
    public var rides: [Ride]? = []
    public var rider: Rider?

    /// `BikeKind` raw value.
    public var kindRawValue: String = BikeKind.bike.rawValue
    /// Whether the bike has a motor; the switch "E-Bike" in the editor.
    public var isEbike: Bool = true
    /// `BikeColor` raw value; the colour of the bike's symbol.
    public var colorRawValue: String = BikeColor.blue.rawValue
    /// Shown in the editor and on the tile in the profile only; elsewhere the coloured symbol.
    @Attribute(.externalStorage) public var photoData: Data?
    public var manufacturer: String = ""
    public var model: String = ""
    /// Drive unit, e.g. "Bosch Performance Line CX".
    public var driveUnit: String = ""
    public var batteryWh: Int?
    /// For information only; not used in any calculation.
    public var weightKg: Double?
    public var purchaseDate: Date?
    /// Odometer before the first ride in Wattspur. Counts in the bike's total only.
    public var startKilometers: Double = 0
    /// Archived instead of deleted: its rides stay assigned and the bike stays in
    /// the filters, but it leaves the import menu.
    public var isArchived: Bool = false
    /// Position in the profile and in menus, ascending.
    public var sortOrder: Int = 0

    public init(name: String = "", serialNumber: Int64? = nil) {
        self.name = name
        self.serialNumber = serialNumber
    }

    public var kind: BikeKind {
        get { BikeKind(rawValue: kindRawValue) ?? .bike }
        set { kindRawValue = newValue.rawValue }
    }

    public var color: BikeColor {
        get { BikeColor(rawValue: colorRawValue) ?? .blue }
        set { colorRawValue = newValue.rawValue }
    }
}

/// The original file a ride was imported from (IMP-07). Kept unchanged so rides
/// can be re-parsed later (NFR-17).
@Model
public final class SourceFile {
    public var id: UUID = UUID()
    public var fileName: String = ""
    @Attribute(.externalStorage) public var data: Data?
    public var ride: Ride?

    public init(fileName: String, data: Data) {
        self.fileName = fileName
        self.data = data
    }
}

@Model
public final class Ride {
    public var id: UUID = UUID()
    /// Identifier from the source, e.g. the Bosch ride UUID in the file name. Used for duplicates.
    public var sourceIdentifier: String = ""
    /// Format of the source file, e.g. "fit".
    public var sourceFormat: String = ""
    /// `true` if the totals (distance, ascent, time) were estimated from GPS
    /// positions because the source has no summary of its own, as with GPX (B-141).
    public var summaryEstimatedFromGPS: Bool = false
    /// An additional source attached to the ride, e.g. a GPX file next to the
    /// FIT file (B-141): its file name and its format ("gpx"). `nil` if none.
    public var attachedSourceName: String?
    public var attachedSourceFormat: String?
    public var name: String = ""
    public var startDate: Date = Date.distantPast
    public var importedAt: Date = Date.now
    public var parserVersion: Int = 0
    /// Set when the ride is in the trash (LIST-07/08).
    public var deletedAt: Date?
    /// The anonymized sample ride from the setup assistant (ONB-02). It never
    /// counts in totals or the analysis and is deleted, not moved to the trash.
    public var isSample: Bool = false
    /// Time zone of the start location (B-006); `nil` until it has been looked up.
    public var timeZoneIdentifier: String?
    /// `file_id.serial_number` from the source file. Metadata only: Bosch writes
    /// a different value into every export, so it does not identify the bike.
    public var deviceSerialNumber: Int64?

    // Summary from the source file (source of truth, Requirements 3.3)
    public var timerTime: TimeInterval = 0
    public var elapsedTime: TimeInterval = 0
    public var distance: Double = 0
    public var averageSpeed: Double?
    public var maxSpeed: Double?
    public var averagePower: Int?
    public var maxPower: Int?
    public var averageCadence: Int?
    public var maxCadence: Int?
    public var totalAscent: Int?
    public var totalDescent: Int?

    // Derived values (Requirements 3.4)
    public var workKilojoules: Double = 0
    public var minAltitude: Double?
    public var maxAltitude: Double?
    /// The best average power over one minute (B-122); `nil` without power values.
    public var bestPower1Min: Int?
    /// `PeakPower.version` the value was calculated with; 0 = not yet calculated.
    public var peakPowerVersion: Int = 0

    /// Encoded `[RideSample]` (binary property list).
    @Attribute(.externalStorage) public var samplesData: Data?
    /// Simplified route for the map of all rides (B-104), `OverviewRoute.encoded()`;
    /// `nil` for a ride without GPS. Small enough (a few kB) to stay inline.
    public var overviewRouteData: Data?
    /// `OverviewRoute.version` the route was computed with; 0 = not yet computed.
    public var overviewRouteVersion: Int = 0

    public var rider: Rider?
    public var bike: Bike?
    @Relationship(deleteRule: .cascade, inverse: \SourceFile.ride)
    public var sourceFile: SourceFile?

    /// The merged ride this ride became part of (B-095, LIST-09). Parts keep their
    /// original file for re-parsing, but are hidden from lists and totals.
    public var mergedInto: Ride?
    /// The original rides a merged ride was made from, in any order.
    @Relationship(deleteRule: .cascade, inverse: \Ride.mergedInto)
    public var parts: [Ride]? = []

    public init(name: String, startDate: Date) {
        self.name = name
        self.startDate = startDate
    }
}

extension Ride {
    public var summary: RideSummary {
        RideSummary(
            timerTime: timerTime, elapsedTime: elapsedTime, distance: distance,
            averageSpeed: averageSpeed, maxSpeed: maxSpeed,
            averagePower: averagePower, maxPower: maxPower,
            averageCadence: averageCadence, maxCadence: maxCadence,
            totalAscent: totalAscent, totalDescent: totalDescent
        )
    }

    public var pausedTime: TimeInterval { max(0, elapsedTime - timerTime) }

    /// Time zone for displaying the start time: the start location's, else the Mac's.
    public var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    /// First recorded position, used to look up the time zone.
    public var startCoordinate: (latitude: Double, longitude: Double)? {
        samples.lazy.compactMap { s in s.latitude.flatMap { lat in s.longitude.map { (lat, $0) } } }.first
    }

    public var isInTrash: Bool { deletedAt != nil }

    /// Rides outside the trash and not merged into another ride, for `@Query`.
    /// One shared predicate: each `#Predicate` written in a view was costly to type-check.
    public static var listedPredicate: Predicate<Ride> {
        #Predicate<Ride> { $0.deletedAt == nil && $0.mergedInto == nil }
    }

    /// The kind of file the ride was imported from; `nil` for an empty or unknown `sourceFormat`.
    public var source: RideSource? { RideSource(rawValue: sourceFormat) }

    /// `true` for a ride merged from several rides (B-095, LIST-09).
    public var isMerged: Bool { !(parts ?? []).isEmpty }

    /// The parts of a merged ride, oldest first.
    public var sortedParts: [Ride] { (parts ?? []).sorted { $0.startDate < $1.startDate } }

    /// Decoded time series; empty if none is stored.
    public var samples: [RideSample] {
        guard let samplesData else { return [] }
        return (try? PropertyListDecoder().decode([RideSample].self, from: samplesData)) ?? []
    }

    /// Copies all values from a parsed ride (used on import and on "update").
    /// Local edits such as the name are not touched.
    func apply(_ parsed: ParsedRide) {
        startDate = parsed.startDate
        parserVersion = parsed.parserVersion
        summaryEstimatedFromGPS = parsed.summaryEstimated
        deviceSerialNumber = parsed.deviceSerialNumber.map { Int64(truncatingIfNeeded: $0) }
        let s = parsed.summary
        timerTime = s.timerTime
        elapsedTime = s.elapsedTime
        distance = s.distance
        averageSpeed = s.averageSpeed
        maxSpeed = s.maxSpeed
        averagePower = s.averagePower
        maxPower = s.maxPower
        averageCadence = s.averageCadence
        maxCadence = s.maxCadence
        totalAscent = s.totalAscent
        totalDescent = s.totalDescent

        let metrics = RideMetrics(ride: parsed)
        workKilojoules = metrics.workKilojoules
        minAltitude = metrics.minAltitude
        maxAltitude = metrics.maxAltitude

        setSamples(parsed.samples)
        setOverviewRoute(OverviewRoute(samples: parsed.samples))
        setPeakPower(PeakPower.bestAverage(of: parsed.samples))
    }

    /// Stores the time series.
    func setSamples(_ samples: [RideSample]) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        samplesData = try? encoder.encode(samples)
    }

    /// The stored overview route; `nil` if none is stored or it is outdated.
    public var overviewRoute: OverviewRoute? {
        guard overviewRouteVersion == OverviewRoute.version else { return nil }
        guard let overviewRouteData else { return OverviewRoute(segments: []) }
        return OverviewRoute(data: overviewRouteData)
    }

    /// `true` while the overview route is missing or from an older version.
    public var needsOverviewRoute: Bool { overviewRouteVersion != OverviewRoute.version }

    func setOverviewRoute(_ route: OverviewRoute) {
        overviewRouteData = route.isEmpty ? nil : route.encoded()
        overviewRouteVersion = OverviewRoute.version
    }

    /// `true` while the best minute is not calculated or from an older version.
    public var needsPeakPower: Bool { peakPowerVersion != PeakPower.version }

    func setPeakPower(_ value: Int?) {
        bestPower1Min = value
        peakPowerVersion = PeakPower.version
    }

    /// A merged ride's best minute: the best of its parts, none across the seam. Parts without a
    /// current value get one first.
    func updatePeakPowerFromParts() {
        let values = sortedParts.map { part -> Int? in
            if part.needsPeakPower { part.setPeakPower(PeakPower.bestAverage(of: part.samples)) }
            return part.bestPower1Min
        }
        setPeakPower(values.compactMap { $0 }.max())
    }

    /// A merged ride's route: its parts' routes one after another (B-095), so the
    /// map draws no line across the gap. Parts without a current route get one first.
    func updateOverviewRouteFromParts() {
        let routes = sortedParts.map { part in
            if let route = part.overviewRoute { return route }
            let route = OverviewRoute(samplesData: part.samplesData)
            part.setOverviewRoute(route)
            return route
        }
        setOverviewRoute(OverviewRoute(joining: routes))
    }
}

/// A goal for a week, month or year (ADV-Z1, B-053). Each combination of metric and
/// period exists at most once; the app keeps that, not the store, because CloudKit
/// allows no unique constraints.
@Model
public final class Goal {
    public var id: UUID = UUID()
    /// `GoalMetric` raw value.
    public var metricRawValue: String = GoalMetric.distance.rawValue
    /// `GoalPeriod` raw value.
    public var periodRawValue: String = GoalPeriod.week.rawValue
    /// Metres, a number of rides, or metres of ascent.
    public var target: Double = 0
    public var createdAt: Date = Date.now

    public init(metric: GoalMetric, period: GoalPeriod, target: Double) {
        metricRawValue = metric.rawValue
        periodRawValue = period.rawValue
        self.target = target
    }

    public var metric: GoalMetric {
        get { GoalMetric(rawValue: metricRawValue) ?? .distance }
        set { metricRawValue = newValue.rawValue }
    }

    public var period: GoalPeriod {
        get { GoalPeriod(rawValue: periodRawValue) ?? .week }
        set { periodRawValue = newValue.rawValue }
    }

    /// Display order: week, month, year, then km, rides, ascent.
    public static func sorted(_ goals: [Goal]) -> [Goal] {
        func rank(_ goal: Goal) -> (Int, Int) {
            (GoalPeriod.allCases.firstIndex(of: goal.period) ?? 0, GoalMetric.allCases.firstIndex(of: goal.metric) ?? 0)
        }
        return goals.sorted { rank($0) < rank($1) }
    }

    /// Combinations of period and metric that have no goal yet.
    public static func freeCombinations(besides goals: [Goal]) -> [(period: GoalPeriod, metric: GoalMetric)] {
        let taken = Set(goals.map { "\($0.periodRawValue)/\($0.metricRawValue)" })
        return GoalPeriod.allCases.flatMap { period in
            GoalMetric.allCases.compactMap { metric in
                taken.contains("\(period.rawValue)/\(metric.rawValue)") ? nil : (period, metric)
            }
        }
    }
}

/// All model types, for creating a `ModelContainer`.
public enum WattspurSchema {
    public static let models: [any PersistentModel.Type] = [Ride.self, Rider.self, Bike.self, SourceFile.self, ImportRecord.self, Goal.self]
}
