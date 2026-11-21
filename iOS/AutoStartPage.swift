import AVFoundation
import Combine
import SwiftUI
import WattspurCore

/// “More › Recording” (B-311): auto-start on or off, and what each device starts with. The trigger
/// itself is an automation in the Shortcuts app; iOS lets no app come to the front by itself.
struct AutoStartPage: View {
    @Environment(PhoneLibrary.self) private var library
    @AppStorage(PhoneSettingsKey.autoStart) private var isOn = false
    @AppStorage(PhoneSettingsKey.autoStartEndOnDisconnect) private var endsOnDisconnect = true
    @AppStorage(PhoneSettingsKey.autoStartEndAfterStandstill) private var endsAfterStandstill = true
    @AppStorage(PhoneSettingsKey.autoStartStandstillMinutes) private var standstillMinutes = AutoStart.defaultStandstillMinutes
    @State private var triggers = AutoStartSettings.triggers
    /// The connection now, read again whenever the audio route changes.
    @State private var ports = AutoStartSettings.currentPorts

    private var devices: [RideExchange.Bike] { (library.state?.bikes ?? []).filter { !$0.isArchived } }

    var body: some View {
        Form {
            Section {
                Toggle("Auto-Start", isOn: $isOn)
            } footer: {
                Text("When a Shortcuts automation runs “Start Ride” without a device, Wattspur waits as “Ready” and begins the ride when you drive off, above 10 km/h. The device comes from the connection below, otherwise it is the last one.")
            }
            if isOn {
                Section {
                    ForEach(devices) { device in
                        Picker(selection: binding(for: device.id)) {
                            Text("Nothing").tag(AutoStart.Trigger?.none)
                            Text(verbatim: "CarPlay").tag(AutoStart.Trigger?.some(.carPlay))
                            ForEach(bluetoothNames(for: device.id), id: \.self) { name in
                                Text(verbatim: name).tag(AutoStart.Trigger?.some(.bluetooth(name)))
                            }
                        } label: {
                            Label {
                                Text(verbatim: device.name)
                            } icon: {
                                (BikeKind(rawValue: device.kind) ?? .bike).image()
                            }
                        }
                    }
                    LabeledContent("Connected now", value: connectedNow)
                } header: {
                    Text("Starts With")
                } footer: {
                    Text("To choose a Bluetooth device, connect the iPhone to it first, e.g. the car's hands-free or the motorcycle headset; its name then shows up here.")
                }
                Section {
                    Toggle("When Disconnected", isOn: $endsOnDisconnect)
                    Toggle("After Standing Still", isOn: $endsAfterStandstill)
                    if endsAfterStandstill {
                        Picker("Standing Still For", selection: $standstillMinutes) {
                            ForEach(AutoStart.standstillChoices, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                    }
                } header: {
                    Text("End")
                } footer: {
                    Text("The ride is saved by itself, with the device and the places at start and end as its name, and a notification says so. Rides under 500 m are not kept. “Ready” without driving off ends after the time standing still.")
                }
                Section {
                    Text("1. Open the Shortcuts app, then Automation › New Automation.")
                    Text("2. Choose CarPlay or Bluetooth (then your device), and Connects.")
                    Text("3. Choose Run Immediately, then the action Wattspur › Start Ride, without a device.")
                    Text("4. For the end: a second automation with Disconnects and Wattspur › End Ride.")
                } header: {
                    Text("Setting Up the Automation")
                }
                .font(.subheadline)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { _ in
            ports = AutoStartSettings.currentPorts
        }
        .onAppear { ports = AutoStartSettings.currentPorts }
        // The notification after an automatic end needs the permission; ask when it is switched on.
        .onChange(of: isOn) { _, on in if on { RideSavedNotice.requestPermission() } }
    }

    private func binding(for id: UUID) -> Binding<AutoStart.Trigger?> {
        Binding {
            triggers[id]
        } set: { trigger in
            triggers[id] = trigger
            AutoStartSettings.triggers = triggers
        }
    }

    /// The Bluetooth device connected now and the one chosen before, so the choice stays visible
    /// when it is not connected.
    private func bluetoothNames(for id: UUID) -> [String] {
        var names = ports.filter { $0.kind == .bluetooth }.map(\.name)
        if case .bluetooth(let saved)? = triggers[id], !names.contains(saved) { names.insert(saved, at: 0) }
        return names
    }

    private var connectedNow: String {
        let names = ports.filter { $0.kind != .other }.map(\.name)
        return names.isEmpty ? String(localized: "Nothing") : names.formatted(.list(type: .and))
    }
}
