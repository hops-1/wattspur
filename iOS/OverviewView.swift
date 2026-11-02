import SwiftUI
import WattspurCore

/// The tab “Overview” of design C (B-214): the totals of this week and this month, the last ride
/// with a small map, and a way to all rides. The figures come from the Mac; until there is a
/// state, the sample ride shows what the tiles will look like.
struct OverviewView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(Recorder.self) private var recorder
    /// Switches to the tab “Rides”.
    var showAllRides: () -> Void
    @State private var sample = SampleRide.load()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let state = library.state, let last = state.lastRide {
                    tiles(totals: state.totals())
                    NavigationLink {
                        TourDetailView(ride: last)
                    } label: {
                        LastRideTile(ride: last)
                    }
                    .buttonStyle(.plain)
                    StartRideButton { recorder.start() }
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
                    Text("Sample data: the tiles count the sample ride's week and month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if library.status == .noFolder {
                        ChooseFolderPrompt()
                    } else {
                        MacSettingPrompt()
                    }
                }
            }
            .padding()
        }
        .refreshable { await library.refresh() }
        .navigationTitle("Overview")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Ride")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            RideMap(ride: ride, route: route)
                .frame(height: 160)
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
