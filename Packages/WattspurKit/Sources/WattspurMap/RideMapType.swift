import WattspurCore

/// Map type of all maps (MAP-01): Apple's three and the OpenStreetMap styles (B-061, MAP-02).
/// The raw values are stored in the settings; the first three are the ones from before 1.8.
/// The names for the user come from each app (rule 8).
public enum RideMapType: String, CaseIterable, Identifiable, Sendable {
    case standard, satellite, hybrid
    case openStreetMap = "osm", cyclOSM = "cyclosm", openTopoMap = "opentopomap"
    public var id: Self { self }

    public static let apple: [RideMapType] = [.standard, .satellite, .hybrid]
    public static let openStreetMapStyles: [RideMapType] = [.openStreetMap, .cyclOSM, .openTopoMap]

    /// The tile server of an OpenStreetMap style; `nil` for Apple's maps.
    public var tileSource: TileSource? {
        switch self {
        case .standard, .satellite, .hybrid: nil
        case .openStreetMap: .openStreetMap
        case .cyclOSM: .cyclOSM
        case .openTopoMap: .openTopoMap
        }
    }
}
