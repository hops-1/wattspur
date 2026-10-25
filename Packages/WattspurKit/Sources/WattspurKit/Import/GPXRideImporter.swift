import Foundation

/// Why a GPX file could not become a ride (B-140). Each case has its own message in the app.
public enum GPXImportError: Error, Equatable, Sendable {
    /// Not XML, or XML without a `gpx` root element.
    case notGPX
    /// The XML ends in the middle of the file: copy or download was cut off.
    case truncated
    /// The XML is damaged somewhere else.
    case malformedXML
    /// Bigger than `maxFileSize` of the importer.
    case tooLarge
    /// More points than `maxPoints` of the importer.
    case tooManyPoints
    /// Only planned routes (`rte`) or waypoints (`wpt`), no recorded track.
    case onlyRoutesOrWaypoints
    /// No track point with a usable position.
    case noTrackPoints
    /// The track has no time at all, so no ride time can be computed.
    case noTimestamps
    /// More than `GPXRideImporter.maxUntimedShare` of the points have no time.
    case tooManyPointsWithoutTime
    /// Times run backwards too often to put the points in order.
    case unorderedTimes
    /// The points are there, but no stretch of at least two points is left after cleaning.
    case noUsablePoints
}

/// A recorded track read from a GPX file, before it is turned into a ride.
///
/// The file's segments and every pause (a gap of `GPXRideImporter.pauseGap` or more between two
/// points) split it into `parts`; neither time nor distance is counted across parts. The points
/// are the original ones, not resampled to 1 Hz (Requirements 10.17).
public struct GPXTrack: Sendable, Equatable {
    /// One continuous stretch.
    public struct Part: Sendable, Equatable {
        public var startDate: Date
        /// `time` counts from `startDate`, `distance` from the start of this part. Speed is derived
        /// from distance and time; power, cadence, heart rate and temperature only where the file has them.
        public var samples: [RideSample]

        public var duration: TimeInterval { samples.last?.time ?? 0 }
        public var distance: Double { samples.last?.distance ?? 0 }
        public var endDate: Date { startDate.addingTimeInterval(duration) }
    }

    /// What was left out while reading, for the import log.
    public struct Discarded: Sendable, Equatable {
        /// Points without a usable position (missing, out of range, 0/0).
        public var invalidPosition = 0
        /// Points without a time stamp.
        public var withoutTime = 0
        /// Points with a time already seen (the first one wins).
        public var duplicateTime = 0
        /// GPS jumps faster than `GPXRideImporter.maxSpeed`.
        public var jumps = 0
        /// Points inside the time span of an earlier segment.
        public var overlapping = 0
        /// Parts with a single point, which have no duration.
        public var singlePointParts = 0
        /// Points that came in the wrong order and were sorted.
        public var reordered = 0

        public var total: Int { invalidPosition + withoutTime + duplicateTime + jumps + overlapping + singlePointParts }
    }

    /// `trk/name`, else `metadata/name`; `nil` if the file has none.
    public var name: String?
    /// The `creator` of the `gpx` element, as a hint for the log (not for logic).
    public var creator: String?
    /// `trk/type`, as a hint for the log (not for logic).
    public var activityType: String?
    /// In time order.
    public var parts: [Part]
    public var discarded: Discarded

    public var startDate: Date { parts.first?.startDate ?? .distantPast }
    public var pointCount: Int { parts.reduce(0) { $0 + $1.samples.count } }

    /// The parts on one time axis, like a merged ride (`RideMerge`): a pause on the same day (in
    /// `timeZone`) keeps its length, parts on different days follow one another directly.
    /// Distance runs on through the parts without the stretches between them.
    public func samples(timeZone: TimeZone = .current) -> [RideSample] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var result: [RideSample] = []
        result.reserveCapacity(pointCount)
        var distanceOffset = 0.0
        var previous: Part?
        var previousOffset = 0.0
        for part in parts {
            var offset = 0.0
            if let previous {
                if calendar.isDate(previous.endDate, inSameDayAs: part.startDate) {
                    offset = part.startDate.timeIntervalSince(startDate)
                } else {
                    offset = previousOffset + previous.duration
                }
            }
            for sample in part.samples {
                var s = sample
                s.time += offset
                s.distance = sample.distance.map { $0 + distanceOffset }
                result.append(s)
            }
            distanceOffset += part.distance
            previous = part
            previousOffset = offset
        }
        return result
    }
}

