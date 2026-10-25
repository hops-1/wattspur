import SwiftUI
import WattspurKit

/// "About Wattspur" with the required notices: version, copyright, licence,
/// trademark and privacy statement, estimate notice and credits.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(verbatim: "Wattspur").font(.title.bold())
                Text("Ride analysis for exports from the Bosch eBike Flow app")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Version \(AppInfo.fullVersion)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 10) {
                Notice(systemImage: "lock.shield",
                       text: "Your rides stay on this Mac. Wattspur sends no data about you or your rides. The map loads map tiles and place information from Apple, and Wattspur asks GitHub once a day whether a new version is out (switch off in Settings).")
                Notice(systemImage: "function",
                       text: "Calories and CO₂ savings are estimates based on your pedal power and distance.")
                Notice(systemImage: "info.circle",
                       text: "Wattspur is not a product of Robert Bosch GmbH and is not affiliated with it. Bosch and eBike Flow are trademarks of their respective owners.")
                Notice(systemImage: "map",
                       text: "Maps: Apple Maps. Reads files in the FIT (Garmin) and GPX formats.")
            }
            .frame(maxWidth: 420, alignment: .leading)

            VStack(spacing: 2) {
                Text(verbatim: AppInfo.copyright)
                Text("Open source under the MIT License")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Notice: View {
    let systemImage: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

#Preview {
    AboutView()
}
