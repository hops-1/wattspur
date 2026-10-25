import SwiftUI
import WattspurKit

/// "Wattspur 1.6.2 is available" at the top of the window (B-172), in the style of the other
/// notes. "Later" keeps it away until a still newer version comes out.
struct UpdateBanner: View {
    let release: ReleaseInfo
    let onView: () -> Void
    let onLater: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Wattspur \(release.version.description) is available").font(.headline)
                Text("You have version \(AppInfo.version). Download the new one from GitHub and replace the app in Applications; your rides stay as they are.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("View on GitHub", action: onView)
                .buttonStyle(.borderedProminent)
            Button("Later", action: onLater)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: 760)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(0.5)))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Wattspur \(release.version.description) is available"))
    }
}