/// Imports GPX 1.0 and 1.1 recordings (B-140, IMP-04): other bikes, bike computers, komoot, Strava.
///
/// Reads with the streaming `XMLParser`, by local element name, so prefixes and the order of
/// attributes and elements do not matter. Besides position, height and time it understands power
/// (`power`), and the Garmin TrackPointExtension values cadence, heart rate and temperature.
/// Routes and waypoints are not imported. Several tracks and segments make one ride with gaps.
/// The totals are computed from the track (`GPXTrack.totals`) and marked as estimated.
public struct GPXRideImporter: RideImporter {
    /// Bump whenever parsing changes so stored rides are re-parsed (NFR-17).
    public static let parserVersion = 1
    /// A gap this long (or a new segment) starts a new part: no ride time, no distance (confirmed 25.10.2026).
    public static let pauseGap: TimeInterval = 30
    /// A point further from the last kept one than this speed allows is a GPS jump (unless the ride was
    /// that fast already), in m/s (150 km/h).
    public static let maxSpeed = 150.0 / 3.6
    /// Larger files are refused (default of `maxFileSize`).
    public static let defaultMaxFileSize = 200 * 1024 * 1024
    /// More track points are refused (default of `maxPoints`).
    public static let defaultMaxPoints = 5_000_000
    /// Share of points without time above which the file is refused.
    public static let maxUntimedShare = 0.05
    /// Share of backward time steps above which the file is refused instead of sorted.
    public static let maxBackwardShare = 0.10

    public let fileExtensions: Set<String> = ["gpx"]
    public var parserVersion: Int { Self.parserVersion }
    /// The time zone that decides whether two parts lie on the same day.
    public let timeZone: TimeZone

    /// Files above this size in bytes are refused.
    public let maxFileSize: Int
    /// Files with more track points than this are refused.
    public let maxPoints: Int

    /// How ride time, distance, speed and ascent are computed from the track.
    public let summaryParameters: GPXSummaryParameters

    public init(timeZone: TimeZone = .current, maxFileSize: Int = defaultMaxFileSize, maxPoints: Int = defaultMaxPoints,
                summaryParameters: GPXSummaryParameters = .standard) {
        self.summaryParameters = summaryParameters
        self.timeZone = timeZone
        self.maxFileSize = maxFileSize
        self.maxPoints = maxPoints
    }

    public func parse(_ data: Data) throws(RideImportError) -> ParsedRide {
        let track: GPXTrack
        do {
            track = try parseTrack(data)
        } catch {
            throw .gpx(error)
        }
        return Self.ride(from: track, timeZone: timeZone, parameters: summaryParameters)
    }

    /// Reads the track with its parts, name and counts of what was left out.
    public func parseTrack(_ data: Data) throws(GPXImportError) -> GPXTrack {
        guard data.count <= maxFileSize else { throw .tooLarge }
        let reader = GPXReader(maxPoints: maxPoints)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        let finished = parser.parse()
        if reader.exceededPoints { throw .tooManyPoints }
        if !finished {
            if !reader.sawRoot { throw .notGPX }
            // A complete file ends with the closing `gpx` tag; anything else was cut off.
            let end = data.suffix(64).reversed().drop { $0 == 0x0A || $0 == 0x0D || $0 == 0x20 || $0 == 0x09 }
            let closing = Array(end.prefix(4).reversed())
            throw closing == Array("gpx>".utf8) ? .malformedXML : .truncated
        }
        guard reader.sawRoot else { throw .notGPX }
        return try Self.track(from: reader)
    }

    // MARK: - Cleaning

