import StoreKit
import SwiftUI
import WattspurCore
import WattspurKit
import WattspurMap

/// The tab “More” (B-298): a list of sections like the iOS Settings, each opening a page of its own,
/// instead of one long form. The profile sits at the top. In landscape the list is on the left and
/// the chosen page on the right, like the rides (B-243). Every setting keeps its key.
struct MoreView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.isLandscape) private var isLandscape
    /// The page beside the list in landscape; the profile until another one is tapped.
    @State private var selection: MorePage = .profile
    /// Only in Debug and TestFlight builds (`BuildChannel`).
    @State private var showsTestTools = BuildChannel.isDebug

    var body: some View {
        Group {
            if isLandscape {
                split
            } else {
                list
            }
        }
        .navigationTitle("More")
        .task { showsTestTools = await BuildChannel.showsTestTools() }
    }

    private var pages: [[MorePage]] {
        var groups: [[MorePage]] = [[.recording, .maps], [.library, .trash], [.help, .about]]
        if showsTestTools { groups.append([.testTools]) }
        return groups
    }

    // MARK: - Portrait

    private var list: some View {
        List {
            Section {
                NavigationLink(value: MorePage.profile) { ProfileHeader() }
            }
            ForEach(pages, id: \.self) { group in
                Section {
                    ForEach(group) { page in
                        NavigationLink(value: page) { MoreRow(page: page) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: MorePage.self) { page in
            MorePageView(page: page)
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .hidesTabBarInLandscape()
        }
    }

    // MARK: - Landscape

    private var split: some View {
        HStack(spacing: 0) {
            List {
                Section {
                    row(.profile) { ProfileHeader() }
                }
                ForEach(pages, id: \.self) { group in
                    Section {
                        ForEach(group) { page in
                            row(page) { MoreRow(page: page) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .tabBarRoomInLandscape()
            .frame(width: 320)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text(selection.title)
                    .font(.title2.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                MorePageView(page: selection, embedded: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemGroupedBackground))
            .id(selection)
        }
        // A page that is gone (test tools in a build without them) falls back to the profile.
        .onChange(of: showsTestTools) { if !showsTestTools && selection == .testTools { selection = .profile } }
    }

    private func row(_ page: MorePage, @ViewBuilder label: () -> some View) -> some View {
        Button {
            selection = page
        } label: {
            label()
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(page == selection ? Color.track.opacity(0.14) : nil)
        .accessibilityAddTraits(page == selection ? .isSelected : [])
    }
}

/// The pages of “More”, in the order of the list.
enum MorePage: String, Hashable, CaseIterable, Identifiable {
    case profile, recording, maps, library, trash, help, about, testTools

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .profile: "Profile"
        case .recording: "Recording"
        case .maps: "Maps"
        case .library: "iCloud & Library"
        case .trash: "Trash"
        case .help: "Help & Handbook"
        case .about: "About Wattspur"
        case .testTools: "Test Tools"
        }
    }

    var systemImage: String {
        switch self {
        case .profile: "person.crop.circle"
        case .recording: "record.circle"
        case .maps: "map"
        case .library: "icloud"
        case .trash: "trash"
        case .help: "book"
        case .about: "info.circle"
        case .testTools: "hammer"
        }
    }

    /// The colour of the small square behind the symbol, as in the iOS Settings.
    var tint: Color {
        switch self {
        case .profile: .track
        case .recording: .red
        case .maps: .green
        case .library: .blue
        case .trash: .gray
        case .help: .orange
        case .about: .gray
        case .testTools: .purple
        }
    }
}

/// One row of the list: the symbol in a coloured square, the title and what is set now.
private struct MoreRow: View {
    let page: MorePage
    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneSync.self) private var sync
    @AppStorage(Recorder.vehicleKey) private var vehicle = RecordingVehicle.eBike
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard

    var body: some View {
        LabeledContent {
            value
        } label: {
            Label {
                Text(page.title)
            } icon: {
                Image(systemName: page.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(page.tint.gradient, in: .rect(cornerRadius: 7))
            }
        }
    }

    private var value: Text? {
        switch page {
        case .recording: Text(vehicle.label)
        case .maps: Text(mapType.label)
        case .library: library.mode == .iCloud ? Text("iCloud") : Text("This iPhone")
        case .trash: library.trash.isEmpty ? nil : Text(library.trash.count.formatted())
        default: nil
        }
    }
}

/// The head of the list: photo, name and how much was ridden; opens the profile (B-299 makes it editable).
private struct ProfileHeader: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        HStack(spacing: 14) {
            RiderAvatar(rider: library.rider, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.title3.weight(.semibold))
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var name: String {
        let name = library.rider?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "Profile") : name
    }

    /// For example “84 rides · 1,520 km”.
    private var summary: String {
        let rides = library.state?.rides ?? []
        let distance = rides.reduce(0) { $0 + $1.distance }
        return String(localized: "\(rides.count) rides · \(RideFormat.distance(distance))")
    }
}

/// The rider's photo in a circle, or the first letter of the name, or a person symbol.
struct RiderAvatar: View {
    let rider: RiderDetails?
    let size: CGFloat

    var body: some View {
        Group {
            if let data = rider?.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initial = rider?.initial {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.track.gradient)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Whether the test tools show (B-298): in Debug builds and on TestFlight, not from the App Store.
enum BuildChannel {
    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func showsTestTools() async -> Bool {
        if isDebug { return true }
        // TestFlight builds run in the sandbox environment; the App Store in production.
        guard let transaction = try? await AppTransaction.shared else { return false }
        return transaction.unsafePayloadValue.environment != .production
    }
}
