import SwiftUI

/// Landscape on the iPhone (B-243): most handlebar mounts for the Bosch Smart System hold the phone
/// sideways. In landscape the tab bar sits at the bottom left in every tab and in the ride detail,
/// so it does not jump when switching; portrait stays as it was. There is no switch in the app:
/// whoever does not want it turns on the orientation lock of iOS.
extension EnvironmentValues {
    /// `true` on an iPhone held sideways: then the height is compact.
    var isLandscape: Bool { verticalSizeClass == .compact }
}

extension View {
    /// Hides the system tab bar in landscape, where `LandscapeTabBar` takes its place. Needed on
    /// every screen of a tab, pushed ones too, because each one decides for itself.
    func hidesTabBarInLandscape() -> some View {
        modifier(HidesTabBarInLandscape())
    }

    /// No title bar on the first screen of a tab, in portrait and landscape (wish of Nils,
    /// 5.11.2026): the tab bar already says where you are, and the content gets the room. Screens
    /// one level down keep a slim bar for the back button. The title stays for VoiceOver and the
    /// back menu.
    func hidesTitleBar() -> some View {
        toolbarVisibility(.hidden, for: .navigationBar)
    }

    /// Room at the bottom of a scroll view in landscape, so its last rows can scroll above the
    /// tab bar at the bottom left.
    func tabBarRoomInLandscape() -> some View {
        modifier(TabBarRoomInLandscape())
    }
}

private struct HidesTabBarInLandscape: ViewModifier {
    @Environment(\.isLandscape) private var isLandscape

    func body(content: Content) -> some View {
        content.toolbarVisibility(isLandscape ? .hidden : .automatic, for: .tabBar)
    }
}

private struct TabBarRoomInLandscape: ViewModifier {
    @Environment(\.isLandscape) private var isLandscape

    func body(content: Content) -> some View {
        content.contentMargins(.bottom, isLandscape ? LandscapeTabBar.height + 12 : 0, for: .scrollContent)
    }
}

/// The tab bar in landscape: a glass capsule at the bottom left with the three tabs. Shows nothing
/// in portrait, where the system tab bar is at the bottom.
struct LandscapeTabBar: View {
    @Binding var tab: WattspurApp.Tab
    @Environment(\.isLandscape) private var isLandscape

    static let height: CGFloat = 52

    var body: some View {
        if isLandscape {
            GlassEffectContainer {
                HStack(spacing: 2) {
                    item(.overview, "Overview", systemImage: "square.grid.2x2")
                    item(.rides, "Rides", systemImage: "list.bullet")
                    item(.map, "Map", systemImage: "map")
                    item(.more, "More", systemImage: "ellipsis")
                }
                .padding(4)
                .frame(height: Self.height)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .padding(.leading, 4)
            .padding(.bottom, 4)
        }
    }

    private func item(_ value: WattspurApp.Tab, _ title: LocalizedStringKey, systemImage: String) -> some View {
        let selected = tab == value
        return Button {
            tab = value
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(title)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(width: 74, height: Self.height - 8)
            .foregroundStyle(selected ? Color.track : Color.primary)
            .background {
                if selected {
                    Capsule().fill(Color.track.opacity(0.14))
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
