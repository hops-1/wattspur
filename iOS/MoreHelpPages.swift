import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurSymbols
import WattspurKit
import WattspurMap

// MARK: - Help & Handbook

/// Links to the handbook online, in the language of the app (as in the Mac's Help menu).
struct HelpPage: View {
    var body: some View {
        Form {
            Section {
                Link(destination: HelpLinks.url(.iPhone)) {
                    Label { DeviceText.text("Wattspur on the iPhone", pad: "Wattspur on the iPad") } icon: { Image(systemName: DeviceText.isPad ? "ipad" : "iphone") }
                }
                Link(destination: HelpLinks.url(.handbook)) {
                    Label("Handbook", systemImage: "book")
                }
                Link(destination: HelpLinks.url(.faq)) {
                    Label("Questions and Answers", systemImage: "questionmark.circle")
                }
            } footer: {
                Text("The handbook is online, so it can get better between versions.")
            }
            Section {
                Link(destination: HelpLinks.releases) {
                    Label("What's New", systemImage: "sparkles")
                }
            }
        }
    }
}

// MARK: - About

/// The version, where the maps come from, the privacy policy and the project page.
struct AboutPage: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text("\(AppInfo.version) (\(AppInfo.build))")
                        .textSelection(.enabled)
                }
                LabeledContent("Commit") {
                    Text(AppInfo.commit)
                        .textSelection(.enabled)
                }
            }
            Section {
                LabeledContent("Apple") { Text("Standard, Satellite, Hybrid") }
                ForEach(TileSource.all) { source in
                    Link(destination: source.attributionURL) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                                .foregroundStyle(.primary)
                            Text(source.attribution)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Map Sources")
            } footer: {
                Text("Apple shows its credit on the map itself.")
            }
            Section {
                Link(destination: HelpLinks.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                // B-362: only the project page, no donation link (App Review 3.1.1).
                Link(destination: HelpLinks.project) {
                    Label("Wattspur on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } footer: {
                Text("Wattspur has no server and no account. Your rides stay on your devices and in your own iCloud.")
            }
        }
    }
}

// MARK: - Test tools

/// Only in Debug and TestFlight builds (`BuildChannel`).
struct TestToolsPage: View {
    @AppStorage(MotionRecorder.rawLogKey) private var recordsRawMotion = false

    var body: some View {
        Form {
            // Spike V-16; goes again once acceleration and lean angle are part of the recording.
            Section {
                Toggle("Record Raw Motion", isOn: $recordsRawMotion)
            } footer: {
                DeviceText.text("For a test of acceleration and lean angle: each recording also writes the motion sensors and GPS into a file. You find it in the Files app under “On My iPhone › Wattspur › Bewegung”. About 20 MB per hour.", pad: "For a test of acceleration and lean angle: each recording also writes the motion sensors and GPS into a file. You find it in the Files app under “On My iPad › Wattspur › Bewegung”. About 20 MB per hour.")
            }
        }
    }
}
