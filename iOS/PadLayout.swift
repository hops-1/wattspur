import SwiftUI
import WattspurCore

/// Whether this device records rides. Not the iPad for now (B-292, decision of Nils 18.11.2026):
/// he has no iPad with GPS to test it, so the recording on the iPad comes with B-293.
enum RecordingAvailability {
    @MainActor static var isSupported: Bool { !DeviceText.isPad }
}

/// Texts that name the device (B-328): "this iPad" on the iPad, the iPhone texts as they were.
/// Both keys are written out at the call site, so the String Catalog finds them.
enum DeviceText {
    @MainActor static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @MainActor static func text(_ phone: LocalizedStringKey, pad: LocalizedStringKey) -> Text {
        Text(isPad ? pad : phone)
    }

    @MainActor static func string(_ phone: String.LocalizationValue, pad: String.LocalizationValue) -> String {
        isPad ? String(localized: pad) : String(localized: phone)
    }
}

/// The charts of a ride on the iPad (B-292): stacked to swipe, as on the iPhone, or one below the
/// other, as on the Mac.
enum ChartLayout: String, CaseIterable, Identifiable {
    case stacked, column

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .stacked: "Stacked"
        case .column: "One Below the Other"
        }
    }
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
        if DeviceText.isPad && horizontalSizeClass == .regular {
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
    /// The page of “More” chosen in the sidebar; `nil` is the list of the settings.
    @State private var page: MorePage? = .profile
    /// Only in Debug and TestFlight builds (`BuildChannel`).
    @State private var showsTestTools = BuildChannel.isDebug

    enum Item: Hashable { case overview, rides, map, page(MorePage), settings }

    private var selection: Binding<Item?> {
        Binding {
            switch tab {
            case .overview: .overview
            case .rides: .rides
            case .map: .map
            case .more: page.map(Item.page) ?? .settings
            }
        } set: { item in
            switch item {
            case .overview: tab = .overview
            case .rides: tab = .rides
            case .map: tab = .map
            case .page(let chosen):
                page = chosen
                tab = .more
            case .settings:
                page = nil
                tab = .more
            case nil: break
            }
        }
    }

    /// The sidebar with names, or only the symbols (wish of Nils, like the Mac's narrow sidebar);
    /// kept for the next start.
    @AppStorage(PhoneSettingsKey.padSidebarExpanded) private var expanded = true

    var body: some View {
        // Not `NavigationSplitView`: its sidebar hides completely; this one folds to the symbols.
        HStack(spacing: 0) {
            PadSidebar(selection: selection, expanded: $expanded)
            Divider().ignoresSafeArea()
            NavigationStack {
                detail
            }
            // A new section starts at its first screen, as a new tab does.
            .id(selection.wrappedValue)
        }
        .environment(\.isPadLayout, true)
        .task { showsTestTools = await BuildChannel.showsTestTools() }
        .onChange(of: showsTestTools) { if !showsTestTools && page == .testTools { page = nil } }
    }

    /// The settings, a second level (wish of Nils): the pages of “More” but the profile, which has
    /// its own row, and the trash, which sits with the rides.
    private var settingsGroups: [[MorePage]] {
        MorePage.groups(showsTestTools: showsTestTools).map { $0.filter { $0 != .trash } }.filter { !$0.isEmpty }
    }

    @ViewBuilder private var detail: some View {
        switch tab {
        case .overview:
            OverviewView { period in
                rideFilter = RideFilter(period: period)
                tab = .rides
            }
        case .rides:
            RidesView(filter: $rideFilter, openedRideID: $openedRideID)
                .hidesTitleBar()
        case .map:
            RidesMapScreen()
                .hidesTitleBar()
        case .more:
            if let page {
                MorePageView(page: page)
                    .navigationTitle(page.title)
            } else {
                settingsList
            }
        }
    }

    private var settingsList: some View {
        List {
            ForEach(settingsGroups, id: \.self) { group in
                Section {
                    ForEach(group) { page in
                        NavigationLink(value: page) { MoreRow(page: page) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationDestination(for: MorePage.self) { page in
            MorePageView(page: page)
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The sidebar of the iPad (B-292): one style for every row, symbol and name, no values; in two
/// groups, the sport switch above. Folded, only the symbols stand one below the other.
private struct PadSidebar: View {
    @Binding var selection: PadRootView.Item?
    @Binding var expanded: Bool

    static let wideWidth: CGFloat = 280
    static let narrowWidth: CGFloat = 68

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if expanded {
                    Text(verbatim: "Wattspur").font(.headline)
                    Spacer(minLength: 0)
                }
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(expanded ? Text("Show Only Symbols") : Text("Show Names"))
            }
            .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
            .padding(.horizontal, expanded ? 16 : 0)
            .padding(.vertical, 8)
            SportSwitch(compact: !expanded)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, expanded ? 16 : 0)
                .padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    header("Media Library")
                    row(.overview, "Overview", "square.grid.2x2")
                    row(.rides, "Rides", "list.bullet")
                    row(.map, "Map", "map")
                    row(.page(.trash), MorePage.trash.title, MorePage.trash.systemImage)
                    header(nil)
                    row(.page(.profile), MorePage.profile.title, MorePage.profile.systemImage)
                    row(.settings, "Settings", "gearshape")
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: expanded ? Self.wideWidth : Self.narrowWidth)
        .background(Color(.secondarySystemBackground).ignoresSafeArea())
    }

    @ViewBuilder private func header(_ title: LocalizedStringKey?) -> some View {
        if expanded, let title {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 4)
        } else if expanded {
            Spacer().frame(height: 20)
        } else {
            Divider().padding(.vertical, 10)
        }
    }

    private func row(_ item: PadRootView.Item, _ title: LocalizedStringKey, _ symbol: String) -> some View {
        let selected = selection == item
        return Button {
            selection = item
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(Color.track)
                    .frame(width: 28)
                if expanded {
                    Text(title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, expanded ? 12 : 0)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: expanded ? .leading : .center)
            .background(selected ? Color(.systemFill) : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Folded, the name is still there for VoiceOver and as a tooltip with a pointer.
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(Text(title))
    }
}
