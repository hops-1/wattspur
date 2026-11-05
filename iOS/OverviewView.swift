import SwiftUI
import WattspurCore

/// The tab “Overview” of design C (B-214): the totals of this week and this month, the last ride
/// with a small map, and a way to all rides. The figures come from the Mac; until there is a
/// state, the sample ride shows what the tiles will look like.
struct OverviewView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(Recorder.self) private var recorder
    @Environment(PhoneRecordings.self) private var recordings
    @Environment(ImportFolder.self) private var folder
    /// Switches to the tab “Rides”.
    var showAllRides: () -> Void
    @State private var sample = SampleRide.load()
    @Environment(\.isLandscape) private var isLandscape

    var body: some View {
        Group {
            if isLandscape { landscape } else { portrait }
        }
        .refreshable {
            await library.refresh()
            await recordings.refreshStatuses(state: library.state, folder: folder)
        }
        .navigationTitle("Overview")
    }

    private var portrait: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let state = library.state, let last = state.lastRide {
                    tiles(totals: totals(state))
                    NavigationLink {
                        TourDetailView(ride: last)
                    } label: {
                        LastRideTile(ride: last)
                    }
                    .buttonStyle(.plain)
                    StartRideButton { recorder.start() }
                    RecordingsSection()
                    Button(action: showAllRides) {
                        HStack {
                            Text("All Rides")
                            Spacer()
                            Text("\(state.rides.count)").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding()
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                    StateLine()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let sample {
                    // The sample ride is old: the totals are counted for its week and month, so
                    // the tiles show what they will look like.
                    tiles(totals: RidePeriodTotals(rides: [(start: sample.ride.startDate, distance: sample.ride.distance)],
                                                   now: sample.ride.startDate))
                    NavigationLink {
                        TourDetailView(ride: sample.ride, route: sample.route)
                    } label: {
                        LastRideTile(ride: sample.ride, route: sample.route)
                    }
                    .buttonStyle(.plain)
                    StartRideButton { recorder.start() }
                    RecordingsSection()
                    Text("Sample data: the tiles count the sample ride's week and month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if library.usesDatabase {
                        FirstRidePrompt()
                    } else if library.status == .noFolder {
                        ChooseFolderPrompt()
                    } else {
                        MacSettingPrompt()
                    }
                }
            }
            .padding()
        }
    }

    /// Landscape (B-243): the last ride larger on the left, the week, month, year and all rides
    /// on the right, “Start Ride” at the bottom right, clear of the tab bar at the bottom left.
    private var landscape: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    if let state = library.state, let last = state.lastRide {
                        NavigationLink {
                            TourDetailView(ride: last)
                        } label: {
                            LastRideTile(ride: last, mapHeight: 100)
                        }
                        .buttonStyle(.plain)
                    } else if let sample {
                        NavigationLink {
                            TourDetailView(ride: sample.ride, route: sample.route)
                        } label: {
                            LastRideTile(ride: sample.ride, route: sample.route, mapHeight: 100)
                        }
                        .buttonStyle(.plain)
                    }
                    RecordingsSection()
                }
                .frame(width: 340)
                VStack(spacing: 16) {
                    if let state = library.state, state.lastRide != nil {
                        landscapeTiles(totals: totals(state), allRides: state.rides.count + recordings.waiting.count)
                        StateLine()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let sample {
                        landscapeTiles(totals: RidePeriodTotals(rides: [(start: sample.ride.startDate, distance: sample.ride.distance)],
                                                                now: sample.ride.startDate),
                                       allRides: 1)
                        Text("Sample data: the tiles count the sample ride's week and month.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if library.usesDatabase {
                            FirstRidePrompt()
                        } else if library.status == .noFolder {
                            ChooseFolderPrompt()
                        } else {
                            MacSettingPrompt()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        // Room for “Start Ride” and the tab bar below the last tiles.
        .contentMargins(.bottom, LandscapeTabBar.height + 12, for: .scrollContent)
        .overlay(alignment: .bottomTrailing) {
            StartRideButton { recorder.start() }
                .frame(width: 230)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
        }
    }

    /// The Mac's rides plus the recordings it does not have yet (B-214).
    private func totals(_ state: RideExchange.Library) -> RidePeriodTotals {
        // Motorcycle rides stay out of the totals, like on the Mac.
        let rides = state.countedRides.map { (start: $0.startDate, distance: $0.distance) }
            + recordings.waiting.filter { !state.isMotorized(bikeID: $0.bikeID) }.map { (start: $0.startDate, distance: $0.distance) }
        return RidePeriodTotals(rides: rides)
    }

    private func landscapeTiles(totals: RidePeriodTotals, allRides: Int) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                StatTile(title: "This Week", value: RideFormat.distance(totals.weekDistance),
                         caption: Self.rides(totals.weekRides), systemImage: "calendar")
                StatTile(title: "This Month", value: RideFormat.distance(totals.monthDistance),
                         caption: Self.rides(totals.monthRides), systemImage: "calendar")
            }
            GridRow {
                StatTile(title: "This Year", value: RideFormat.distance(totals.yearDistance),
                         caption: Self.rides(totals.yearRides), systemImage: "calendar")
                Button(action: showAllRides) {
                    StatTile(title: "All Rides", value: allRides.formatted(), systemImage: "bicycle")
                        .contentShape(.rect(cornerRadius: 24))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows all rides")
            }
        }
    }

    /// “3 rides”.
    private static func rides(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? String(localized: "ride") : String(localized: "rides"))"
    }

    private func tiles(totals: RidePeriodTotals) -> some View {
        HStack(spacing: 16) {
            StatTile(title: "This Week", value: RideFormat.distance(totals.weekDistance),
                     systemImage: "calendar")
            StatTile(title: "This Month", value: totals.monthRides.formatted(),
                     unit: totals.monthRides == 1 ? "ride" : "rides", systemImage: "bicycle")
        }
    }
}