    private static func track(from reader: GPXReader) throws(GPXImportError) -> GPXTrack {
        var discarded = GPXTrack.Discarded()
        if reader.segments.allSatisfy(\.isEmpty) {
            throw reader.sawRouteOrWaypoint ? .onlyRoutesOrWaypoints : .noTrackPoints
        }

        // Position first: a point without one is no track point at all.
        var segments: [[RawPoint]] = []
        for segment in reader.segments {
            var kept: [RawPoint] = []
            for point in segment {
                guard point.hasValidPosition else { discarded.invalidPosition += 1; continue }
                kept.append(point)
            }
            if !kept.isEmpty { segments.append(kept) }
        }
        let positioned = segments.reduce(0) { $0 + $1.count }
        guard positioned > 0 else { throw .noTrackPoints }

        // Time.
        let timed = segments.reduce(0) { $0 + $1.filter { $0.time != nil }.count }
        guard timed > 0 else { throw .noTimestamps }
        discarded.withoutTime = positioned - timed
        if Double(discarded.withoutTime) / Double(positioned) > maxUntimedShare { throw .tooManyPointsWithoutTime }

        var backward = 0
        var cleaned: [[RawPoint]] = []
        for segment in segments {
            let points = segment.filter { $0.time != nil }
            for i in points.indices.dropFirst() where points[i].time! < points[i - 1].time! { backward += 1 }
            cleaned.append(points)
        }
        if Double(backward) / Double(timed) > maxBackwardShare { throw .unorderedTimes }
        discarded.reordered = backward

        // Sort, drop equal times (the first wins) and GPS jumps.
        for i in cleaned.indices {
            let sorted = cleaned[i].enumerated().sorted {
                $0.element.time! != $1.element.time! ? $0.element.time! < $1.element.time! : $0.offset < $1.offset
            }.map(\.element)
            var points: [RawPoint] = []
            points.reserveCapacity(sorted.count)
            var stepSpeed = 0.0
            for point in sorted {
                if let last = points.last {
                    let dt = point.time!.timeIntervalSince(last.time!)
                    if dt == 0 { discarded.duplicateTime += 1; continue }
                    let speed = last.distance(to: point) / dt
                    // A jump is faster than a bike can go and far faster than the ride before it,
                    // so a motorcycle at a steady 160 km/h is no row of jumps.
                    if dt < pauseGap, speed > maxSpeed, speed > 3 * stepSpeed { discarded.jumps += 1; continue }
                    stepSpeed = speed
                }
                points.append(point)
            }
            cleaned[i] = points
        }

        // Segments in time order; points inside the time span of an earlier one are dropped.
        cleaned.sort { $0[0].time! < $1[0].time! }
        var latest = Date.distantPast
        var parts: [GPXTrack.Part] = []
        for segment in cleaned {
            var run: [RawPoint] = []
            func close() {
                if run.count >= 2 {
                    parts.append(Self.part(from: run))
                } else if run.count == 1 {
                    discarded.singlePointParts += 1
                }
                run.removeAll(keepingCapacity: true)
            }
            for point in segment {
                let time = point.time!
                if time <= latest { discarded.overlapping += 1; continue }
                if let last = run.last, time.timeIntervalSince(last.time!) >= pauseGap { close() }
                run.append(point)
                latest = time
            }
            close()
        }
        guard !parts.isEmpty else { throw .noUsablePoints }

        let name = [reader.trackName, reader.metadataName].compactMap { $0 }.first { !$0.isEmpty }
        return GPXTrack(name: name, creator: reader.creator, activityType: reader.trackType,
                        parts: parts, discarded: discarded)
    }

    private static func part(from points: [RawPoint]) -> GPXTrack.Part {
        let start = points[0].time!
        var samples: [RideSample] = []
        samples.reserveCapacity(points.count)
        var distance = 0.0
        for (i, point) in points.enumerated() {
            if i > 0 { distance += points[i - 1].distance(to: point) }
            var sample = RideSample(time: point.time!.timeIntervalSince(start),
                                    latitude: point.latitude, longitude: point.longitude,
                                    altitude: point.altitude, distance: distance,
                                    power: point.power, cadence: point.cadence,
                                    cadenceMeasured: point.cadence != nil,
                                    heartRate: point.heartRate, temperature: point.temperature)
            if i > 0 {
                let dt = sample.time - samples[i - 1].time
                sample.speed = dt > 0 ? (distance - (samples[i - 1].distance ?? 0)) / dt : nil
            }
            samples.append(sample)
        }
        // The first point has no step behind it: take the speed of the first step.
        if samples.count > 1 { samples[0].speed = samples[1].speed }
        return GPXTrack.Part(startDate: start, samples: samples)
    }

    // MARK: - Ride

    /// A ride with totals computed from the track (B-142): ride time without pauses and standing
    /// still, distance along the moving steps, speeds, and ascent from smoothed heights. They are
    /// estimates; a Bosch FIT delivers its own and wins (Requirements 3.3).
    static func ride(from track: GPXTrack, timeZone: TimeZone, parameters: GPXSummaryParameters = .standard) -> ParsedRide {
        let samples = track.samples(timeZone: timeZone)
        let totals = track.totals(parameters)
        let timer = totals.movingTime
        let distance = totals.distance
        let powers = samples.compactMap(\.power).filter { $0 > 0 }
        let cadences = samples.filter(\.cadenceMeasured).compactMap(\.cadence).filter { $0 > 0 }

        var work: Double?
        if samples.contains(where: { $0.power != nil }) {
            var joules = 0.0
            for part in track.parts {
                for (a, b) in zip(part.samples, part.samples.dropFirst()) {
                    joules += Double(a.power ?? 0) * (b.time - a.time)
                }
            }
            work = joules / 1000
        }

        let summary = RideSummary(
            timerTime: timer,
            elapsedTime: samples.last?.time ?? 0,
            distance: distance,
            averageSpeed: timer > 0 ? distance / timer : nil,
            maxSpeed: totals.maxSpeed,
            averagePower: powers.isEmpty ? nil : powers.reduce(0, +) / powers.count,
            maxPower: powers.max(),
            averageCadence: cadences.isEmpty ? nil : cadences.reduce(0, +) / cadences.count,
            maxCadence: cadences.max(),
            totalAscent: totals.ascent,
            totalDescent: totals.descent
        )
        return ParsedRide(startDate: track.startDate, summary: summary, samples: samples,
                          deviceSerialNumber: nil, parserVersion: parserVersion, workKilojoules: work,
                          summaryEstimated: true, suggestedName: track.name)
    }

