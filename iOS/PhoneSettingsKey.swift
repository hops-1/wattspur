import Foundation

/// The keys of the iPhone app's settings in one place, like `SettingsKey` on the Mac (rule 7, R-65).
/// The values are stored on users' iPhones: never change one, only add new keys.
enum PhoneSettingsKey {
    /// What was recorded, chosen in “More” until B-286 (`RecordingVehicle`); only read once, for the
    /// first default of `recordingDevice`.
    static let recordingVehicle = "recordingVehicle"
    /// The iPad's sidebar with names (`true`) or only the symbols (B-292); each iPad keeps its own.
    static let padSidebarExpanded = "padSidebarExpanded"
    /// How the iPad shows the charts of a ride (`ChartLayout`, B-292).
    static let padChartLayout = "padChartLayout"
    /// The device of the last recording (B-286), JSON of `RecordingDevice`.
    static let recordingDevice = "recordingDevice"
    /// The open devices for Siri and the Shortcuts app (B-286), JSON, written at every reload.
    static let shortcutDevices = "shortcutDevices"
    /// Whether the raw motion data is written while recording (V-16).
    static let recordRawMotion = "recordRawMotion"
    /// What the detail map colours the track by (`TrackColouring`, B-248).
    static let trackColouring = "trackColouring"
    /// The user's choice for iCloud sync (B-218).
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    // "iCloudSyncOfferShown" (the offer to switch to iCloud, iOS 0.3 to 0.5) is no longer read.
    /// The bike of the last saved recording, as the default for the next.
    static let lastRecordingBike = "lastRecordingBike"
    /// The bookmark of the folder the Mac watched (iOS 0.2 to 0.5). Since 0.6 only read to know who
    /// used the folder way (B-263).
    static let importFolderBookmark = "importFolderBookmark"
    /// Whether the recording map turns with the direction of travel instead of north up (B-280).
    static let recordingMapHeadingUp = "recordingMapHeadingUp"
    /// Whether the recording map colours the track by height (B-283).
    static let recordingTrackByElevation = "recordingTrackByElevation"
    // "folderEndNoticeShown" (the notice in 0.5.3 that the folder ends with 0.6) is no longer read.
    /// The notice that the folder exchange ended was shown (B-263, part 2).
    static let folderGoneNoticeShown = "folderGoneNoticeShown"
    /// The map style of every map, Apple's or an OpenStreetMap style (`RideMapType`, B-226); the same
    /// raw values as on the Mac.
    static let mapType = "mapType"
    /// The map of all rides (B-227): lines or heat map (`RidesMapStyle.Mode`), the period (`RidePeriod`)
    /// and the bike (`BikeFilter`).
    static let ridesMapMode = "ridesMapMode"
    static let ridesMapPeriod = "ridesMapPeriod"
    static let ridesMapBike = "ridesMapBike"
    /// The sport Overview, Rides and Map show (B-289, `Sport`); each iPhone keeps its own, not synced.
    static let shownSport = "shownSport"
    /// The legend of the coloured track on the ride's map is folded to its colours (tap to unfold).
    static let mapLegendFolded = "mapLegendFolded"
    /// Height or speed in the profile while recording (B-277).
    static let recordingProfileKind = "recordingProfileKind"
    /// The backup on the iPhone (B-302): whether it runs by itself once a week, the folder chosen last
    /// (a bookmark, for the automatic backup) and when the last backup was made.
    static let autoBackup = "autoBackup"
    static let backupFolderBookmark = "backupFolderBookmark"
    static let lastBackupDate = "lastBackupDate"
    /// The analysis on the iPad (B-295): the period (`AnalysisPeriodKind`), what the bars show
    /// (`BarMetric`) and the device (`BikeFilter`); each iPad keeps its own.
    static let padAnalysisPeriod = "padAnalysisPeriod"
    static let padAnalysisBarMetric = "padAnalysisBarMetric"
    static let padAnalysisDevice = "padAnalysisDevice"
    /// The highlights on the iPad (B-295): the tab (`PadHighlightsTab`) and the device (`BikeFilter`).
    static let padHighlightsTab = "padHighlightsTab"
    static let padHighlightsDevice = "padHighlightsDevice"
    /// The comparison on the iPad (B-334): whether each value shows its difference from the average.
    static let padCompareShowsDeviation = "padCompareShowsDeviation"
    /// Auto-start (B-311): whether “Start Ride” from a shortcut without a device waits as “Ready” for
    /// the vehicle to move, off by default; and what each device starts with (JSON of
    /// `[UUID: AutoStart.Trigger]`), kept on this iPhone only.
    static let autoStart = "autoStart"
    static let autoStartTriggers = "autoStartTriggers"
    /// How an auto-started ride ends (B-339): when the connection ends (the second automation runs
    /// “End Ride”), after standing still, and how many minutes of standing still; both on by default.
    static let autoStartEndOnDisconnect = "autoStartEndOnDisconnect"
    static let autoStartEndAfterStandstill = "autoStartEndAfterStandstill"
    static let autoStartStandstillMinutes = "autoStartStandstillMinutes"
    /// Set by UI tests and screenshots: import the sample ride at launch.
    static let demoRide = "WattspurDemoRide"
}
