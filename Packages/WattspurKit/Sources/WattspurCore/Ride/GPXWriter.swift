import Foundation

/// Writes a ride as GPX 1.1 (B-112, IMP-09), e.g. for komoot or a navigation device.
///
/// One track with one segment per part: a merged ride keeps the gap between its
/// parts instead of drawing a straight line across it. Times are in UTC. Power and
/// cadence go into the extensions that Garmin and Strava exports use: `<power>`
/// directly, cadence as `gpxtpx:cad` (Garmin TrackPointExtension v2). Programs that
/// do not know them ignore them. A description (the bike, B-136) goes into
/// `<metadata>` and the track, where other programs show it as a note.
public enum GPXWriter {
    /// A continuous recording: the samples' `time` counts from `startDate`.
    public struct Segment: Sendable, Equatable {
        public var startDate: Date
        public var samples: [RideSample]

        public init(startDate: Date, samples: [RideSample]) {
            self.startDate = startDate
            self.samples = samples
        }
    }

    public static let trackPointExtensionNamespace = "http://www.garmin.com/xmlschemas/TrackPointExtension/v2"
    /// Wattspur's own extension: the bike a recording of the iPhone app was ridden on (B-212), so
    /// the Mac assigns the ride without asking (B-213), and the GPS accuracy of each of its points
    /// (`wattspur:accuracy`, metres). Other programs ignore it.
    public static let wattspurNamespace = "https://github.com/hops-1/wattspur/gpx/1"
    /// The `creator` of recordings made with the iPhone app (B-212).
    public static let iPhoneCreator = "Wattspur iOS"

    public static func document(name: String, segments: [Segment], description: String? = nil,
                                creator: String = "Wattspur", bikeID: UUID? = nil) -> Data {
        let note = description.flatMap { $0.isEmpty ? nil : escape($0) }
        let ownExtension = bikeID != nil || segments.contains { $0.samples.contains { $0.horizontalAccuracy != nil } }
        let wattspur = ownExtension ? "xmlns:wattspur=\"\(wattspurNamespace)\" " : ""
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="\(escape(creator))" xmlns="http://www.topografix.com/GPX/1/1" \
        xmlns:gpxtpx="\(trackPointExtensionNamespace)" \(wattspur)\
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
        xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escape(name))</name>

        """
        if let note { xml += "    <desc>\(note)</desc>\n" }
        if let start = segments.map(\.startDate).min() {
            xml += "    <time>\(timestamp(start))</time>\n"
        }
        if let bikeID {
            xml += "    <extensions><wattspur:bike>\(bikeID.uuidString)</wattspur:bike></extensions>\n"
        }
        xml += """
          </metadata>
          <trk>
            <name>\(escape(name))</name>

        """
        if let note { xml += "    <desc>\(note)</desc>\n" }
        xml += "    <type>cycling</type>\n"
        for segment in segments {
            let points = segment.samples.filter { $0.latitude != nil && $0.longitude != nil }
            guard !points.isEmpty else { continue }
            xml += "    <trkseg>\n"
            for sample in points {
                xml += trackPoint(sample, start: segment.startDate)
            }
            xml += "    </trkseg>\n"
        }
        xml += "  </trk>\n</gpx>\n"
        return Data(xml.utf8)
    }

    /// "2026-10-18T12:12:13Z", or "2026-10-18T12:12:13.250Z" for a time between whole seconds
    /// (B-233): the iPhone's fixes do not fall on whole seconds, and two of them in one second
    /// would otherwise get the same time and one would be lost on import.
    static func timestamp(_ date: Date) -> String {
        let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
        let (seconds, fraction) = milliseconds.quotientAndRemainder(dividingBy: 1000)
        let whole = fraction < 0 ? seconds - 1 : seconds
        let text = Date(timeIntervalSince1970: TimeInterval(whole))
            .formatted(Date.ISO8601FormatStyle(timeZone: TimeZone(identifier: "UTC")!))
        guard fraction != 0 else { return text }
        return text.dropLast() + String(format: ".%03dZ", fraction < 0 ? fraction + 1000 : fraction)
    }

    private static func trackPoint(_ s: RideSample, start: Date) -> String {
        // String(format:) without a locale always writes a decimal point.
        var point = "      <trkpt lat=\"\(String(format: "%.7f", s.latitude ?? 0))\" lon=\"\(String(format: "%.7f", s.longitude ?? 0))\">"
        if let altitude = s.altitude { point += "<ele>\(String(format: "%.1f", altitude))</ele>" }
        point += "<time>\(timestamp(start.addingTimeInterval(s.time)))</time>"
        // Only measured cadence: the held value is for charts, not for data.
        let cadence = s.cadenceMeasured ? s.cadence : nil
        let accuracy = s.horizontalAccuracy.flatMap { $0 >= 0 && $0.isFinite ? $0 : nil }
        if s.power != nil || cadence != nil || accuracy != nil {
            point += "<extensions>"
            if let power = s.power { point += "<power>\(power)</power>" }
            if let cadence {
                point += "<gpxtpx:TrackPointExtension><gpxtpx:cad>\(cadence)</gpxtpx:cad></gpxtpx:TrackPointExtension>"
            }
            if let accuracy { point += "<wattspur:accuracy>\(String(format: "%.1f", accuracy))</wattspur:accuracy>" }
            point += "</extensions>"
        }
        return point + "</trkpt>\n"
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// A file name without characters that Finder does not accept.
    public static func fileName(_ title: String) -> String {
        title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".gpx"
    }
}

