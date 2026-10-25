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

    public static func document(name: String, segments: [Segment], description: String? = nil, creator: String = "Wattspur") -> Data {
        let note = description.flatMap { $0.isEmpty ? nil : escape($0) }
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="\(escape(creator))" xmlns="http://www.topografix.com/GPX/1/1" \
        xmlns:gpxtpx="\(trackPointExtensionNamespace)" \
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
        xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escape(name))</name>

        """
        if let note { xml += "    <desc>\(note)</desc>\n" }
        if let start = segments.map(\.startDate).min() {
            xml += "    <time>\(timestamp(start))</time>\n"
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

    /// "2026-10-18T12:12:13Z"
    static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: TimeZone(identifier: "UTC")!))
    }

    private static func trackPoint(_ s: RideSample, start: Date) -> String {
        // String(format:) without a locale always writes a decimal point.
        var point = "      <trkpt lat=\"\(String(format: "%.7f", s.latitude ?? 0))\" lon=\"\(String(format: "%.7f", s.longitude ?? 0))\">"
        if let altitude = s.altitude { point += "<ele>\(String(format: "%.1f", altitude))</ele>" }
        point += "<time>\(timestamp(start.addingTimeInterval(s.time)))</time>"
        // Only measured cadence: the held value is for charts, not for data.
        let cadence = s.cadenceMeasured ? s.cadence : nil
        if s.power != nil || cadence != nil {
            point += "<extensions>"
            if let power = s.power { point += "<power>\(power)</power>" }
            if let cadence {
                point += "<gpxtpx:TrackPointExtension><gpxtpx:cad>\(cadence)</gpxtpx:cad></gpxtpx:TrackPointExtension>"
            }
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
