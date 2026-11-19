import SwiftUI
import WattspurCore

/// The tab “Rides” (B-209): the rides of the library by month, newest first. Pull down to read
/// the store again.
struct RidesView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.isLandscape) private var isLandscape
    /// On the iPad the ride is shown beside the list too (B-292).
    @Environment(\.isPadLayout) private var isPadLayout
    @Environment(PhoneImport.self) private var phoneImport
    /// The sport of the capsule (B-289): the list shows only its rides.
    @ShownSport private var sport
    /// The ride shown beside the list in landscape (B-243); the newest until one is tapped.
    @State private var selection: UUID?
    /// On the iPad (B-296): choosing several rides to compare or merge them, and the chosen ones.
    @State private var selecting = false
    @State private var marked: Set<UUID> = []
    /// Search and filters (B-222), kept by the app: the period tiles of the overview set them.
    @Binding var filter: RideFilter
    /// A ride to open, from “Open last ride” (Siri or a shortcut, B-225); cleared when it closes.
    @Binding var openedRideID: UUID?

    var body: some View {
        Group {
            if let state = library.state {
                if sideBySide {
                    split(state)
                } else {
                    list(state)
                }
            }
        }
        .navigationTitle("Rides")
        // In landscape the ride is shown beside the list.
        .onChange(of: openedRideID, initial: true) { _, id in
            if sideBySide, let id {
                selection = id
                openedRideID = nil
            }
        }
    }

    /// List and ride side by side: in landscape on the iPhone (B-243), always on the iPad (B-292).
    private var sideBySide: Bool { isLandscape || isPadLayout }

    /// The filter as it applies: a bike filter only with two devices of the sport or more (`RideFilter.resolved`).
    private func effectiveFilter(_ state: RideExchange.Library) -> RideFilter {
        filter.resolved(knownBikeIDs: Set(state.devices(of: sport).map(\.id)))
    }

    /// The rides of the sport shown, by month, with search and filters.
    private func shownMonths(_ state: RideExchange.Library) -> [RideExchange.Library.Month] {
        state.only(sport).months(filteredBy: effectiveFilter(state))
    }

    private func filterBar(_ state: RideExchange.Library, months: [RideExchange.Library.Month]) -> some View {
        RideFilterBar(filter: $filter, compact: sideBySide, sport: sport,
                      bikes: state.devices(of: sport).filter { !$0.isArchived || $0.id == filter.bike.bikeID },
                      shown: months.reduce(0) { $0 + $1.rides.count }, total: state.only(sport).rides.count,
                      importFiles: { phoneImport.choosingFiles = true })
    }

    /// No rides at all, or none that pass the search and filters.
    @ViewBuilder private func emptyState(_ state: RideExchange.Library, months: [RideExchange.Library.Month]) -> some View {
        if state.only(sport).rides.isEmpty {
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
        let months = shownMonths(state)
        let shownRides = months.flatMap(\.rides)
        let chosen = shownRides.first { $0.id == selection } ?? shownRides.first
        return HStack(spacing: 0) {
            List {
                if library.problem != nil {
                    Section {
                        StateLine()
                    }
                }
                ForEach(months) { month in
                    Section(RideFormat.month(month.start)) {
                        ForEach(month.rides) { ride in
                            Button {
                                if selecting {
                                    if marked.contains(ride.id) { marked.remove(ride.id) } else { marked.insert(ride.id) }
                                } else {
                                    selection = ride.id
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if selecting {
                                        Image(systemName: marked.contains(ride.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(marked.contains(ride.id) ? Color.track : Color.secondary)
                                            .accessibilityHidden(true)
                                    }
                                    RideRow(ride: ride, bike: state.bike(withID: ride.bikeID))
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(highlighted(ride, chosen: chosen) ? Color.track.opacity(0.14) : nil)
                            .accessibilityAddTraits(highlighted(ride, chosen: chosen) ? .isSelected : [])
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
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if isPadLayout { selectBar }
                    filterBar(state, months: months)
                }
            }
            .frame(width: 320)
            .overlay { emptyState(state, months: months) }
            .modifier(RideFileDrop(enabled: isPadLayout) { phoneImport.importFiles($0, library: library) })
            Divider()
            if selecting {
                selectionDetail
            } else if let chosen {
                TourDetailView(ride: chosen, embedded: true)
                    .id(chosen.id)
            } else {
                Color.clear
            }
        }
        // No title bar (`hidesTitleBar`): the search sits at the top, the
        // detail has its own buttons.
    }

    /// The ride beside the list, or while choosing on the iPad the chosen ones.
    private func highlighted(_ ride: RideExchange.Ride, chosen: RideExchange.Ride?) -> Bool {
        selecting ? marked.contains(ride.id) : ride.id == chosen?.id
    }

    /// "Select" above the list on the iPad (B-296): then a tap marks rides to compare or merge.
    private var selectBar: some View {
        HStack {
            if selecting {
                Text("\(marked.count) selected").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button(selecting ? "Cancel" : "Select") {
                selecting.toggle()
                marked = []
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// While choosing: the comparison from two rides on, before that a hint.
    @ViewBuilder private var selectionDetail: some View {
        if marked.count >= 2 {
            PadCompareView(rideIDs: marked) { id in
                selecting = false
                marked = []
                selection = id
            } onMerged: { id in
                selecting = false
                marked = []
                selection = id
            } onDone: {
                selecting = false
                marked = []
            }
        } else {
            ContentUnavailableView("Select Rides", systemImage: "checkmark.circle",
                                   description: Text("Tap two to four rides to compare them, or two or more to merge them."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func actions(for ride: RideExchange.Ride) -> some View {
        if library.canShare(ride) {
            ShareLink(item: library.sharedGPX(for: ride), preview: SharePreview(ride.name)) {
                Label("Share GPX", systemImage: "square.and.arrow.up")
            }
        }
        Button("Move to Trash", systemImage: "trash", role: .destructive) { library.moveToTrash(ride) }
    }

    /// Into the trash (B-217), here and over iCloud on the Mac too.
    private func deleteAction(for ride: RideExchange.Ride) -> some View {
        Button("Delete", systemImage: "trash", role: .destructive) { library.moveToTrash(ride) }
            .tint(.red)
    }

    private var noRides: some View {
        ContentUnavailableView {
            Label("No Rides", systemImage: "bicycle")
        } description: {
            Text("Record a ride in the overview, or import FIT and GPX files.")
        } actions: {
            Button("Import Files …") { phoneImport.choosingFiles = true }
        }
    }

    private func list(_ state: RideExchange.Library) -> some View {
        let months = shownMonths(state)
        return List {
            // Only when reading the store went wrong.
            if library.problem != nil {
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
        guard let openedRideID, !sideBySide else { return nil }
        return state.rides.first { $0.id == openedRideID }
    }
}

/// Why the store could not be read again; empty when all is well.
struct StateLine: View {
    @Environment(PhoneLibrary.self) private var library

    var body: some View {
        if let problem = library.problem {
            Label(problem, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
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

/// FIT and GPX files dropped on the list on the iPad (B-297) go into the same import as files
/// from the file picker; the iPhone's list takes no drops.
private struct RideFileDrop: ViewModifier {
    let enabled: Bool
    let onDrop: ([URL]) -> Void
    @State private var targeted = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .dropDestination(for: DroppedRideFile.self) { files, _ in
                    onDrop(files.map(\.url))
                    return !files.isEmpty
                } isTargeted: { targeted = $0 }
                .overlay {
                    if targeted {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.track, lineWidth: 3)
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            content
        }
    }
}