    // MARK: - Time stamps

    /// ISO 8601 as GPX writes it: `2026-10-18T12:12:13Z`, with 0 to 9 fraction digits, `Z` or an
    /// offset (`+02:00`, `+0200`, `+02`). Without a zone the time counts as UTC.
    static func parseTime(_ text: String) -> Date? {
        var bytes = Array(text.utf8)
        while let first = bytes.first, first == 0x20 || first == 0x0A || first == 0x0D || first == 0x09 { bytes.removeFirst() }
        while let last = bytes.last, last == 0x20 || last == 0x0A || last == 0x0D || last == 0x09 { bytes.removeLast() }
        var i = 0
        func digits(_ count: Int) -> Int? {
            guard i + count <= bytes.count else { return nil }
            var value = 0
            for k in 0..<count {
                let b = bytes[i + k]
                guard b >= 0x30, b <= 0x39 else { return nil }
                value = value * 10 + Int(b - 0x30)
            }
            i += count
            return value
        }
        func expect(_ set: [UInt8]) -> Bool {
            guard i < bytes.count, set.contains(bytes[i]) else { return false }
            i += 1
            return true
        }
        guard let year = digits(4), expect([UInt8(ascii: "-")]),
              let month = digits(2), expect([UInt8(ascii: "-")]),
              let day = digits(2), expect([UInt8(ascii: "T"), UInt8(ascii: "t"), 0x20]),
              let hour = digits(2), expect([UInt8(ascii: ":")]),
              let minute = digits(2), expect([UInt8(ascii: ":")]),
              let second = digits(2) else { return nil }
        guard (1...12).contains(month), (1...31).contains(day), hour < 24, minute < 60, second <= 60 else { return nil }

        var fraction = 0.0
        if i < bytes.count, bytes[i] == UInt8(ascii: ".") || bytes[i] == UInt8(ascii: ",") {
            i += 1
            var scale = 0.1
            var count = 0
            while i < bytes.count, bytes[i] >= 0x30, bytes[i] <= 0x39 {
                fraction += Double(bytes[i] - 0x30) * scale
                scale /= 10
                i += 1
                count += 1
            }
            guard count > 0 else { return nil }
        }

        var offset = 0
        if i < bytes.count {
            if bytes[i] == UInt8(ascii: "Z") || bytes[i] == UInt8(ascii: "z") {
                i += 1
            } else if bytes[i] == UInt8(ascii: "+") || bytes[i] == UInt8(ascii: "-") {
                let sign = bytes[i] == UInt8(ascii: "-") ? -1 : 1
                i += 1
                guard let h = digits(2), h < 24 else { return nil }
                var m = 0
                if i < bytes.count {
                    if bytes[i] == UInt8(ascii: ":") { i += 1 }
                    guard let parsed = digits(2), parsed < 60 else { return nil }
                    m = parsed
                }
                offset = sign * (h * 3600 + m * 60)
            }
        }
        guard i == bytes.count else { return nil }

        // Days since 1970-01-01 (proleptic Gregorian, after Howard Hinnant).
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146_097 + doe - 719_468
        let seconds = Double(days * 86_400 + hour * 3600 + minute * 60 + second - offset)
        return Date(timeIntervalSince1970: seconds + fraction)
    }
}

// MARK: - Reading the XML

/// A track point as read, before cleaning.
private struct RawPoint {
    var latitude = Double.nan
    var longitude = Double.nan
    var altitude: Double?
    var time: Date?
    var power: Int?
    var cadence: Int?
    var heartRate: Int?
    var temperature: Double?

    var hasValidPosition: Bool {
        latitude.isFinite && longitude.isFinite
            && abs(latitude) <= 90 && abs(longitude) <= 180
            && !(latitude == 0 && longitude == 0)
    }

