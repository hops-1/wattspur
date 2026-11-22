@preconcurrency import Darwin
import Foundation
import WattspurCore

/// Writes the health log of a recording (B-369, `RecordingHealth`) into the documents folder
/// “Diagnose”, which the Files app shows under “On My iPhone › Wattspur”: one line a minute, no
/// place, never synced or sent. The last `keptFiles` recordings stay.
@MainActor
final class RecordingDiagnostics {
    private static let folderName = "Diagnose"
    private static let keptFiles = 10

    private var health: RecordingHealth
    private let file: FileHandle

    init?(start: Date) {
        let folder = URL.documentsDirectory.appending(path: Self.folderName)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Self.removeOld(in: folder)
        let name = start.formatted(.verbatim(
            "Aufnahme-\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits).csv",
            locale: Locale(identifier: "en_US_POSIX"), timeZone: .current, calendar: Calendar(identifier: .gregorian)))
        let url = folder.appending(path: name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let file = try? FileHandle(forWritingTo: url) else { return nil }
        self.file = file
        health = RecordingHealth(start: start, cpuSeconds: Self.cpuSeconds())
        try? file.write(contentsOf: Data("# Wattspur \(AppInfo.version) (\(AppInfo.build))\n\(RecordingHealth.header)\n".utf8))
    }

    func position(measured: Date, hasBarometer: Bool, isVisible: Bool) {
        let now = Date.now
        health.position(measured: measured, handled: now, hasBarometer: hasBarometer)
        if health.isDue(at: now) { writeLine(at: now, isVisible: isVisible) }
    }

    func stop(isVisible: Bool) {
        writeLine(at: .now, isVisible: isVisible)
        try? file.close()
    }

    private func writeLine(at date: Date, isVisible: Bool) {
        let process = ProcessInfo.processInfo
        let device = RecordingHealth.Device(cpuSeconds: Self.cpuSeconds(), footprintMB: Self.footprintMB(),
                                            thermal: process.thermalState.rawValue, isVisible: isVisible,
                                            lowPower: process.isLowPowerModeEnabled)
        try? file.write(contentsOf: Data((health.line(at: date, device: device) + "\n").utf8))
    }

    /// The file names begin with the date, so sorting them by name sorts them by age.
    private static func removeOld(in folder: URL) {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix("Aufnahme-") && $0.hasSuffix(".csv") }
            .sorted()
        for name in names.dropLast(keptFiles - 1) {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    private static func cpuSeconds() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    /// The memory iOS counts against the app, the number its reports show.
    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_000_000 : 0
    }
}
