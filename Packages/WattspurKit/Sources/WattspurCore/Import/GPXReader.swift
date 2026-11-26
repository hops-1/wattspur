import Foundation

// The XML reader of GPXRideImporter (S-24): streams through the file and collects the raw track points.

/// A track point as read, before cleaning.
struct RawPoint {
    var latitude = Double.nan
    var longitude = Double.nan
    var altitude: Double?
    var time: Date?
    var power: Int?
    var cadence: Int?
    var heartRate: Int?
    var temperature: Double?
    /// `wattspur:accuracy`, metres (recordings of the iPhone app).
    var accuracy: Double?
    /// `wattspur:lean` (degrees), `wattspur:accel` and `wattspur:rough` (g), B-245.
    var lean: Double?
    var acceleration: Double?
    var roughness: Double?

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
final class GPXReader: NSObject, XMLParserDelegate {
    /// Element names (local, lower case) that carry a value, by the name they are known under.
    private static let valueNames: [String: Value] = [
        "ele": .elevation, "time": .time,
        "power": .power, "powerinwatts": .power, "watts": .power,
        "cad": .cadence, "cadence": .cadence,
        "hr": .heartRate, "heartrate": .heartRate,
        "atemp": .temperature, "temp": .temperature,
        "accuracy": .accuracy,
        "lean": .lean, "accel": .acceleration, "rough": .roughness
    ]

    private enum Value {
        case elevation, time, power, cadence, heartRate, temperature, accuracy, lean, acceleration, roughness
    }

    let maxPoints: Int
    /// Stops quietly after this many points (`stoppedEarly`), for a quick look at a file (B-372).
    let stopAfter: Int?
    var segments: [[RawPoint]] = []
    /// The points of each `rte`, for planned tours (B-372); the ride importer ignores them.
    var routes: [[RawPoint]] = []
    var stoppedEarly = false
    /// `metadata/time` is there: a recording names when it was made, komoot does not (V-22).
    var hasMetadataTime = false
    var routeName: String?
    var sawRoot = false
    var sawRouteOrWaypoint = false
    var exceededPoints = false
    var creator: String?
    var trackName: String?
    var trackType: String?
    var metadataName: String?
    var bikeText: String?
    var kindText: String?

    private var stack: [String] = []
    private var pointCount = 0
    private var point: RawPoint?
    private var text = ""
    private var collecting: Value?
    private var collectingTrackText: ReferenceWritableKeyPath<GPXReader, String?>?

    init(maxPoints: Int, stopAfter: Int? = nil) {
        self.maxPoints = maxPoints
        self.stopAfter = stopAfter
    }

    private func countPoint(_ parser: XMLParser) {
        pointCount += 1
        if let stopAfter, pointCount >= stopAfter {
            stoppedEarly = true
            parser.abortParsing()
        } else if pointCount > maxPoints {
            exceededPoints = true
            parser.abortParsing()
        }
    }

    private static func position(_ attributes: [String: String]) -> RawPoint {
        var p = RawPoint()
        for (key, value) in attributes {
            switch local(key) {
            case "lat": p.latitude = Double(value.trimmingCharacters(in: .whitespaces)) ?? .nan
            case "lon", "lng": p.longitude = Double(value.trimmingCharacters(in: .whitespaces)) ?? .nan
            default: break
            }
        }
        return p
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
                creator = attributeDict["creator"].map { String($0.prefix(GPXRideImporter.maxTextLength)) }
            }
        case "trkseg":
            segments.append([])
        case "trkpt":
            // A `trkpt` outside a `trkseg` (broken files) still opens a segment.
            if segments.isEmpty || parent != "trkseg" { segments.append([]) }
            point = Self.position(attributeDict)
            countPoint(parser)
        case "rte":
            sawRouteOrWaypoint = true
            routes.append([])
        case "rtept":
            sawRouteOrWaypoint = true
            if routes.isEmpty || parent != "rte" { routes.append([]) }
            point = Self.position(attributeDict)
            countPoint(parser)
        case "wpt":
            sawRouteOrWaypoint = true
        default:
            if point != nil {
                collecting = Self.valueNames[name]
            } else if name == "name" {
                if parent == "trk" { collectingTrackText = \.trackName }
                else if parent == "metadata" { collectingTrackText = \.metadataName }
                else if parent == "rte" { collectingTrackText = \.routeName }
            } else if name == "time", parent == "metadata" {
                hasMetadataTime = true
            } else if name == "type", parent == "trk" {
                collectingTrackText = \.trackType
            } else if name == "bike", parent == "extensions", stack.dropLast(2).last == "metadata" {
                collectingTrackText = \.bikeText
            } else if name == "kind", parent == "extensions", stack.dropLast(2).last == "metadata" {
                collectingTrackText = \.kindText
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting != nil { text += string }
        // Texts are cut anyway (S-41); a little more than the limit leaves room for trimming.
        else if collectingTrackText != nil, text.utf8.count < GPXRideImporter.maxTextLength * 8 { text += string }
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
        if name == "rtept" {
            if let finished = point, !routes.isEmpty {
                routes[routes.count - 1].append(finished)
            }
            point = nil
            return
        }

        if let key = collectingTrackText {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if self[keyPath: key] == nil, !trimmed.isEmpty { self[keyPath: key] = String(trimmed.prefix(GPXRideImporter.maxTextLength)) }
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
        case .accuracy:
            if point?.accuracy == nil, let v = Double(trimmed), v.isFinite, v >= 0 { point?.accuracy = v }
        case .lean:
            if point?.lean == nil, let v = Double(trimmed), v.isFinite, abs(v) <= 90 { point?.lean = v }
        case .acceleration:
            if point?.acceleration == nil, let v = Double(trimmed), v.isFinite, abs(v) <= 5 { point?.acceleration = v }
        case .roughness:
            if point?.roughness == nil, let v = Double(trimmed), v.isFinite, v >= 0, v <= 10 { point?.roughness = v }
        }
    }

    private static func whole(_ text: String) -> Int? {
        guard let v = Double(text), v.isFinite, abs(v) < 100_000 else { return nil }
        return Int(v.rounded())
    }
}
