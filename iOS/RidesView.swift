import SwiftUI
import WattspurCore

/// The tab “Rides” (B-209): the rides from the Mac by month, newest first. Pull down to read the
/// state again; the copy in the app shows them without a connection too.
struct RidesView: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        Group {
            switch library.status {
            case .noFolder:
                ChooseFolderPrompt()
            case .noState:
                MacSettingPrompt()
                    .refreshable { await library.refresh() }
            case .loaded:
                if let state = library.state {
                    list(state)
                }
            }
        }
        .navigationTitle("Rides")
    }

    private func list(_ state: RideExchange.Library) -> some View {
        List {
            // The line about the Mac's state; the iPhone's own store has none, unless something went wrong.
            if !library.usesDatabase || library.problem != nil {
                Section {
                    StateLine()
                }
            }
            ForEach(state.months()) { month in
                Section(RideFormat.month(month.start)) {
                    ForEach(month.rides) { ride in
                        NavigationLink {
                            TourDetailView(ride: ride)
                        } label: {
                            RideRow(ride: ride, bike: state.bike(withID: ride.bikeID))
                        }
                        .contextMenu {
                            if library.canShare(ride) {
                                ShareLink(item: library.sharedGPX(for: ride), preview: SharePreview(ride.name)) {
                                    Label("Share GPX", systemImage: "square.and.arrow.up")
                                }
                            }
                            if library.usesDatabase {
                                Button("Move to Trash", systemImage: "trash", role: .destructive) { library.moveToTrash(ride) }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            // Only the iPhone's own rides can be deleted; those from the Mac's state cannot (B-217).
                            if library.usesDatabase {
                                Button("Delete", systemImage: "trash", role: .destructive) { library.moveToTrash(ride) }
                                    .tint(.red)
                            }
                        }
                    }
                }
            }
        }
        .refreshable { await library.refresh() }
        .overlay {
            if state.rides.isEmpty {
                if library.usesDatabase {
                    ContentUnavailableView("No Rides", systemImage: "bicycle",
                                           description: Text("Record a ride in the overview."))
                } else {
                    ContentUnavailableView("No Rides", systemImage: "bicycle",
                                           description: Text("The Mac has no rides yet."))
                }
            }
        }
    }
}

/// “State from the Mac: Today, 14:02”, or why it could not be read again.
struct StateLine: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let state = library.state, !library.usesDatabase {
                Label("State from the Mac: \(RideFormat.stateDate(state.generatedAt))", systemImage: "desktopcomputer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let problem = library.problem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// Name, date, riding time · distance, ascent and the bike.
struct RideRow: View {
    var ride: RideExchange.Ride
    var bike: RideExchange.Bike?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(ride.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if let bike { BikeBadge(bike: bike) }
            }
            Text(RideFormat.shortDate(ride.startDate, timeZone: ride.timeZone))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text("\(RideFormat.duration(ride.timerTime)) · \(RideFormat.distance(ride.distance))")
                if let ascent = ride.totalAscent {
                    Label(RideFormat.ascent(ascent), systemImage: "arrow.up.right")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.subheadline)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
