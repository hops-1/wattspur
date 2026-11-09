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
    /// The offer to switch to iCloud was shown to a user of the folder way.
    static let iCloudSyncOfferShown = "iCloudSyncOfferShown"
    /// The bike of the last saved recording, as the default for the next.
    static let lastRecordingBike = "lastRecordingBike"
    /// The bookmark of the folder the Mac watches (iOS 0.2).
    static let importFolderBookmark = "importFolderBookmark"
    /// Whether the recording map turns with the direction of travel instead of north up (B-280).
    static let recordingMapHeadingUp = "recordingMapHeadingUp"
    /// Whether the recording map colours the track by height (B-283).
    static let recordingTrackByElevation = "recordingTrackByElevation"
    /// Height or speed in the profile while recording (B-277).
    static let recordingProfileKind = "recordingProfileKind"
    /// Set by UI tests and screenshots: import the sample ride at launch.
    static let demoRide = "WattspurDemoRide"
}
