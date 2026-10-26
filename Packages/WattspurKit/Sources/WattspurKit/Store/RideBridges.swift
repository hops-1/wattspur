import Foundation

/// How a stored ride becomes the plain values that the pure code in WattspurCore works on
/// (figures, sort keys, map rides, GPX segments). The pure types know nothing of SwiftData;
/// these bridges live next to the model.

// From Analysis/MapOverview.swift
extension Ride {
    public func isOnMap(_ filter: MapFilter) -> Bool {
        filter.admits(id: id, startDate: startDate, countsInStatistics: countsInStatistics,
                      isListed: deletedAt == nil && mergedInto == nil, bikeID: bike?.id, rideSource: self.source)
    }

    /// The ride for the map; `nil` without GPS or while its route is still being prepared.
    public var mapRide: MapRide? {
        overviewRoute.flatMap { MapRide(id: id, name: name, figures: figures, route: $0) }
    }
}

// From Analysis/RideAnalysis.swift
extension Ride {
    public var figures: RideFigures {
        RideFigures(startDate: startDate, distance: distance, timerTime: timerTime, totalAscent: totalAscent,
                    workKilojoules: workKilojoules, averageSpeed: averageSpeed,
                    averagePower: averagePower, averageCadence: averageCadence)
    }
}

// From Analysis/RideComparison.swift
extension Ride {
    public var comparisonFigures: ComparisonFigures {
        // A merged ride's average power is weighted by moving time, so its pedalling
        // time comes from the parts, where Bosch's own averages still hold.
        // If a part has no power data, fall back to the merged values.
        let partTimes = (parts ?? []).map(\.comparisonFigures.pedallingTime)
        let pedalling: TimeInterval? = isMerged && !partTimes.contains(nil)
            ? partTimes.compactMap { $0 }.reduce(0, +)
            : nil
        return ComparisonFigures(
            timerTime: timerTime, elapsedTime: elapsedTime, distance: distance,
            averageSpeed: averageSpeed, maxSpeed: maxSpeed,
            totalAscent: totalAscent, totalDescent: totalDescent,
            minAltitude: minAltitude, maxAltitude: maxAltitude,
            averagePower: averagePower, maxPower: maxPower,
            averageCadence: averageCadence, maxCadence: maxCadence,
            workKilojoules: workKilojoules, pedallingTime: pedalling, startDate: startDate
        )
    }

    /// Counts towards totals and averages: not in the trash, not the sample ride,
    /// not a part of a merged ride (the merged ride counts instead).
    public var countsInStatistics: Bool {
        deletedAt == nil && !isSample && mergedInto == nil
    }
}

// From Analysis/Highlights.swift
extension Ride {
    public var highlightRide: HighlightRide {
        HighlightRide(id: id, figures: figures, timeZone: timeZone)
    }
}

// From Analysis/NewPaths.swift
extension Ride {
    /// The rides "new paths" are measured against: everything that counts, with a
    /// merged ride's parts in its place (each with its own start), without the
    /// sample ride and the trash.
    @MainActor
    public static func newPathInputs(_ rides: [Ride]) -> [NewPaths.Input] {
        rides.filter { $0.deletedAt == nil && !$0.isSample && !$0.isMerged && ($0.mergedInto?.deletedAt == nil) }
            .compactMap { ride in ride.overviewRoute.map { NewPaths.Input(id: ride.id, startDate: ride.startDate, route: $0) } }
    }
}

// From Ride/RouteIndex.swift
extension Ride {
    /// Does the ride take part in the search for similar routes? Not the sample ride, not the
    /// trash and not the parts of a merged ride: the merged ride stands for them, with its
    /// segments (Requirements 10.19).
    public var countsForSimilarRoutes: Bool {
        deletedAt == nil && !isSample && mergedInto == nil
    }
}

extension RouteIndex {
    /// The routes of all rides that count, without those that have no GPS or whose route is still
    /// being prepared (`Ride.needsOverviewRoute`).
    @MainActor
    public init(_ rides: [Ride]) {
        self.init()
        for ride in rides where ride.countsForSimilarRoutes {
            if let route = ride.overviewRoute { insert(ride.id, route: route) }
        }
    }
}

// From Ride/GPXWriter.swift
extension Ride {
    /// The recordings to export: each part of a merged ride with its own start, so
    /// the times stay true even across days; otherwise the ride itself.
    public var gpxSegments: [GPXWriter.Segment] {
        if isMerged {
            return sortedParts.flatMap(\.gpxSegments)
        }
        return [GPXWriter.Segment(startDate: startDate, samples: samples)]
    }
}

// From Ride/RideQuery.swift
extension Ride {
    public var sortKey: RideSortKey {
        RideSortKey(startDate: startDate, distance: distance, timerTime: timerTime,
                    totalAscent: totalAscent, averagePower: averagePower)
    }
}

// From Ride/CalorieModel.swift
extension Rider {
    public var bodyProfile: BodyProfile {
        BodyProfile(weightKg: weightKg, heightCm: heightCm, birthYear: birthYear, sex: sex)
    }
}

// From Analysis/MapOverview.swift
extension MapOverview {
    /// Collects the filtered rides of the library.
    @MainActor
    public init(_ rides: [Ride], filter: MapFilter) {
        var shown: [MapRide] = [], withoutGPS = 0, preparing = 0
        for ride in rides where ride.isOnMap(filter) {
            if ride.needsOverviewRoute {
                preparing += 1
            } else if let mapRide = ride.mapRide {
                shown.append(mapRide)
            } else {
                withoutGPS += 1
            }
        }
        self.init(rides: shown, withoutGPS: withoutGPS, preparing: preparing)
    }
}

// From BikeFilter.swift
extension Ride {
    /// Whether the ride passes a bike filter.
    public func isOnBike(_ filter: BikeFilter) -> Bool { filter.admits(bikeID: bike?.id) }
}

// From SourceFilter.swift
extension Ride {
    /// Whether the ride passes a source filter.
    public func isFromSource(_ filter: SourceFilter) -> Bool { filter.admits(source: source) }

    /// The symbol of the ride in the list; `nil` for a plain Bosch FIT.
    public var sourceBadge: RideSourceBadge? {
        if source == .gpx { return .gpx }
        return attachedSourceFormat == RideSource.gpx.rawValue ? .attachedGPX : nil
    }

    /// `true` if the file held power, so values that come from it (power, work, calories) are there.
    public var hasPowerData: Bool { averagePower != nil || maxPower != nil }
}
