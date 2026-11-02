import SwiftUI
import WattspurCore

/// The tab "Overview" of design C (B-205): two tiles with this week's and this month's totals,
/// the tile "Last Ride" with a small map, and the version at the bottom.
struct OverviewView: View {
    @State private var ride = SampleRide.load()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let ride {
                    // In 0.1 there is only the sample ride, which is old: the totals are counted
                    // for its week and month, so the tiles show what they will look like.
                    let totals = RidePeriodTotals(rides: [(start: ride.start, distance: ride.summary.distance)],
                                                  now: ride.start)
                    HStack(spacing: 16) {
                        StatTile(title: "This Week", value: RideFormat.distance(totals.weekDistance),
                                 systemImage: "calendar")
                        StatTile(title: "This Month", value: totals.monthRides.formatted(),
                                 unit: totals.monthRides == 1 ? "ride" : "rides", systemImage: "bicycle")
                    }
                    NavigationLink {
                        RideDetailView(ride: ride)
                    } label: {
                        LastRideTile(ride: ride)
                    }
                    .buttonStyle(.plain)
                    Text("Sample data: the tiles count the sample ride's week and month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ContentUnavailableView("No Rides", systemImage: "bicycle",
                                           description: Text("The sample ride could not be read."))
                }
                VersionFooter()
                    .padding(.top, 24)
            }
            .padding()
        }
        .navigationTitle("Overview")
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

/// The tile "Last Ride": map, name, date and the three key figures. Opens the detail on a tap.
struct LastRideTile: View {
    var ride: RideItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Ride")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            RouteMap(route: ride.route)
                .frame(height: 160)
                .clipShape(.rect(cornerRadius: 16))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.name).font(.headline)
                    Text(RideFormat.date(ride.start))
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
    var ride: RideItem

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { figures }
            VStack(alignment: .leading, spacing: 8) { figures }
        }
    }

    @ViewBuilder private var figures: some View {
        Figure(title: "Distance", value: RideFormat.distance(ride.summary.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        Figure(title: "Riding Time", value: RideFormat.duration(ride.summary.timerTime), systemImage: "clock")
        if let ascent = ride.summary.totalAscent {
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

/// Version and commit, as in the About window on the Mac (in 0.2 in the tab "More").
struct VersionFooter: View {
    var body: some View {
        Text("Wattspur \(AppInfo.version) (\(AppInfo.build), \(AppInfo.commit))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }
}
