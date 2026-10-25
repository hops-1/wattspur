import Foundation
import SwiftData

/// Importing files, finding the same ride in another file, and keeping rides up to date
/// (B-010, B-104, B-143, IMP-02, IMP-04, NFR-17, ONB-02). Start within ±60 s, GPS path within ±10 %,
/// and the same simplified route (B-104): the Bosch distance comes from the wheel sensor and lies
/// about 5 % above the GPS path.
struct ImportService: LibraryService {
    let env: LibraryEnvironment
    var importers: [any RideImporter] { env.importers }
    init(_ env: LibraryEnvironment) { self.env = env }

    private var bikes: BikeService { BikeService(env) }
    private var merges: MergeService { MergeService(env) }

    /// Imports a file from disk. Handles security-scoped URLs from the open panel.
    @discardableResult
    func importFile(at url: URL, bike: Bike? = nil, detectDuplicates: Bool = true) -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            return importFile(data: data, fileName: url.lastPathComponent, bike: bike, detectDuplicates: detectDuplicates)
        } catch {
            return ImportResult(fileName: url.lastPathComponent, outcome: .failed(.decoding(.fileTooShort)))
        }
    }

    /// Imports file contents for `bike` (default: the active bike). Duplicates are skipped (IMP-02);
    /// use `update(_:with:fileName:)` to refresh one. A GPX file for a Bosch ride of the same bike is
    /// attached to it, a FIT for a GPX ride is reported as `fitForGPX` (B-143). With `detectDuplicates`
    /// off the file becomes a ride of its own ("As new ride" in the duplicate dialog); it then gets
    /// no Bosch ID, so the ID keeps belonging to the first ride.
    @discardableResult
    func importFile(data: Data, fileName: String, bike: Bike? = nil, detectDuplicates: Bool = true) -> ImportResult {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard let importer = importers.first(where: { $0.fileExtensions.contains(ext) }) else {
            return ImportResult(fileName: fileName, outcome: .unsupported)
        }

        let parsed: ParsedRide
        do {
            parsed = try importer.parse(data)
        } catch {
            return ImportResult(fileName: fileName, outcome: .failed(error))
        }

        let names = Self.parseFileName(fileName)
        if detectDuplicates, let existing = findDuplicate(sourceIdentifier: names.sourceIdentifier, parsed: parsed) {
            return ImportResult(fileName: fileName, outcome: .duplicate(existingRideID: existing.id))
        }
        let target = bike ?? bikes.activeBike()
        if detectDuplicates, let similar = findSimilarRide(to: parsed, bike: target) {
            switch (RideSource(fileExtension: ext), similar.source) {
            case (.gpx?, .fit?):
                guard similar.attachedSourceFormat == nil else {
                    return ImportResult(fileName: fileName, outcome: .duplicate(existingRideID: similar.id))
                }
                attach(parsed, fileName: fileName, to: similar)
                try? context.save()
                return ImportResult(fileName: fileName, outcome: .attached(rideID: similar.id))
            case (.gpx?, .gpx?):
                return ImportResult(fileName: fileName, outcome: .duplicate(existingRideID: similar.id))
            case (.fit?, .gpx?):
                return ImportResult(fileName: fileName, outcome: .fitForGPX(existingRideID: similar.id))
            default:
                break
            }
        }

        let suggested = parsed.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ride = Ride(name: suggested.isEmpty ? names.title : suggested, startDate: parsed.startDate)
        ride.sourceIdentifier = detectDuplicates ? (names.sourceIdentifier ?? "") : ""
        ride.sourceFormat = ext
        ride.apply(parsed)
        ride.rider = bikes.defaultRider()
        ride.bike = target
        ride.sourceFile = SourceFile(fileName: fileName, data: data)
        context.insert(ride)
        try? context.save()
        return ImportResult(fileName: fileName, outcome: .imported(rideID: ride.id))
    }

    /// Refreshes an existing ride from a file on disk (security-scoped URLs allowed).
    func update(_ ride: Ride, withFileAt url: URL) throws(RideImportError) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw .noRideData }
        try update(ride, with: data, fileName: url.lastPathComponent)
    }

    /// Refreshes an existing ride from a newer export. Keeps the local name (IMP-02).
    func update(_ ride: Ride, with data: Data, fileName: String) throws(RideImportError) {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard let importer = importers.first(where: { $0.fileExtensions.contains(ext) }) else {
            throw .noRideData
        }
        let parsed = try importer.parse(data)
        let incoming = RideSource(fileExtension: ext)

        // A GPX never replaces the Bosch values of a FIT ride (Requirements 3.3): it refreshes the
        // additional source.
        if incoming == .gpx, ride.source == .fit {
            attach(parsed, fileName: fileName, to: ride)
            if let merged = ride.mergedInto { merges.refresh(merged) }
            try? context.save()
            return
        }

        let before = (samples: ride.samples, start: ride.startDate, fileName: ride.sourceFile?.fileName, source: ride.source)
        ride.apply(parsed)
        ride.sourceFormat = ext
        if let identifier = Self.parseFileName(fileName).sourceIdentifier { ride.sourceIdentifier = identifier }
        if incoming == .fit, before.source == .gpx {
            // The Bosch values replace the estimate; the GPX stays noted as an additional source and
            // its heart rate and temperature are kept.
            ride.attachedSourceName = before.fileName
            ride.attachedSourceFormat = RideSource.gpx.rawValue
            carrySensorValues(from: before.samples, startDate: before.start, to: ride)
        } else if incoming == .fit, ride.attachedSourceFormat != nil {
            carrySensorValues(from: before.samples, startDate: before.start, to: ride)
        } else if incoming == .gpx {
            ride.attachedSourceName = nil
            ride.attachedSourceFormat = nil
        }
        if ride.bike == nil { ride.bike = bikes.defaultBike() }
        if let file = ride.sourceFile {
            file.fileName = fileName
            file.data = data
        } else {
            ride.sourceFile = SourceFile(fileName: fileName, data: data)
        }
        if let merged = ride.mergedInto { merges.refresh(merged) }
        try? context.save()
    }

    /// Re-parses rides whose stored parser version is older than the current one,
    /// from their archived original file. Local edits (name, trash) stay (NFR-17).
    /// Returns the number of updated rides.
    @discardableResult
    func reparseOutdatedRides() -> Int {
        var updated = 0
        var mergedToRefresh: Set<UUID> = []
        let rides = (try? context.fetch(FetchDescriptor<Ride>())) ?? []
        for ride in rides {
            guard let file = ride.sourceFile, let data = file.data,
                  let importer = importers.first(where: { $0.fileExtensions.contains(ride.sourceFormat) }),
                  ride.parserVersion < importer.parserVersion,
                  let parsed = try? importer.parse(data) else { continue }
            let before = ride.attachedSourceFormat == nil ? nil : (samples: ride.samples, start: ride.startDate)
            ride.apply(parsed)
            if let before { carrySensorValues(from: before.samples, startDate: before.start, to: ride) }
            if ride.bike == nil { ride.bike = bikes.defaultBike() }
            if let merged = ride.mergedInto { mergedToRefresh.insert(merged.id) }
            updated += 1
        }
        // A merged ride has no file of its own; it is rebuilt from its updated parts.
        for ride in rides where mergedToRefresh.contains(ride.id) { merges.refresh(ride) }
        if updated > 0 { try? context.save() }
        return updated
    }

    /// Computes the overview route (B-104) of every ride that has none or one from
    /// an older `OverviewRoute.version`, e.g. rides imported before v1.4. Decoding
    /// and simplifying run off the main actor in batches; each batch is saved, so
    /// an interrupted run goes on where it stopped. Returns the number of rides.
    @discardableResult
    func prepareOverviewRoutes(batchSize: Int = 20,
                                      progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async -> Int {
        let version = OverviewRoute.version
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.overviewRouteVersion != version })
        let outdated = (try? context.fetch(descriptor)) ?? []
        guard !outdated.isEmpty else { return 0 }
        // Parts first: a merged ride is put together from its parts' routes.
        let single = outdated.filter { !$0.isMerged }
        let merged = outdated.filter(\.isMerged)
        var done = 0
        progress(0, outdated.count)
        for start in stride(from: 0, to: single.count, by: max(1, batchSize)) {
            let batch = Array(single[start..<min(start + max(1, batchSize), single.count)])
            let inputs = batch.map(\.samplesData)
            let routes = await Task.detached(priority: .utility) { inputs.map(OverviewRoute.init(samplesData:)) }.value
            // The ride may have been deleted or updated meanwhile.
            for (ride, route) in zip(batch, routes) where !ride.isDeleted && ride.needsOverviewRoute {
                ride.setOverviewRoute(route)
            }
            try? context.save()
            done += batch.count
            progress(done, outdated.count)
        }
        for ride in merged where !ride.isDeleted && ride.needsOverviewRoute { ride.updateOverviewRouteFromParts() }
        try? context.save()
        progress(outdated.count, outdated.count)
        return outdated.count
    }

    /// Imports the anonymized sample ride (V-05) under the given name and marks it
    /// as a sample. If one is already there, it is returned (and restored from the trash).
    @discardableResult
    func importSample(data: Data, name: String) -> Ride? {
        if let existing = RideService(env).sampleRides().first {
            existing.deletedAt = nil
            try? context.save()
            return existing
        }
        let result = importFile(data: data, fileName: "SampleRide.fit")
        guard case .imported(let id) = result.outcome, let ride = ride(withID: id) else { return nil }
        ride.isSample = true
        ride.name = name
        try? context.save()
        return ride
    }

    private func findDuplicate(sourceIdentifier: String?, parsed: ParsedRide) -> Ride? {
        if let sourceIdentifier {
            var descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.sourceIdentifier == sourceIdentifier })
            descriptor.fetchLimit = 1
            if let match = try? context.fetch(descriptor).first { return match }
        }
        let from = parsed.startDate.addingTimeInterval(-1)
        let to = parsed.startDate.addingTimeInterval(1)
        let distance = parsed.summary.distance
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate { $0.startDate >= from && $0.startDate <= to })
        return (try? context.fetch(descriptor))?.first { abs($0.distance - distance) < 1 }
    }

    /// Splits a Bosch export name like "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit"
    /// into the ride title and the Bosch ride UUID (IMP-03).
    nonisolated static func parseFileName(_ fileName: String) -> (title: String, sourceIdentifier: String?) {
        let base = (fileName as NSString).deletingPathExtension
        let pattern = /^(.*?)-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$/
        if let match = base.wholeMatch(of: pattern) {
            let title = String(match.1).trimmingCharacters(in: .whitespaces)
            return (title.isEmpty ? base : title, String(match.2).lowercased())
        }
        return (base, nil)
    }
    /// How far the start times of two files of one ride may be apart, in seconds.
    static let similarStartTolerance: TimeInterval = 60
    /// How far the GPS paths may be apart, as a share of the longer one.
    static let similarDistanceTolerance = 0.10

    /// The ride of `bike` that `parsed` records again, if there is one. Rides of other bikes never
    /// match: two people on one tour start together and ride the same route (group ride), and
    /// their files are different rides. Rides in the trash, the sample ride and rides that are
    /// part of a merged ride do not match. The closest start wins.
    func findSimilarRide(to parsed: ParsedRide, bike: Bike?) -> Ride? {
        let from = parsed.startDate.addingTimeInterval(-Self.similarStartTolerance)
        let to = parsed.startDate.addingTimeInterval(Self.similarStartTolerance)
        let descriptor = FetchDescriptor<Ride>(predicate: #Predicate {
            $0.startDate >= from && $0.startDate <= to && !$0.isSample && $0.deletedAt == nil
        })
        let candidates = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.mergedInto == nil && !$0.isMerged }
            .filter { bike == nil || $0.bike == nil || $0.bike?.id == bike?.id }
            .sorted { abs($0.startDate.timeIntervalSince(parsed.startDate)) < abs($1.startDate.timeIntervalSince(parsed.startDate)) }
        guard !candidates.isEmpty else { return nil }

        let newPath = GPSPath.length(of: parsed.samples)
        guard newPath > 0 else { return nil }
        let newRoute = OverviewRoute(samples: parsed.samples)
        for ride in candidates {
            let samples = ride.samples
            let path = GPSPath.length(of: samples)
            guard path > 0, abs(path - newPath) <= Self.similarDistanceTolerance * max(path, newPath) else { continue }
            let route = ride.overviewRoute.flatMap { $0.isEmpty ? nil : $0 } ?? OverviewRoute(samples: samples)
            if RouteMatch.matches(route, newRoute) { return ride }
        }
        return nil
    }

    /// Adds the extra source of a GPX file to a Bosch ride: its heart rate and temperature go into the
    /// time series, the file is noted. The Bosch values stay (Requirements 3.3).
    func attach(_ parsed: ParsedRide, fileName: String, to ride: Ride) {
        carrySensorValues(from: parsed.samples, startDate: parsed.startDate, to: ride)
        ride.attachedSourceName = fileName
        ride.attachedSourceFormat = RideSource.gpx.rawValue
    }

    /// Copies heart rate and temperature from `source` (a time series starting at `startDate`) to the
    /// nearest sample of the ride, if that is within `sensorTolerance` seconds.
    func carrySensorValues(from source: [RideSample], startDate: Date, to ride: Ride) {
        var samples = ride.samples
        guard !samples.isEmpty else { return }
        // Seconds the source axis runs ahead of the ride's.
        let shift = startDate.timeIntervalSince(ride.startDate)
        let heartRates = source.compactMap { s in s.heartRate.map { (time: s.time + shift, value: Double($0)) } }
        let temperatures = source.compactMap { s in s.temperature.map { (time: s.time + shift, value: $0) } }
        guard !heartRates.isEmpty || !temperatures.isEmpty else { return }
        let order = samples.indices.sorted { samples[$0].time < samples[$1].time }
        Self.assign(heartRates, to: order, in: &samples) { $0.heartRate = Int($1.rounded()) }
        Self.assign(temperatures, to: order, in: &samples) { $0.temperature = $1 }
        ride.setSamples(samples)
    }

    /// How far apart in seconds two samples may be to count as the same moment.
    static let sensorTolerance: TimeInterval = 5

    private static func assign(_ values: [(time: TimeInterval, value: Double)], to order: [Int], in samples: inout [RideSample],
                               set: (inout RideSample, Double) -> Void) {
        guard !values.isEmpty else { return }
        let sorted = values.sorted { $0.time < $1.time }
        var j = 0
        for index in order {
            let t = samples[index].time
            while j + 1 < sorted.count, abs(sorted[j + 1].time - t) <= abs(sorted[j].time - t) { j += 1 }
            if abs(sorted[j].time - t) <= sensorTolerance { set(&samples[index], sorted[j].value) }
        }
    }
    /// The facts of a file for the duplicate dialog; `nil` if no importer reads it.
    func facts(ofFileAt url: URL) -> DuplicateFacts? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard let data = try? Data(contentsOf: url),
              let importer = importers.first(where: { $0.fileExtensions.contains(ext) }),
              let parsed = try? importer.parse(data) else { return nil }
        return DuplicateFacts(parsed: parsed, source: RideSource(fileExtension: ext))
    }
}