    /// Great-circle distance in metres.
    func distance(to other: RawPoint) -> Double {
        GPXGeo.distance(latitude, longitude, other.latitude, other.longitude)
    }
}

/// Collects the track points while `XMLParser` streams through the file.
private final class GPXReader: NSObject, XMLParserDelegate {
    /// Element names (local, lower case) that carry a value, by the name they are known under.
    private static let valueNames: [String: Value] = [
        "ele": .elevation, "time": .time,
        "power": .power, "powerinwatts": .power, "watts": .power,
        "cad": .cadence, "cadence": .cadence,
        "hr": .heartRate, "heartrate": .heartRate,
        "atemp": .temperature, "temp": .temperature
    ]

    private enum Value { case elevation, time, power, cadence, heartRate, temperature }

    let maxPoints: Int
    var segments: [[RawPoint]] = []
    var sawRoot = false
    var sawRouteOrWaypoint = false
    var exceededPoints = false
    var creator: String?
    var trackName: String?
    var trackType: String?
    var metadataName: String?

    private var stack: [String] = []
    private var pointCount = 0
    private var point: RawPoint?
    private var text = ""
    private var collecting: Value?
    private var collectingTrackText: ReferenceWritableKeyPath<GPXReader, String?>?

    init(maxPoints: Int) {
        self.maxPoints = maxPoints
    }

    private static func local(_ name: String) -> String {
        let local = name.split(separator: ":").last.map(String.init) ?? name
        return local.lowercased()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = Self.local(elementName)
        let parent = stack.last
        stack.append(name)
        text = ""
        collecting = nil
        collectingTrackText = nil

        switch name {
        case "gpx":
            if stack.count == 1 {
                sawRoot = true
                creator = attributeDict["creator"]
            }
        case "trkseg":
            segments.append([])
        case "trkpt":
            // A `trkpt` outside a `trkseg` (broken files) still opens a segment.
            if segments.isEmpty || parent != "trkseg" { segments.append([]) }
            var p = RawPoint()
            for (key, value) in attributeDict {
                switch Self.local(key) {
                case "lat": p.latitude = Double(value.trimmingCharacters(in: .whitespaces)) ?? .nan
                case "lon", "lng": p.longitude = Double(value.trimmingCharacters(in: .whitespaces)) ?? .nan
                default: break
                }
            }
            point = p
            pointCount += 1
            if pointCount > maxPoints {
                exceededPoints = true
                parser.abortParsing()
            }
        case "rte", "rtept", "wpt":
            sawRouteOrWaypoint = true
        default:
            if point != nil {
                collecting = Self.valueNames[name]
            } else if name == "name" {
                if parent == "trk" { collectingTrackText = \.trackName }
                else if parent == "metadata" { collectingTrackText = \.metadataName }
            } else if name == "type", parent == "trk" {
                collectingTrackText = \.trackType
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting != nil || collectingTrackText != nil { text += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if collecting != nil || collectingTrackText != nil, let string = String(data: CDATABlock, encoding: .utf8) {
            text += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = Self.local(elementName)
        defer {
            if !stack.isEmpty { stack.removeLast() }
            collecting = nil
            collectingTrackText = nil
            text = ""
        }

        if name == "trkpt" {
            if let finished = point, !segments.isEmpty {
                segments[segments.count - 1].append(finished)
            }
            point = nil
            return
        }

        if let key = collectingTrackText {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if self[keyPath: key] == nil, !trimmed.isEmpty { self[keyPath: key] = trimmed }
            return
        }

        guard let value = collecting, point != nil else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch value {
        case .time:
            if point?.time == nil { point?.time = GPXRideImporter.parseTime(trimmed) }
        case .elevation:
            // Height 0 is how devices write "no height".
            if point?.altitude == nil, let v = Double(trimmed), v.isFinite, v != 0 { point?.altitude = v }
        case .temperature:
            if point?.temperature == nil, let v = Double(trimmed), v.isFinite { point?.temperature = v }
        case .power:
            if point?.power == nil, let v = Self.whole(trimmed), v >= 0 { point?.power = v }
        case .cadence:
            if point?.cadence == nil, let v = Self.whole(trimmed), v >= 0 { point?.cadence = v }
        case .heartRate:
            if point?.heartRate == nil, let v = Self.whole(trimmed), v > 0 { point?.heartRate = v }
        }
    }

    private static func whole(_ text: String) -> Int? {
        guard let v = Double(text), v.isFinite, abs(v) < 100_000 else { return nil }
        return Int(v.rounded())
    }
}
