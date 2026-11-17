import AppIntents
import Foundation
import WattspurCore

/// What the next recording is made with (B-286): remembered on this iPhone, not synced. One tap on
/// “Start Ride” takes it; “with … ▾” changes it.
@MainActor
enum RecordingChoice {
    /// The device of the last recording, or of the last choice in the sheet.
    static var last: RecordingDevice? {
        get {
            UserDefaults.standard.data(forKey: PhoneSettingsKey.recordingDevice)
                .flatMap { try? JSONDecoder().decode(RecordingDevice.self, from: $0) }
        }
        set {
            UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: PhoneSettingsKey.recordingDevice)
        }
    }

    /// The setting in “More” before B-286, for the first default only.
    static var oldVehicle: RecordingVehicle? {
        UserDefaults.standard.string(forKey: PhoneSettingsKey.recordingVehicle).flatMap(RecordingVehicle.init(rawValue:))
    }

    static func next(devices: [RideExchange.Bike], activeID: UUID?) -> RecordingDevice {
        RecordingDevice.next(last: last, devices: devices, activeID: activeID, oldVehicle: oldVehicle)
    }

    // MARK: - For Siri and the Shortcuts app

    /// The open devices, written by the library at every reload, so a shortcut finds them before
    /// the library has opened.
    static func cache(devices: [RideExchange.Bike]) {
        let open = devices.filter { !$0.isArchived }
        let data = try? JSONEncoder().encode(open)
        let changed = data != UserDefaults.standard.data(forKey: PhoneSettingsKey.shortcutDevices)
        UserDefaults.standard.set(data, forKey: PhoneSettingsKey.shortcutDevices)
        // Siri only knows the names in “Start a ride with Nugget” once it is told (D.1 of the 1.1 test:
        // it took the last device instead). Once per launch, and whenever the devices change.
        if changed || !toldSiri {
            toldSiri = true
            WattspurShortcuts.updateAppShortcutParameters()
        }
    }

    private static var toldSiri = false

    static var cachedDevices: [RideExchange.Bike] {
        UserDefaults.standard.data(forKey: PhoneSettingsKey.shortcutDevices)
            .flatMap { try? JSONDecoder().decode([RideExchange.Bike].self, from: $0) } ?? []
    }
}

extension RecordingDevice {
    /// The name in the start button and the sheet: the device's, or “Car” or “Motorcycle” without one.
    func name(in devices: [RideExchange.Bike]) -> String {
        if let bikeID, let device = devices.first(where: { $0.id == bikeID }) { return device.name }
        return kind.localizedName
    }

    /// The symbol of its kind, also for the Live Activity.
    var symbol: String { BikeBadge.symbol(kind) }
}

extension BikeKind {
    /// The kind's name as text, as `label` in the profile.
    var localizedName: String {
        switch self {
        case .bike: String(localized: "Bicycle")
        case .mountain: String(localized: "Mountain bike")
        case .road: String(localized: "Road bike")
        case .gravel: String(localized: "Gravel bike")
        case .cargo: String(localized: "Cargo bike")
        case .motorcycle: String(localized: "Motorcycle")
        case .car: String(localized: "Car")
        case .runningShoe: String(localized: "Running shoes")
        }
    }
}
