import Foundation

/// The keys of the iPhone app's settings in one place, like `SettingsKey` on the Mac (rule 7, R-65).
/// The values are stored on users' iPhones: never change one, only add new keys.
enum PhoneSettingsKey {
    /// What is recorded, chosen in “More” (`RecordingVehicle`).
    static let recordingVehicle = "recordingVehicle"
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
    /// The legend of the coloured track on the ride's map is folded to its colours (tap to unfold).
    static let mapLegendFolded = "mapLegendFolded"
    /// Height or speed in the profile while recording (B-277).
    static let recordingProfileKind = "recordingProfileKind"
    /// Set by UI tests and screenshots: import the sample ride at launch.
    static let demoRide = "WattspurDemoRide"
}
