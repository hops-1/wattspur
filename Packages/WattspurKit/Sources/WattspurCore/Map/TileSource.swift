import Foundation

// Map styles from OpenStreetMap tile servers (B-061, MAP-02). The terms of each server
// are in docs/RECHERCHE-KARTEN.md: own User-Agent, visible attribution, caching by the
// HTTP headers, no prefetching. The app loads the tiles; this only says where they are.

/// A raster tile server with 256-pixel tiles in Web Mercator.
public struct TileSource: Sendable, Hashable, Identifiable {
    /// Stable key, also stored in the settings.
    public let id: String
    /// Name shown in the map style picker.
    public let name: String
    /// `{s}` subdomain, `{z}` zoom, `{x}` column, `{y}` row.
    let template: String
    let subdomains: [String]
    /// Highest zoom the server renders; MapKit enlarges the last level beyond it.
    public let maxZoom: Int
    public let tileSize: Int
    /// The credit the server asks for, shown on the map and in the PDF.
    public let attribution: String
    /// Where the credit links to.
    public let attributionURL: URL

    /// The address of one tile. The subdomain follows from the tile, so the same
    /// tile always has the same address and the cache finds it again.
    public func url(for tile: Tile) -> URL {
        let subdomain = subdomains.isEmpty ? "" : subdomains[(tile.x + tile.y) % subdomains.count]
        let address = template
            .replacingOccurrences(of: "{s}", with: subdomain)
            .replacingOccurrences(of: "{z}", with: String(tile.zoom))
            .replacingOccurrences(of: "{x}", with: String(tile.x))
            .replacingOccurrences(of: "{y}", with: String(tile.y))
        return URL(string: address)!
    }

    public static let openStreetMap = TileSource(
        id: "osm", name: "OpenStreetMap",
        template: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", subdomains: [],
        maxZoom: 19, tileSize: 256,
        attribution: "© OpenStreetMap contributors",
        attributionURL: URL(string: "https://www.openstreetmap.org/copyright")!)

    /// Hosted by OpenStreetMap France; the address has moved before, so it lives only here.
    public static let cyclOSM = TileSource(
        id: "cyclosm", name: "CyclOSM",
        template: "https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png", subdomains: ["a", "b", "c"],
        maxZoom: 20, tileSize: 256,
        attribution: "© OpenStreetMap contributors · CyclOSM · Tiles OpenStreetMap France",
        attributionURL: URL(string: "https://www.cyclosm.org")!)

    /// The only style with contour lines and hill shading.
    public static let openTopoMap = TileSource(
        id: "opentopomap", name: "OpenTopoMap",
        template: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png", subdomains: ["a", "b", "c"],
        maxZoom: 17, tileSize: 256,
        attribution: "Map data: © OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)",
        attributionURL: URL(string: "https://opentopomap.org/about")!)

    public static let all: [TileSource] = [.openStreetMap, .cyclOSM, .openTopoMap]
}
