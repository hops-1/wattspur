import SwiftUI
import WattspurCore

/// The tab “Rides” (B-209): the rides from the Mac by month, newest first. Pull down to read the
/// state again; the copy in the app shows them without a connection too.
struct RidesView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.isLandscape) private var isLandscape
    /// The ride shown beside the list in landscape (B-243); the newest until one is tapped.
    @State private var selection: UUID?
    /// Search and filters (B-222), kept by the app: the period tiles of the overview set them.
    @Binding var filter: RideFilter
    /// A ride to open, from “Open last ride” (Siri or a shortcut, B-225); cleared when it closes.
    @Binding var openedRideID: UUID?

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
                    if isLandscape {
                        split(state)
                    } else {
                        list(state)
                    }
                }
            }
        }
        .navigationTitle("Rides")
        // In landscape the ride is shown beside the list.
        .onChange(of: openedRideID, initial: true) { _, id in
            if isLandscape, let id {
                selection = id
                openedRideID = nil
            }
        }
    }

    /// The filter as it applies: a bike filter only with two bikes or more (`RideFilter.resolved`).
    private func effectiveFilter(_ state: RideExchange.Library) -> RideFilter {
        filter.resolved(knownBikeIDs: Set(state.bikes.map(\.id)))
    }

    private func filterBar(_ state: RideExchange.Library, months: [RideExchange.Library.Month]) -> some View {
        RideFilterBar(filter: $filter, compact: isLandscape, bikes: state.bikes.filter { !$0.isArchived || $0.id == filter.bike.bikeID },
                      shown: months.reduce(0) { $0 + $1.rides.count }, total: state.rides.count)
    }

    /// No rides at all, or none that pass the search and filters.
    @ViewBuilder private func emptyState(_ state: RideExchange.Library, months: [RideExchange.Library.Month]) -> some View {
        if state.rides.isEmpty {
            noRides
        } else if months.isEmpty {
            ContentUnavailableView {
                Label("No Matches", systemImage: "magnifyingglass")
            } description: {
                Text("Change the search or the filters.")
            } actions: {
                Button("Show All Rides") { filter = RideFilter() }
            }
        }
    }

    /// Landscape (B-243): the list on the left, the detail of the chosen ride on the right.
    private func split(_ state: RideExchange.Library) -> some View {
        let months = state.months(filteredBy: effectiveFilter(state))
        let shownRides = months.flatMap(\.rides)
        let chosen = shownRides.first { $0.id == selection } ?? shownRides.first
        return HStack(spacing: 0) {
            List {
                if !library.usesDatabase || library.problem != nil {
                    Section {
                        StateLine()
                    }
                }
                ForEach(months) { month in
                    Section(RideFormat.month(month.start)) {
                        ForEach(month.rides) { ride in
                            Button {
                                selection = ride.id
                            } label: {
                                RideRow(ride: ride, bike: state.bike(withID: ride.bikeID))
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(ride.id == chosen?.id ? Color.track.opacity(0.14) : nil)
                            .accessibilityAddTraits(ride.id == chosen?.id ? .isSelected : [])
                            .contextMenu { actions(for: ride) }
                            .swipeActions(edge: .trailing) { deleteAction(for: ride) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await library.refresh() }
            .scrollDismissesKeyboard(.immediately)
            .tabBarRoomInLandscape()
            .safeAreaInset(edge: .top, spacing: 0) { filterBar(state, months: months) }
            .frame(width: 320)
            .overlay { emptyState(state, months: months) }
            Divider()
            if let chosen {
                TourDetailView(ride: chosen, embedded: true)
                    .id(chosen.id)
            } else {
                Color.clear
            }
        }
        // No title bar (`hidesTitleBar`): the search sits at the top, the
        // detail has its own buttons.
    }

    @ViewBuilder private func actions(for ride: RideExchange.Ride) -> some View {
        if library.canShare(ride) {
            ShareLink(item: library.sharedGPX(for: ride), preview: SharePreview(ride.name)) {
                Label("Share GPX", systemImage: "square.and.arrow.up")
            }
        }
        if library.usesDatabase {
            Button("Move to Trash", systemImage: "trash", role: .destructive) { library.moveToTrash(ride) }
        }
    }

    /// Only the iPhone's own rides can be deleted; those from the Mac's state cannot (B-217).
    @ViewBuilder private func deleteAction(for ride: RideExchange.Ride) -> some View {
        if library.usesDatabase {
            Button("Delete", systemImage: "trash", role: .destructive) { library.moveToTrash(ride) }
                .tint(.red)
        }
    }

    @ViewBuilder private var noRides: some View {
        if library.usesDatabase {
            ContentUnavailableView("No Rides", systemImage: "bicycle",
                                   description: Text("Record a ride in the overview."))
        } else {
            ContentUnavailableView("No Rides", systemImage: "bicycle",
                                   description: Text("The Mac has no rides yet."))
        }
    }

    private func list(_ state: RideExchange.Library) -> some View {
        let months = state.months(filteredBy: effectiveFilter(state))
        return List {
            // The line about the Mac's state; the iPhone's own store has none, unless something went wrong.
            if !library.usesDatabase || library.problem != nil {
                Section {
                    StateLine()
                }
            }
            ForEach(months) { month in
                Section(RideFormat.month(month.start)) {
                    ForEach(month.rides) { ride in
                        NavigationLink {
                            TourDetailView(ride: ride)
                        } label: {
                            RideRow(ride: ride, bike: state.bike(withID: ride.bikeID))
                        }
                        .contextMenu { actions(for: ride) }
                        .swipeActions(edge: .trailing) { deleteAction(for: ride) }
                    }
                }
            }
        }
        .refreshable { await library.refresh() }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) { filterBar(state, months: months) }
        .overlay { emptyState(state, months: months) }
        .navigationDestination(isPresented: Binding(get: { openedRide(in: state) != nil },
                                                    set: { if !$0 { openedRideID = nil } })) {
            if let ride = openedRide(in: state) {
                TourDetailView(ride: ride)
            }
        }
    }

    private func openedRide(in state: RideExchange.Library) -> RideExchange.Ride? {
        guard let openedRideID, !isLandscape else { return nil }
        return state.rides.first { $0.id == openedRideID }
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
