import AppKit
import SwiftData
import SwiftUI
import WattspurKit

/// Settings window (⌘,): general settings and the watched folder (B-042: SET-01, SET-02, SET-07).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Import", systemImage: "square.and.arrow.down") {
                ImportSettingsView()
            }
            Tab("Calculation", systemImage: "function") {
                if CalorieMode.withProfileAvailable {
                    CalorieSettingsView()
                } else {
                    ContentUnavailableView("Coming in a Later Version", systemImage: "function",
                                           description: Text("Factors for calories and CO₂ will be adjustable here."))
                }
            }
        }
        .frame(width: 620)
        .scenePadding()
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.mapType) private var mapType: RideMapType = .standard
    @AppStorage(SettingsKey.setupCompleted) private var setupCompleted = false
    @AppStorage(SettingsKey.updateCheckEnabled) private var updateCheckEnabled = true
    @Query private var riders: [Rider]
    @Query(filter: #Predicate<Ride> { $0.isSample }) private var samples: [Ride]
    @Environment(RideLibrary.self) private var sharedLibrary

    var body: some View {
        Form {
            LabeledContent("Language:") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "")
                    Text("Wattspur follows the macOS language. To use a different language for Wattspur only, go to System Settings › General › Language & Region › Applications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open System Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            Picker("Default map type:", selection: $mapType) {
                ForEach(RideMapType.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            LabeledContent("Profile:") {
                HStack {
                    Text(verbatim: riders.first?.name.nonEmpty ?? String(localized: "No name yet"))
                    Button("Edit Profile…") { NotificationCenter.default.post(name: .showProfile, object: nil) }
                }
            }
            LabeledContent("Setup:") {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Show Setup Assistant…") { setupCompleted = false }
                    Text("Go through profile, import folder and the export guide again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Updates:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Check for new versions", isOn: $updateCheckEnabled)
                    Text("Once a day Wattspur asks GitHub whether a newer version is out and shows a note. Nothing about you or your rides is sent. “Check for Updates…” in the Wattspur menu always works.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent("Sample ride:") {
                VStack(alignment: .leading, spacing: 4) {
                    if samples.isEmpty {
                        Button("Load Sample Ride") { SampleRide.load(into: sharedLibrary) }
                    } else {
                        Button("Remove Sample Ride") { SampleRide.remove(from: sharedLibrary) }
                    }
                    Text("An anonymized ride to try things out. It does not count in the analysis and can be removed with one click.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.columns)
        .padding(.vertical, 8)
    }
}

struct ImportSettingsView: View {
    @Environment(FolderWatcher.self) private var watcher
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.mergeSuggestionGapMinutes) private var mergeGapMinutes = RideMergeSuggestion.defaultGapMinutes

    var body: some View {
        @Bindable var watcher = watcher
        Form {
            LabeledContent("Watch folder:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $watcher.isEnabled) { EmptyView() }
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!watcher.hasFolder)
                    FolderStatusText()
                }
            }
            LabeledContent("Folder:") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder").foregroundStyle(Color.accentColor)
                        Text(verbatim: watcher.displayPath ?? String(localized: "No folder chosen"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    HStack {
                        Button(watcher.hasFolder ? "Change…" : "Choose Folder…") { watcher.chooseFolder() }
                        Button("Show in Finder") { watcher.showInFinder() }
                            .disabled(watcher.folderURL == nil)
                    }
                    Text("Imported files move to the subfolder “\(String(localized: "folder.imported", defaultValue: "Imported"))”, files that cannot be read to “\(String(localized: "folder.failed", defaultValue: "Failed"))”. Deleted rides are therefore not imported again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent("When:") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("At launch and whenever new files appear")
                    Text("Only works while Wattspur is open.").font(.caption).foregroundStyle(.secondary)
                }
            }
            LabeledContent("Duplicates:") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skip and note in the import log")
                    Text("When you drop files on the window, Wattspur asks instead.").font(.caption).foregroundStyle(.secondary)
                }
            }
            LabeledContent("Other files:") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leave in place")
                    Text("Only FIT and GPX files are imported. Other types are noted once in the log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledContent("Merging:") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Suggest merging", selection: $mergeGapMinutes) {
                        Text("Off").tag(0)
                        ForEach([15, 30, 60, 120], id: \.self) { Text("Gap up to \($0) min").tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Text("After an import, Wattspur points out rides on the same day that probably belong together: the second starts soon after the first ended and close to where it ended. Nothing is merged without your confirmation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("Import Log…") { openWindow(id: "importLog") }
                Button("Check Now") { watcher.checkNow() }
                    .disabled(!watcher.isEnabled || watcher.folderURL == nil)
                    .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.columns)
        .padding(.vertical, 8)
    }
}

/// "Active · last checked 2 min ago · 3 rides imported today", or what is wrong.
struct FolderStatusText: View {
    @Environment(FolderWatcher.self) private var watcher
    @Query private var records: [ImportRecord]

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let folder = ImportSource.folder.rawValue
        let imported = ImportRecordOutcome.imported.rawValue
        _records = Query(filter: #Predicate<ImportRecord> {
            $0.date >= start && $0.sourceRaw == folder && $0.outcomeRaw == imported
        })
    }

    var body: some View {
        Group {
            if let problem = watcher.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            } else if !watcher.hasFolder {
                Text("Choose a folder first.")
            } else if !watcher.isEnabled {
                Text("Off – import by drag & drop or “Import…” only")
            } else if let checked = watcher.lastChecked {
                Text("Active · last checked \(checked, format: .relative(presentation: .named)) · \(records.count) rides imported today")
            } else {
                Text("Active")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension String {
    /// `nil` for an empty or blank string.
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
