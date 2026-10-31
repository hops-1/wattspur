import Foundation

/// The regions of curvy roads the user has imported (B-182): one compact file per region in a
/// folder of its own. They are reference data for the map, not rides, so they do not live in
/// the SwiftData store, and they are not part of the library backup; the user can load the
/// files again from roadcurvature.com.
public struct CurvyRoadLibrary: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    static let fileExtension = "curvyroads"

    /// The regions that are there, by name; files that cannot be read are skipped.
    public func regions() -> [CurvyRegion.Info] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { url in (try? Data(contentsOf: url, options: .mappedIfSafe)).flatMap { try? CurvyRegion.info(from: $0) } }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Every road of every region; a region that cannot be read is skipped.
    public func roads() -> [CurvyRoad] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == Self.fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .flatMap { url -> [CurvyRoad] in
                guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
                return (try? CurvyRegion(data: data).roads) ?? []
            }
    }

    /// Reads a KMZ or KML of roadcurvature.com and keeps it as a region; a region of the same
    /// name (the same state, perhaps with fewer roads) is replaced. Takes a while for a large
    /// state, so call it off the main actor.
    @discardableResult
    public func install(from url: URL, limits: CurvyRoads.Limits = CurvyRoads.Limits(), now: Date = .now) throws -> CurvyRegion.Info {
        let roads = try CurvyRoads.read(from: url, limits: limits)
        let id = Self.regionID(forFileNamed: url.lastPathComponent)
        let region = CurvyRegion(id: id, name: Self.regionName(forID: id), importedAt: now, roads: roads)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try region.encoded().write(to: file(for: id), options: .atomic)
        return region.info
    }

    public func remove(id: String) {
        try? FileManager.default.removeItem(at: file(for: id))
    }

    private func file(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension(Self.fileExtension)
    }

    /// "hessen.c_300.kmz" → "hessen": the state's name up to the first dot, in a form safe for a file name.
    static func regionID(forFileNamed fileName: String) -> String {
        let stem = fileName.split(separator: ".", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let safe = stem.lowercased().unicodeScalars.map { scalar -> Character in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-" || scalar == "_" ? Character(scalar) : "-"
        }
        let id = String(safe).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return id.isEmpty ? "region" : id
    }

    /// "nordrhein-westfalen" → "Nordrhein Westfalen".
    static func regionName(forID id: String) -> String {
        id.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
    }
}
