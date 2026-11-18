import SwiftUI
import WattspurCore

/// Whether this device records rides. Not the iPad for now (B-292, decision of Nils 18.11.2026):
/// he has no iPad with GPS to test it, so the recording on the iPad comes with B-293.
enum RecordingAvailability {
    @MainActor static var isSupported: Bool { UIDevice.current.userInterfaceIdiom != .pad }
}

extension EnvironmentValues {
    /// `true` inside the sidebar layout of the iPad (B-292): the screens show the ride beside the
    /// list, the charts one below the other, and leave the sport switch to the sidebar.
    @Entry var isPadLayout = false
}

/// The tabs, or on an iPad in the regular width the sidebar (B-292, `DESIGN-IPAD.md`). An iPad in a
/// narrow Split View or Slide Over window gets the tabs of the iPhone.
struct RootLayout<Tabs: View, Pad: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var tabs: () -> Tabs
    @ViewBuilder var pad: () -> Pad

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
            pad()
        } else {
            tabs()
        }
    }
}

/// The iPad in the regular width (B-292): a sidebar like on the Mac, with the sport switch at the
/// top, then Overview, Rides and Map, below them the pages of “More”. The screens are the ones of
/// the iPhone; only their arrangement is new.
struct PadRootView: View {
    /// The tab of the iPhone layout, kept by the app: Siri and the overview's tiles set it.
    @Binding var tab: WattspurApp.Tab
    @Binding var rideFilter: RideFilter
    @Binding var openedRideID: UUID?
    /// The page of “More” chosen in the sidebar.
    @State private var page: MorePage = .profile
    /// Only in Debug and TestFlight builds (`BuildChannel`).
    @State private var showsTestTools = BuildChannel.isDebug

    enum Item: Hashable { case overview, rides, map, page(MorePage) }

    private var selection: Binding<Item?> {
        Binding {
            switch tab {
            case .overview: .overview
            case .rides: .rides
            case .map: .map
            case .more: .page(page)
            }
        } set: { item in
            switch item {
            case .overview: tab = .overview
            case .rides: tab = .rides
            case .map: tab = .map
            case .page(let chosen):
                page = chosen
                tab = .more
            case nil: break
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // One style for every row, like the Mac's sidebar: symbol and name, no values (wish of Nils).
            List(selection: selection) {
                Section("Media Library") {
                    Label("Overview", systemImage: "square.grid.2x2").tag(Item.overview)
                    Label("Rides", systemImage: "list.bullet").tag(Item.rides)
                    Label("Map", systemImage: "map").tag(Item.map)
                    label(.trash)
                }
                Section("Settings") {
                    ForEach(settingsPages) { label($0) }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                SportSwitch()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .navigationTitle("Wattspur")
        } detail: {
            NavigationStack {
                detail
            }
            // A new section starts at its first screen, as a new tab does.
            .id(selection.wrappedValue)
        }
        .environment(\.isPadLayout, true)
        .task { showsTestTools = await BuildChannel.showsTestTools() }
        .onChange(of: showsTestTools) { if !showsTestTools && page == .testTools { page = .profile } }
    }

    /// Profile, then the pages of “More” but the trash, which sits with the rides.
    private var settingsPages: [MorePage] {
        [.profile] + MorePage.groups(showsTestTools: showsTestTools).joined().filter { $0 != .trash }
    }

    private func label(_ page: MorePage) -> some View {
        Label(page.title, systemImage: page.systemImage).tag(Item.page(page))
    }

    @ViewBuilder private var detail: some View {
        switch tab {
        case .overview:
            OverviewView { period in
                rideFilter = RideFilter(period: period)
                tab = .rides
            }
        // A slim title bar stays on every screen: it holds the button that brings the sidebar back.
        case .rides:
            RidesView(filter: $rideFilter, openedRideID: $openedRideID)
                .navigationBarTitleDisplayMode(.inline)
        case .map:
            RidesMapScreen()
                .navigationBarTitleDisplayMode(.inline)
        case .more:
            MorePageView(page: page)
                .navigationTitle(page.title)
        }
    }
}
