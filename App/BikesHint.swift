import SwiftUI
import WattspurKit

/// The one-time note after the update to 1.5 (B-138): rides now belong to bikes. It
/// sits at the top of the window instead of blocking it with a dialog, and is gone for
/// good after "Later", "Go to Profile" or a visit to the profile.
struct BikesHintBanner: View {
    let bikeName: String
    let onProfile: () -> Void
    let onLater: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bicycle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("New in 1.5: Set up your bikes").font(.headline)
                Text("Wattspur now analyses several eBikes separately. All your earlier rides belong to “\(bikeName)” – rename it and add more bikes in Profile.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Go to Profile", action: onProfile)
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
        .accessibilityLabel(Text("New in 1.5: Set up your bikes"))
    }
}
