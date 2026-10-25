import SwiftData
import SwiftUI
import WattspurKit

/// The anonymized sample ride that ships with the app (ONB-02, V-05).
/// `App/SampleRide.fit` is made with `swift run anonymize-fit` in WattspurKit.
@MainActor
enum SampleRide {
    @discardableResult
    static func load(into library: RideLibrary) -> Ride? {
        guard let url = Bundle.main.url(forResource: "SampleRide", withExtension: "fit"),
              let data = try? Data(contentsOf: url) else { return nil }
        return library.importSample(data: data, name: String(localized: "Sample Ride"))
    }

    static func remove(from library: RideLibrary) {
        library.removeSamples()
    }
}

/// Shown above the detail of the sample ride, with the button that removes it.
struct SampleRideBanner: View {
    @Environment(RideLibrary.self) private var sharedLibrary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("This is a sample ride").font(.callout.weight(.semibold))
                Text("It is anonymized and does not count in the analysis or totals. Once you have imported your own rides, you can remove it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button("Remove Sample Ride") { SampleRide.remove(from: sharedLibrary) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}

/// The "Sample" tag in the ride list.
struct SampleBadge: View {
    var body: some View {
        Text("Sample")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary, lineWidth: 1))
            .foregroundStyle(.secondary)
    }
}
