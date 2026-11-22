import AVFoundation
import Foundation
import WattspurCore

/// Auto-start on this iPhone (B-311): the switch in “More › Recording” and what each device starts
/// with. Not synced: the connection to CarPlay or a headset belongs to this iPhone.
@MainActor
enum AutoStartSettings {
    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: PhoneSettingsKey.autoStart) }
        set { UserDefaults.standard.set(newValue, forKey: PhoneSettingsKey.autoStart) }
    }

    /// “End Ride” from the automation when the connection ends saves the ride by itself (B-339).
    static var endsOnDisconnect: Bool {
        UserDefaults.standard.object(forKey: PhoneSettingsKey.autoStartEndOnDisconnect) as? Bool ?? true
    }

    /// The ride ends by itself after standing still (B-339).
    static var endsAfterStandstill: Bool {
        UserDefaults.standard.object(forKey: PhoneSettingsKey.autoStartEndAfterStandstill) as? Bool ?? true
    }

    /// Minutes of standing still before the ride ends, and before “Ready” ends without one.
    static var standstillMinutes: Int {
        let minutes = UserDefaults.standard.integer(forKey: PhoneSettingsKey.autoStartStandstillMinutes)
        return AutoStart.standstillChoices.contains(minutes) ? minutes : AutoStart.defaultStandstillMinutes
    }

    static var triggers: [UUID: AutoStart.Trigger] {
        get {
            UserDefaults.standard.data(forKey: PhoneSettingsKey.autoStartTriggers)
                .flatMap { try? JSONDecoder().decode([UUID: AutoStart.Trigger].self, from: $0) } ?? [:]
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: PhoneSettingsKey.autoStartTriggers) }
    }

    /// The outputs of the audio route now: CarPlay, a Bluetooth device (hands-free, headset,
    /// speaker) or something else. Reading the route needs no audio session of Wattspur's own.
    static var currentPorts: [AutoStart.AudioPort] {
        AVAudioSession.sharedInstance().currentRoute.outputs.map { output in
            let kind: AutoStart.AudioPort.Kind = switch output.portType {
            case .carAudio: .carPlay
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE: .bluetooth
            default: .other
            }
            return AutoStart.AudioPort(kind: kind, name: output.portName)
        }
    }

    /// What “Ready” records with now (B-370): the connection's device, else the last car or motorcycle.
    static func readyDevice(devices: [RideExchange.Bike]) -> RecordingDevice {
        AutoStart.readyDevice(for: currentPorts, triggers: triggers, devices: devices,
                              last: RecordingChoice.last, lastVehicle: RecordingChoice.last(of: .vehicle))
    }

    /// The device of the connection there now, if one starts with it.
    static func deviceForConnection(devices: [RideExchange.Bike]) -> RecordingDevice? {
        AutoStart.device(for: currentPorts, triggers: triggers, devices: devices)
    }
}
