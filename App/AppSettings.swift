import Foundation

/// The keys under which the app remembers settings in `UserDefaults` and `@AppStorage`.
///
/// The values are what earlier versions wrote. Changing one makes people lose that setting, so
/// they stay as they are; a new setting gets a new line here.
enum SettingsKey {
    static let setupCompleted = "setupCompleted"
    static let bikesHintDone = "bikesHintDone"
    static let sidebarCompact = "sidebarCompact"
    static let sidebarWidth = "sidebarWidth"
    static let listWidth = "listWidth"
    static let multiSelectTipDone = "multiSelectTipDone"
    static let rideSortOrder = "rideSortOrder"
    static let ridePeriod = "ridePeriod"
    /// The distance band of the ride list (B-244), shared rule with the iPhone (`RideFilter`).
    static let rideDistance = "rideDistance"
    static let bikeFilterRides = "bikeFilter.rides"
    static let sourceFilterRides = "sourceFilter.rides"
    static let analysisPeriod = "analysisPeriod"
    static let analysisBarMetric = "analysisBarMetric"
    static let bikeFilterAnalysis = "bikeFilter.analysis"
    static let sourceFilterAnalysis = "sourceFilter.analysis"
    static let bikeFilterHighlights = "bikeFilter.highlights"
    static let sourceFilterHighlights = "sourceFilter.highlights"
    static let mapPeriod = "mapPeriod"
    static let mapType = "mapType"
    static let mapMode = "mapMode"
    /// Lines or heat map can be hidden with a second click in "Customize Map" (B-061).
    static let mapShowsRides = "mapShowsRides"
    static let bikeFilterMap = "bikeFilter.map"
    static let sourceFilterMap = "sourceFilter.map"
    static let chartAxis = "chartAxis"
    /// The route on the ride's map coloured by curve (B-181).
    static let routeByCurves = "routeByCurves"
    /// The ride's map coloured by lean angle, for rides with lean angles (B-247).
    static let routeByLean = "routeByLean"
    /// The ride's map coloured by road surface (B-248).
    static let routeBySurface = "routeBySurface"
    /// The route by height on the ride's map (B-063).
    static let routeByElevation = "routeByElevation"
    /// The layer "Curvy roads" on the maps (B-183).
    static let showsCurvyRoads = "showsCurvyRoads"
    static let compareShowsDeviation = "compareShowsDeviation"
    static let similarRoutesThreshold = "similarRoutesThreshold"
    static let dismissedRouteSuggestions = "dismissedRouteSuggestions"
    static let calorieMode = "calorieMode"
    static let mergeSuggestionGapMinutes = "mergeSuggestionGapMinutes"
    static let recordsCheckedUntil = "recordsCheckedUntil"
    static let watchFolderEnabled = "watchFolderEnabled"
    static let watchFolderBookmark = "watchFolderBookmark"
    /// Write the state for the iPhone into the import folder (B-208).
    static let phoneStateEnabled = "phoneStateEnabled"
    /// "Sync with iCloud" (B-072); takes effect at the next start.
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    /// When the backup before the first sync was made (P-22).
    static let iCloudSyncBackupDate = "iCloudSyncBackupDate"
    // Update notice (B-172); earlier versions did not write these.
    static let updateCheckEnabled = "updateCheckEnabled"
    static let updateCheckedAt = "updateCheckedAt"
    static let updateLatestTag = "updateLatestTag"
    static let updateLatestLink = "updateLatestLink"
    static let updateDismissedVersion = "updateDismissedVersion"
}