/// The rides recorded here that the Mac does not have yet (B-212), with their status, sharing
/// and deleting. Hidden while there are none.
struct RecordingsSection: View {
    @Environment(PhoneRecordings.self) private var recordings
    @Environment(PhoneLibrary.self) private var library
    @Environment(ImportFolder.self) private var folder
    @State private var deleting: PhoneRecordings.Entry?

    var body: some View {
        if !recordings.waiting.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recordings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(recordings.waiting) { entry in
                    row(entry)
                    if entry.id != recordings.waiting.last?.id { Divider() }
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            // iCloud and the Mac take a minute or two: look again while the list is shown.
            .task {
                while !Task.isCancelled {
                    await recordings.refreshStatuses(state: library.state, folder: folder)
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .confirmationDialog("Delete this recording?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible, presenting: deleting) { entry in
                Button("Delete Recording", role: .destructive) { recordings.delete(entry, folder: folder) }
            } message: { _ in
                Text("The ride is removed from the iPhone, and from the folder if the Mac has not imported it yet.")
            }
        }
    }

    private func row(_ entry: PhoneRecordings.Entry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.headline).lineLimit(2)
                    if let bike = library.state?.bike(withID: entry.bikeID) { BikeBadge(bike: bike) }
                }
                Text("\(RideFormat.duration(entry.movingTime)) · \(RideFormat.distance(entry.distance))")
                    .font(.subheadline)
                    .monospacedDigit()
                StatusLabel(status: recordings.statuses[entry.id])
            }
            Spacer()
            Menu {
                ShareLink(item: recordings.localURL(of: entry)) {
                    Label("Share GPX", systemImage: "square.and.arrow.up")
                }
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = entry }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .accessibilityLabel(Text("Actions"))
            }
        }
    }
}

/// Where a recording is on its way to the Mac.
struct StatusLabel: View {
    var status: PhoneRecordings.Status?

    var body: some View {
        switch status {
        case .onlyHere:
            Label("Only on the iPhone", systemImage: "iphone").font(.footnote).foregroundStyle(.secondary)
        case .waitingForiCloud, nil:
            VStack(alignment: .leading, spacing: 2) {
                Label("Waiting for iCloud", systemImage: "icloud.and.arrow.up").font(.footnote).foregroundStyle(.orange)
                // Seen on the iPhone (V-14): iOS sometimes uploads only once the Files app shows the folder.
                Text("If it stays like this, open the folder once in the Files app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .waitingForMac:
            Label("Waiting for the Mac", systemImage: "desktopcomputer").font(.footnote).foregroundStyle(.secondary)
        case .takenOver:
            Label("Taken over by the Mac", systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.green)
        case .failed:
            Label("The Mac could not read it", systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.red)
        }
    }
}

/// The large red button that opens the recording (design C).
struct StartRideButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Start Ride", systemImage: "record.circle")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
        .controlSize(.extraLarge)
    }
}

/// A total in a rounded glass tile.
struct StatTile: View {
    var title: LocalizedStringKey
    var value: String
    var unit: LocalizedStringKey?
    /// A line below the value that is not a unit, such as “3 rides”.
    var caption: String?
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.track)
            if let unit {
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

/// The tile “Last Ride”: map, name, date and the three key figures. Opens the detail on a tap.
struct LastRideTile: View {
    var ride: RideExchange.Ride
    var route: RideExchange.Route?
    var mapHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Ride")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            RideMap(ride: ride, route: route)
                .frame(height: mapHeight)
                .clipShape(.rect(cornerRadius: 16))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.name).font(.headline)
                    Text(RideFormat.date(ride.startDate, timeZone: ride.timeZone))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            FigureRow(ride: ride)
        }
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .contentShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the ride")
    }
}

/// Distance, riding time and climbing side by side; stacked when the text is very large.
struct FigureRow: View {
    var ride: RideExchange.Ride

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { figures }
            VStack(alignment: .leading, spacing: 8) { figures }
        }
    }

    @ViewBuilder private var figures: some View {
        Figure(title: "Distance", value: RideFormat.distance(ride.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        Figure(title: "Riding Time", value: RideFormat.duration(ride.timerTime), systemImage: "clock")
        if let ascent = ride.totalAscent {
            Figure(title: "Ascent", value: RideFormat.ascent(ascent), systemImage: "arrow.up.right")
        }
    }
}

struct Figure: View {
    var title: LocalizedStringKey
    var value: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// Version and commit, as in the About window on the Mac; in the tab “More”.
struct VersionFooter: View {
    var body: some View {
        Text("Wattspur \(AppInfo.version) (\(AppInfo.build), \(AppInfo.commit))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }
}
