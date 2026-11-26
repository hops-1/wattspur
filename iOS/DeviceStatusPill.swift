import Combine
import SwiftUI
import UIKit

/// The clock and the iPhone's battery in a small glass capsule (B-388). In landscape iOS hides the
/// status bar, so the recording shows them itself, at the top right above the map style button,
/// as the Bosch Flow app does. A battery symbol and a bolt while charging, no percentage; VoiceOver
/// reads the percentage. It draws again on the full minute and when the battery changes, never on
/// every fix (B-365).
struct DeviceStatusPill: View {
    @State private var battery = BatteryReading.current

    var body: some View {
        HStack(spacing: 8) {
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
            }
            if let level = battery.level {
                HStack(spacing: 3) {
                    Image(systemName: BatteryReading.symbol(for: level))
                        .foregroundStyle(battery.isLow ? Color.orange : Color.primary)
                    if battery.isCharging {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.green)
                            .imageScale(.small)
                    }
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .frame(height: 30)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            BatteryMonitoring.acquire()
            battery = .current
        }
        .onDisappear { BatteryMonitoring.release() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            battery = .current
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            battery = .current
        }
    }

    private var accessibilityText: Text {
        let time = Text(Date.now, format: .dateTime.hour().minute())
        guard let level = battery.level else { return time }
        let percent = Int((level * 100).rounded())
        var text = time + Text(verbatim: ", ") + Text("Battery \(percent) %")
        if battery.isCharging { text = text + Text(verbatim: ", ") + Text("Charging") }
        return text
    }
}

/// What the capsule shows of the battery.
struct BatteryReading: Equatable {
    /// 0 to 1; `nil` when iOS knows no level (the simulator, or monitoring still off).
    var level: Float?
    var isCharging: Bool

    /// Orange below 20 % unless charging, as iOS does.
    var isLow: Bool { (level ?? 1) < 0.2 && !isCharging }

    @MainActor static var current: BatteryReading {
        let device = UIDevice.current
        let level = device.batteryLevel
        let state = device.batteryState
        return BatteryReading(level: level < 0 ? nil : level,
                              isCharging: state == .charging || state == .full)
    }

    /// The SF Symbol nearest to the level.
    static func symbol(for level: Float) -> String {
        switch level {
        case ..<0.13: "battery.0percent"
        case ..<0.38: "battery.25percent"
        case ..<0.63: "battery.50percent"
        case ..<0.88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

/// `UIDevice.isBatteryMonitoringEnabled` is one switch for the whole app; the capsule and the raw
/// motion log (`MotionRecorder`) both need it. It goes off only when neither does.
@MainActor enum BatteryMonitoring {
    private static var users = 0

    static func acquire() {
        users += 1
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    static func release() {
        users = max(0, users - 1)
        if users == 0 { UIDevice.current.isBatteryMonitoringEnabled = false }
    }
}
