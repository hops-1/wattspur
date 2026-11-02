import SwiftUI
import UniformTypeIdentifiers

/// The tab “More” (design C): the folder shared with the Mac and the version. For now it also
/// holds the tests of the spike V-14, which go away again with the real recording (B-211).
struct MoreView: View {
    @Environment(ImportFolder.self) private var folder

    var body: some View {
        Form {
            Section {
                if let url = folder.url {
                    LabeledContent("Folder", value: url.lastPathComponent)
                } else {
                    Text("No folder chosen yet.")
                        .foregroundStyle(.secondary)
                }
                ChooseFolderButton(title: folder.url == nil ? "Choose Folder…" : "Choose Another Folder…")
                if let problem = folder.problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Wattspur Import")
            } footer: {
                Text("Choose the folder “Wattspur Import” in iCloud Drive that the Mac watches.")
            }

            FolderTestSection()
            GPSTestSection()

            Section {
                VersionFooter()
            }
        }
        .navigationTitle("More")
    }
}

/// Spike V-14 (1): write, read and list files in the chosen folder.
private struct FolderTestSection: View {
    @Environment(ImportFolder.self) private var folder
    @State private var lines: [String] = []

    var body: some View {
        Section {
            Button("Write Test File") { writeTestFile() }
            Button("Read Test File") { readTestFile() }
            Button("List Folder") { listFolder() }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        } header: {
            Text("Test: Folder")
        } footer: {
            Text("Writes “iPhone/Test/Write Test.txt” with the time. Look on the Mac when it appears.")
        }
        .disabled(folder.url == nil)
    }

    private static let testPath = "iPhone/Test/Write Test.txt"

    private func writeTestFile() {
        let text = "Written on the iPhone at \(Date.now.formatted(date: .numeric, time: .standard))\n" // stays English: a test file
        lines = [Self.attempt { try folder.write(Data(text.utf8), to: Self.testPath); return text }]
    }

    private func readTestFile() {
        lines = [Self.attempt { String(decoding: try folder.read(Self.testPath), as: UTF8.self) }]
    }

    private func listFolder() {
        lines = [Self.attempt {
            let root = try folder.contents()
            let placeholders = root.filter { $0.hasSuffix(".icloud") }.count
            return String(localized: "\(root.count) entries, \(placeholders) not downloaded:") + "\n" + root.joined(separator: "\n")
        }]
    }

    private static func attempt(_ body: () throws -> String) -> String {
        do { return try body() } catch { return "⚠︎ \(error.localizedDescription)" }
    }
}

/// Spike V-14 (2): a GPS recording with the screen locked.
private struct GPSTestSection: View {
    @Environment(ImportFolder.self) private var folder
    @Environment(GPSTest.self) private var test
    @State private var message: String?

    var body: some View {
        Section {
            if test.isRunning {
                Button("Stop GPS Test", role: .destructive) { test.stopTest() }
            } else {
                Button("Start GPS Test") { test.startTest() }
            }
            if test.start != nil {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    results
                }
            }
            if !test.isRunning, test.points > 0 {
                Button("Save CSV in Folder") { saveCSV() }
                    .disabled(folder.url == nil)
                Button("Hand Over to the Mac as GPX") { saveGPX() }
                    .disabled(folder.url == nil)
            }
            if let message {
                Text(message).font(.footnote)
            }
        } header: {
            Text("Test: GPS Recording")
        } footer: {
            Text("Start, lock the screen and ride for about 30 minutes. Then stop and note the figures.")
        }
    }

    @ViewBuilder private var results: some View {
        if let status = test.status {
            Text(status).foregroundStyle(.red)
        }
        LabeledContent("Duration", value: Duration.seconds(test.duration).formatted(.time(pattern: .hourMinuteSecond)))
        LabeledContent("Points", value: String(localized: "\(test.points) (\(test.backgroundPoints) in background)"))
        LabeledContent("Seconds per Point", value: test.points > 1
                       ? (test.duration / Double(test.points - 1)).formatted(.number.precision(.fractionLength(1))) : "–")
        LabeledContent("Mean Accuracy", value: test.meanAccuracy.map { RideFormat.ascent(Int($0.rounded())) } ?? "–")
        LabeledContent("Gaps over 10 s", value: String(localized: "\(test.gaps), longest \(Int(test.longestGap)) s"))
        LabeledContent("Standing Still", value: "\(test.stationaryUpdates)")
        LabeledContent("Distance", value: RideFormat.distance(test.distance))
        LabeledContent("Battery", value: batteryText)
    }

    private var batteryText: String {
        guard let start = test.batteryAtStart, let now = test.batteryNow else { return "–" }
        return "\(Int((start * 100).rounded())) % → \(Int((now * 100).rounded())) %"
    }

    private var fileStem: String {
        "GPS-Test " + (test.start ?? .now).formatted(.verbatim("\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))-\(minute: .twoDigits)",
                                                               timeZone: .current, calendar: .current))
    }

    private func saveCSV() {
        do {
            let data = try Data(contentsOf: test.logURL)
            try folder.write(data, to: "iPhone/Test/\(fileStem).csv")
            message = String(localized: "Saved in “iPhone/Test”.")
        } catch {
            message = error.localizedDescription
        }
    }

    /// Straight into the watched folder, so the Mac imports it like any GPX.
    private func saveGPX() {
        guard let data = test.gpx(name: fileStem) else { return }
        do {
            try folder.write(data, to: "\(fileStem).gpx")
            message = String(localized: "Saved in “Wattspur Import”. The Mac imports it.")
        } catch {
            message = error.localizedDescription
        }
    }
}
