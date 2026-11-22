import Foundation

/// The health log of a recording (B-369): one line a minute with what it takes to see an overload
/// afterwards. No place, no height, no name: only counts, delays and the state of the app and iPhone.
public struct RecordingHealth: Sendable {
    /// What the app measures at the end of a minute.
    public struct Device: Sendable {
        /// CPU seconds of the process since its launch.
        public var cpuSeconds: Double
        public var footprintMB: Double
        /// `ProcessInfo.ThermalState`: 0 nominal to 3 critical.
        public var thermal: Int
        public var isVisible: Bool
        public var lowPower: Bool

        public init(cpuSeconds: Double, footprintMB: Double, thermal: Int, isVisible: Bool, lowPower: Bool) {
            self.cpuSeconds = cpuSeconds
            self.footprintMB = footprintMB
            self.thermal = thermal
            self.isVisible = isVisible
            self.lowPower = lowPower
        }
    }

    public static let interval: TimeInterval = 60
    public static let header = "time,seconds,visible,positions,max_delay_s,no_barometer,cpu_percent,memory_mb,thermal,low_power"

    private var since: Date
    private var cpuSeconds: Double
    private var positions = 0
    private var maxDelay = 0.0
    private var withoutBarometer = 0

    public init(start: Date, cpuSeconds: Double) {
        since = start
        self.cpuSeconds = cpuSeconds
    }

    /// One position: when it was measured and when the app got to it.
    public mutating func position(measured: Date, handled: Date, hasBarometer: Bool) {
        positions += 1
        maxDelay = max(maxDelay, handled.timeIntervalSince(measured))
        if !hasBarometer { withoutBarometer += 1 }
    }

    public func isDue(at date: Date) -> Bool { date.timeIntervalSince(since) >= Self.interval }

    /// The line for the time since the line before; the next one starts at zero.
    public mutating func line(at date: Date, device: Device) -> String {
        let seconds = date.timeIntervalSince(since)
        let cpu = seconds > 0 ? (device.cpuSeconds - cpuSeconds) / seconds * 100 : 0
        let fields = [
            date.formatted(.iso8601),
            String(Int(seconds.rounded())),
            device.isVisible ? "1" : "0",
            String(positions),
            String((maxDelay * 10).rounded() / 10),
            String(withoutBarometer),
            String(Int(cpu.rounded())),
            String(Int(device.footprintMB.rounded())),
            String(device.thermal),
            device.lowPower ? "1" : "0",
        ]
        self = RecordingHealth(start: date, cpuSeconds: device.cpuSeconds)
        return fields.joined(separator: ",")
    }
}
