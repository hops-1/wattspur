import Foundation

/// What the share extension of the iPhone app makes of the things another app shares (B-301).
/// Apps share a real file (Flow, Files), plain data with or without a name (some trackers), or only a
/// link (komoot, Strava). Wattspur reads FIT and GPX; a link it does not load, but says how to get
/// the file.
public enum SharedItem {
    /// The file type of shared data, from its content first and its name second: `"fit"`, `"gpx"`,
    /// or nil when it is neither. Data without a name still gets its type this way.
    public static func fileExtension(of data: Data, suggestedName: String?) -> String? {
        if isFIT(data) { return "fit" }
        if isGPX(data) { return "gpx" }
        let ext = ((suggestedName ?? "") as NSString).pathExtension.lowercased()
        return ["fit", "gpx"].contains(ext) ? ext : nil
    }

    /// A file name for shared data: the suggested name with the right extension, or a name from the
    /// date when there is none. Never a path, so it cannot leave the folder it is written to.
    public static func fileName(suggestedName: String?, fileExtension ext: String, date: Date = .now) -> String {
        let base = ((suggestedName ?? "") as NSString).lastPathComponent
        var stem = (base as NSString).deletingPathExtension
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stem.hasPrefix(".") { stem = String(stem.drop { $0 == "." }) }
        if stem.isEmpty {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            stem = "Shared \(formatter.string(from: date))"
        }
        return "\(stem).\(ext)"
    }

    /// FIT: the header names “.FIT” at bytes 8 to 11.
    static func isFIT(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let start = data.startIndex
        return data[start + 8 ..< start + 12].elementsEqual(Array(".FIT".utf8))
    }

    /// GPX: a `gpx` element near the start, after the XML declaration and comments.
    static func isGPX(_ data: Data) -> Bool {
        let text = String(decoding: data.prefix(2048), as: UTF8.self).lowercased()
        // The root element, with or without a prefix; not `<gpxdata:…>` or other look-alikes.
        return text.contains(/<([a-z0-9_]+:)?gpx[\s>\/]/)
    }

    /// The service a shared link comes from, for the hint how to export the file there.
    public enum LinkSource: String, Sendable, Equatable {
        case komoot, strava, garmin, other
    }

    /// A shared web link (`http`, `https`): where it is from. Nil for other URLs, such as files.
    public static func linkSource(of url: URL) -> LinkSource? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host()?.lowercased() else { return nil }
        func on(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        if on("komoot.com") || on("komoot.de") { return .komoot }
        if on("strava.com") || on("strava.app.link") { return .strava }
        if on("garmin.com") { return .garmin }
        return .other
    }

    /// Finds a web link in shared text (“Look at my tour on komoot: https://…”).
    public static func link(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).lazy.compactMap(\.url).first { linkSource(of: $0) != nil }
    }
}
