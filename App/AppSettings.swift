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
    static let bikeFilterMap = "bikeFilter.map"
    static let sourceFilterMap = "sourceFilter.map"
    static let chartAxis = "chartAxis"
    static let compareShowsDeviation = "compareShowsDeviation"
    static let similarRoutesThreshold = "similarRoutesThreshold"
    static let calorieMode = "calorieMode"
    static let mergeSuggestionGapMinutes = "mergeSuggestionGapMinutes"
    static let recordsCheckedUntil = "recordsCheckedUntil"
    static let watchFolderEnabled = "watchFolderEnabled"
    static let watchFolderBookmark = "watchFolderBookmark"
    // Update notice (B-172); earlier versions did not write these.
    static let updateCheckEnabled = "updateCheckEnabled"
    static let updateCheckedAt = "updateCheckedAt"
    static let updateLatestTag = "updateLatestTag"
    static let updateLatestLink = "updateLatestLink"
    static let updateDismissedVersion = "updateDismissedVersion"
}
