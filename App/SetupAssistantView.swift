import SwiftData
import SwiftUI
import WattspurKit

/// Setup assistant on first launch (B-027, ONB-01): profile name, import folder
/// and how to export from the Flow app. Can be shown again from Settings.
struct SetupAssistantView: View {
    @Environment(FolderWatcher.self) private var watcher
    @Environment(\.modelContext) private var modelContext
    @Environment(RideLibrary.self) private var sharedLibrary
    @Environment(\.dismiss) private var dismiss
    @AppStorage("setupCompleted") private var setupCompleted = false

    @State private var step = 1
    @State private var name = ""
    @State private var folderChoice: FolderChoice = .iCloud
    @State private var loadSample = false
    @State private var bodyExpanded = true
    /// The first bike and the body data (B-138); filled from what is stored, so running
    /// the assistant again shows the current values.
    @State private var bikeName = ""
    @State private var bikeColor: BikeColor = .blue
    @State private var weight: Double?
    @State private var height: Double?
    @State private var birthYear: Int?
    @State private var sex: RiderSex = .unspecified
    @AppStorage("bikesHintDone") private var bikesHintDone = false

    private enum FolderChoice: Hashable { case iCloud, other, none }
    private static let stepCount = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(1...Self.stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: index == step ? 22 : 6, height: 6)
                }
                Spacer()
                Text("Step \(step) of \(Self.stepCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Step \(step) of \(Self.stepCount)"))
            .padding([.horizontal, .top], 28)

            Group {
                switch step {
                case 1: welcome
                case 2: firstBike
                case 3: folder
                case 4: exportGuide
                default: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 40)
            .padding(.top, 24)

            Divider()
            HStack {
                if step < Self.stepCount {
                    Button("Skip") { finish() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if step > 1 {
                    Button("Back") { withAnimation(.snappy) { step -= 1 } }
                }
                if step < Self.stepCount {
                    Button("Continue") { next() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") { finish() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .frame(height: 64)
        }
        .frame(width: 600, height: 620)
        .onAppear {
            let library = sharedLibrary
            let rider = library.defaultRider()
            name = rider.name
            let bike = library.activeBike()
            bikeName = bike.name
            bikeColor = bike.color
            weight = rider.weightKg
            height = rider.heightCm
            birthYear = rider.birthYear
            sex = rider.sex
            if watcher.hasFolder { folderChoice = .other }
        }
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Image(systemName: "bicycle")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Wattspur").font(.largeTitle.bold())
            Text("Wattspur analyses the rides you export from the Bosch eBike Flow app – locally on your Mac, without an account or subscription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440)
            VStack(alignment: .leading, spacing: 6) {
                Text("What’s your name?").font(.headline)
                TextField("Your name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(next)
                Text("For your local profile. Stays on this Mac and can be changed later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 320)
            .padding(.top, 14)
        }
    }

    /// Step 2: name and color of the first bike; body data may be skipped (B-138).
    private var firstBike: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                BikeChip(kind: .bike, color: bikeColor, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your first bike").font(.title2.bold())
                    Text("Give your eBike a name and a color. You can add more bikes later in Profile.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            LabeledField("Bike name") {
                TextField("Bike name", text: $bikeName, prompt: Text(verbatim: RideLibrary.defaultBikeName))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }
            BikeColorPicker(selection: $bikeColor)
            DisclosureGroup(isExpanded: $bodyExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("For a “with profile” calorie estimate in a later version. You can skip this and add it later in Profile; the data stays on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .bottom, spacing: 18) {
                        LabeledField("Weight") {
                            HStack(spacing: 6) {
                                NumberField("Weight", value: $weight, range: ProfileInput.weightKg, width: 70, prompt: "kg")
                                Text("kg")
                            }
                        }
                        LabeledField("Height") {
                            HStack(spacing: 6) {
                                NumberField("Height", value: $height, range: ProfileInput.heightCm, width: 70, prompt: "cm")
                                Text("cm")
                            }
                        }
                        LabeledField("Birth year") {
                            TextField("Birth year", value: $birthYear, format: .number.grouping(.never), prompt: Text("Year"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .labelsHidden()
                                .monospacedDigit()
                        }
                    }
                    Picker("Sex", selection: $sex) {
                        ForEach([RiderSex.unspecified, .female, .male]) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 6) {
                    Text("Body data").fontWeight(.semibold)
                    Text("optional").foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var folder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where do new rides go?").font(.title2.bold())
            Text("Wattspur can watch a folder and import new exports automatically. With iCloud Drive this works straight from your iPhone.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Import folder", selection: $folderChoice) {
                option("iCloud Drive › Wattspur Import (recommended)",
                       detail: "You confirm the place once; Wattspur creates the folder if it is missing.")
                    .tag(FolderChoice.iCloud)
                option("Choose Another Folder…", detail: "For example a folder on this Mac or in another cloud service.")
                    .tag(FolderChoice.other)
                option("No folder – I’ll drop files on the window myself", detail: "You can change this any time in Settings › Import.")
                    .tag(FolderChoice.none)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if let path = watcher.displayPath, folderChoice != .none {
                Label { Text(verbatim: path) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    .font(.callout)
            }
        }
    }

    private func option(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var exportGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to export from the Flow app").font(.title2.bold())
            Text("Once per ride on your iPhone – Wattspur takes care of the rest.")
                .foregroundStyle(.secondary)
            ExportStep(number: 1, title: "Open the ride in the Flow app", detail: "Tap “Statistics” at the bottom and pick the ride.")
            ExportStep(number: 2, title: "Menu at the top right › “Download FIT”", detail: "FIT contains power, cadence and all totals.")
            ExportStep(number: 3, title: "“Save to Files”", detail: "In the menu that opens next.")
            ExportStep(number: 4, title: "Choose iCloud Drive › Wattspur Import", detail: "Next time you look at Wattspur, the ride is there.")
            Text("Use “Download FIT”: it has power and cadence, the GPX only the route. GPX files from other bikes and bike computers are imported as well.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var done: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("All set").font(.largeTitle.bold())
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Profile").foregroundStyle(.secondary)
                    Text(verbatim: name.nonEmpty ?? String(localized: "No name yet"))
                }
                GridRow {
                    Text("Bike").foregroundStyle(.secondary)
                    Text(verbatim: bikeName.nonEmpty ?? RideLibrary.defaultBikeName)
                }
                GridRow {
                    Text("Import folder").foregroundStyle(.secondary)
                    if folderChoice == .none || !watcher.hasFolder {
                        Text("No folder – drag & drop only")
                    } else {
                        Text(verbatim: watcher.displayPath ?? "")
                    }
                }
            }
            .padding(14)
            .frame(width: 420, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            Toggle(isOn: $loadSample) {
                Text("Load a sample ride")
                Text("An anonymized ride to try things out. It does not count in the analysis and can be removed with one click.")
            }
            .toggleStyle(.checkbox)
            .frame(width: 420, alignment: .leading)
            Text("Settings (⌘,) let you change all of this later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func next() {
        switch step {
        case 1:
            saveName()
        case 2:
            saveBike()
        case 3:
            switch folderChoice {
            case .iCloud:
                watcher.chooseFolder(startingAt: FolderWatcher.iCloudDriveURL, createImportFolder: true)
                guard watcher.hasFolder else { return } // cancelled: stay on this step
            case .other:
                if !watcher.hasFolder { watcher.chooseFolder() }
                guard watcher.hasFolder else { return }
            case .none:
                watcher.isEnabled = false
            }
        default:
            break
        }
        withAnimation(.snappy) { step = min(step + 1, Self.stepCount) }
    }

    private func saveName() {
        let library = sharedLibrary
        let rider = library.defaultRider()
        if let trimmed = name.nonEmpty {
            rider.name = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        try? modelContext.save()
    }

    /// The first bike and the body data go to the library when the step is left.
    private func saveBike() {
        let library = sharedLibrary
        library.configureActiveBike(name: bikeName, color: bikeColor)
        library.setBodyData(weightKg: weight, heightCm: height, birthYear: birthYear, sex: sex)
    }

    private func finish() {
        saveName()
        saveBike()
        // The hint "Set up your bikes" is for libraries from before 1.5; this one has just done it.
        bikesHintDone = true
        if loadSample { SampleRide.load(into: sharedLibrary) }
        setupCompleted = true
        dismiss()
    }
}

private struct ExportStep: View {
    let number: Int
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: "\(number)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
