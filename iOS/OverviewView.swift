import SwiftUI
import WattspurCore

/// The tab “Overview” of design C (B-214): the totals of this week and this month, the last ride
/// with a small map, and a way to all rides. Until there is a ride, the sample ride shows what the
/// tiles will look like.
struct OverviewView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(Recorder.self) private var recorder
    /// Switches to the tab “Rides”, filtered to a period (B-222); `.all` shows every ride.
    var showRides: (RidePeriod) -> Void
    @State private var sample = SampleRide.load()
    @Environment(\.isLandscape) private var isLandscape
    /// The iPad's sidebar layout (B-292): its own arrangement, see `pad`.
    @Environment(\.isPadLayout) private var isPadLayout
    /// The sport of the capsule (B-289): tiles, last ride and the count of all rides are of it.
    @ShownSport private var sport

    var body: some View {
        Group {
            if isPadLayout { pad } else if isLandscape { landscape } else { portrait }
        }
        .refreshable {
            await library.refresh()
        }
        .navigationTitle("Overview")
    }

    private var portrait: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let state = library.state, state.lastRide != nil {
                    SportMenu()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    tiles(totals: totals(state), linked: true)
                    if let last = state.only(sport).lastRide {
                        NavigationLink {
                            TourDetailView(ride: last)
                        } label: {
                            LastRideTile(ride: last)
                        }
                        .buttonStyle(.plain)
                    }
                    StartRideButton { recorder.start(device: $0) }
                    highlightsLink
                    Button { showRides(.all) } label: {
                        HStack {
                            Text("All Rides")
                            Spacer()
                            Text("\(state.only(sport).rides.count)").foregroundStyle(.secondary)
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
                                                   now: sample.ride.startDate), linked: false)
                    NavigationLink {
                        TourDetailView(ride: sample.ride, route: sample.route)
                    } label: {
                        LastRideTile(ride: sample.ride, route: sample.route)
                    }
                    .buttonStyle(.plain)
                    StartRideButton { recorder.start(device: $0) }
                    Text("Sample data: the tiles count the sample ride's week and month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    FirstRidePrompt()
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
                    if let state = library.state, state.lastRide != nil {
                        SportMenu()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let state = library.state, let last = state.only(sport).lastRide {
                        NavigationLink {
                            TourDetailView(ride: last)
                        } label: {
                            LastRideTile(ride: last, mapHeight: 100)
                        }
                        .buttonStyle(.plain)
                        // Left: the right column ends under “Start Ride”.
                        highlightsLink
                    } else if library.state?.lastRide == nil, let sample {
                        NavigationLink {
                            TourDetailView(ride: sample.ride, route: sample.route)
                        } label: {
                            LastRideTile(ride: sample.ride, route: sample.route, mapHeight: 100)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 340)
                VStack(spacing: 16) {
                    if let state = library.state, state.lastRide != nil {
                        landscapeTiles(totals: totals(state), allRides: state.only(sport).rides.count, linked: true)
                        StateLine()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let sample {
                        landscapeTiles(totals: RidePeriodTotals(rides: [(start: sample.ride.startDate, distance: sample.ride.distance)],
                                                                now: sample.ride.startDate),
                                       allRides: 1, linked: false)
                        Text("Sample data: the tiles count the sample ride's week and month.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        FirstRidePrompt()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        // Room for “Start Ride” and the tab bar below the last tiles.
        .contentMargins(.bottom, LandscapeTabBar.height + 12, for: .scrollContent)
        .overlay(alignment: .bottomTrailing) {
            StartRideButton { recorder.start(device: $0) }
                .frame(width: 230)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
        }
    }

    /// The iPad (B-292): the last ride with a large map, the four tiles beside it when the
    /// window is wider than tall, below it when it is taller (wish of Nils 18.11.2026).
    private var pad: some View {
        GeometryReader { geo in
            // Beside each other only with room for both: the tiles need about 380 pt.
            let wide = geo.size.width > geo.size.height && geo.size.width >= 760
            ScrollView {
                Group {
                    if wide {
                        HStack(alignment: .top, spacing: 16) {
                            padLastRide(mapHeight: max(240, geo.size.height - 300))
                            VStack(spacing: 16) { padTiles }
                                .frame(width: min(440, max(380, geo.size.width * 0.38)))
                        }
                    } else {
                        VStack(spacing: 16) {
                            padLastRide(mapHeight: min(max(240, geo.size.height * 0.4), 480))
                            padTiles
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder private func padLastRide(mapHeight: CGFloat) -> some View {
        if let state = library.state, let last = state.only(sport).lastRide {
            NavigationLink {
                TourDetailView(ride: last)
            } label: {
                LastRideTile(ride: last, mapHeight: mapHeight)
            }
            .buttonStyle(.plain)
        } else if library.state?.lastRide == nil, let sample {
            NavigationLink {
                TourDetailView(ride: sample.ride, route: sample.route)
            } label: {
                LastRideTile(ride: sample.ride, route: sample.route, mapHeight: mapHeight)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var padTiles: some View {
        if let state = library.state, state.lastRide != nil {
            landscapeTiles(totals: totals(state), allRides: state.only(sport).rides.count, linked: true)
            StateLine()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let sample {
            landscapeTiles(totals: RidePeriodTotals(rides: [(start: sample.ride.startDate, distance: sample.ride.distance)],
                                                    now: sample.ride.startDate),
                           allRides: 1, linked: false)
            Text("Sample data: the tiles count the sample ride's week and month.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            FirstRidePrompt()
        }
    }

    /// The tile that opens the highlights on the iPhone (B-228); the iPad has them in its sidebar.
    private var highlightsLink: some View {
        NavigationLink {
            HighlightsView()
        } label: {
            HighlightsTile()
        }
        .buttonStyle(.plain)
    }

    /// The totals of the library (B-214) for the sport of the capsule (B-289): a car never lands in
    /// the cycling tiles, like on the Mac.
    private func totals(_ state: RideExchange.Library) -> RidePeriodTotals {
        state.totals(of: sport)
    }

    private func landscapeTiles(totals: RidePeriodTotals, allRides: Int, linked: Bool) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                periodTile(.thisWeek, linked: linked) {
                    StatTile(title: "This Week", value: RideFormat.distance(totals.weekDistance),
                             caption: Self.rides(totals.weekRides), systemImage: "calendar")
                }
                periodTile(.thisMonth, linked: linked) {
                    StatTile(title: "This Month", value: RideFormat.distance(totals.monthDistance),
                             caption: Self.rides(totals.monthRides), systemImage: "calendar")
                }
            }
            GridRow {
                periodTile(.thisYear, linked: linked) {
                    StatTile(title: "This Year", value: RideFormat.distance(totals.yearDistance),
                             caption: Self.rides(totals.yearRides), systemImage: "calendar")
                }
                periodTile(.all, linked: linked) {
                    StatTile(title: "All Rides", value: allRides.formatted(), systemImage: sport.symbol)
                }
            }
        }
    }

    /// A tile that opens the list filtered to its period (B-222, wish of Nils 5.11.2026). The
    /// sample ride's tiles count an old week, so they open nothing.
    @ViewBuilder private func periodTile(_ period: RidePeriod, linked: Bool,
                                         @ViewBuilder tile: () -> some View) -> some View {
        if linked {
            Button { showRides(period) } label: {
                tile().contentShape(.rect(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .accessibilityHint(period == .all ? "Shows all rides" : "Shows the rides of this period")
        } else {
            tile()
        }
    }

    /// “3 rides”.
    private static func rides(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? String(localized: "ride") : String(localized: "rides"))"
    }

    private func tiles(totals: RidePeriodTotals, linked: Bool) -> some View {
        HStack(spacing: 16) {
            periodTile(.thisWeek, linked: linked) {
                StatTile(title: "This Week", value: RideFormat.distance(totals.weekDistance),
                         systemImage: "calendar")
            }
            periodTile(.thisMonth, linked: linked) {
                StatTile(title: "This Month", value: totals.monthRides.formatted(),
                         unit: totals.monthRides == 1 ? "ride" : "rides", systemImage: sport.symbol)
            }
        }
    }
}

/// The tile "Highlights" in the overview (B-228): the next goal not yet reached with its
/// progress; without goals the number of records of the sport and its longest ride (the totals
/// of the year are already in the tiles above).
struct HighlightsTile: View {
    @Environment(PhoneLibrary.self) private var library
    @ShownSport private var sport

    var body: some View {
        let calendar = GoalPeriod.calendar()
        let rides = library.statsRides.filter(\.countsInStatistics)
        // Goals count every bike, whatever sport the capsule shows (as on the Mac and the iPad).
        let cycling = rides.filter { $0.sport == .cycling }.map(\.highlight)
        let goals = library.goals.map {
            GoalProgress(metric: $0.metric, period: $0.period, target: $0.target, rides: cycling, calendar: calendar)
        }
        let next = goals.first { !$0.current.isReached } ?? goals.first
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Highlights", systemImage: "trophy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            if let next {
                goal(next, calendar: calendar)
            } else {
                records(rides.filter { $0.sport == sport }.map(\.highlight), calendar: calendar)
            }
        }
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .contentShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows your year, records and goals")
    }

    @ViewBuilder private func goal(_ progress: GoalProgress, calendar: Calendar) -> some View {
        let metric = progress.metric
        let unit = HighlightTexts.unit(metric)
        let target = HighlightTexts.number(metric, progress.current.target)
        Text(verbatim: "\(HighlightTexts.currentPeriod(progress.period, progress.current.interval, calendar: calendar)) · \(HighlightTexts.title(metric))")
            .font(.footnote)
            .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: HighlightTexts.number(metric, progress.current.value))
                .font(.title.weight(.bold))
                .foregroundStyle(Color.track)
            Text(verbatim: String(localized: "of \(unit.isEmpty ? target : "\(target) \(unit)")"))
                .foregroundStyle(.secondary)
            Spacer()
            if progress.current.isReached {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.track)
                    .accessibilityLabel(Text("Reached"))
            }
        }
        .monospacedDigit()
        ProgressView(value: min(1, progress.current.fraction))
            .tint(Color.track)
    }

    @ViewBuilder private func records(_ rides: [HighlightRide], calendar: Calendar) -> some View {
        let records = HighlightsSummary(rides: rides, calendar: calendar).records
        Text("Year, records and goals")
            .font(.footnote)
            .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: String(localized: "\(records.count) records"))
                .font(.title.weight(.bold))
                .foregroundStyle(Color.track)
            Spacer()
            if let longest = records.first(where: { $0.kind == .longestDistance }) {
                Text(verbatim: "\(HighlightTexts.title(longest.kind)) \(HighlightTexts.text(longest.kind, longest.value))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .monospacedDigit()
    }
}

/// The large red button that opens the recording (design C). One tap starts with the device of the
/// last recording; “with … ▾” below it opens “What are you riding?” (B-286).
struct StartRideButton: View {
    @Environment(PhoneLibrary.self) private var library
    /// The sport of the capsule: the button offers a device of it (B-324).
    @ShownSport private var sport
    var action: (RecordingDevice) -> Void
    @State private var choosing = false

    var body: some View {
        // Not on the iPad for now (B-292): it has no recording until B-293.
        if RecordingAvailability.isSupported { button }
    }

    private var button: some View {
        let device = library.nextRecordingDevice(in: sport)
        return VStack(spacing: 6) {
            Button { action(device) } label: {
                Label("Start Ride", systemImage: "record.circle")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
            .controlSize(.extraLarge)
            Button { choosing = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: device.symbol)
                    Text("with \(device.name(in: library.state?.bikes ?? []))")
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(minHeight: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Choose what you ride with"))
            .accessibilityValue(Text(verbatim: device.name(in: library.state?.bikes ?? [])))
        }
        .sheet(isPresented: $choosing) {
            DeviceChoiceSheet(current: device) { chosen in
                RecordingChoice.last = chosen
                choosing = false
                action(chosen)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// “What are you riding?” (B-286): the devices in groups Bikes, Vehicles and Shoes, below them the
/// vehicle types bicycle, car and motorcycle without a device (B-321), e.g. for a hired bike or a
/// rented car. A tap starts the ride with it.
struct DeviceChoiceSheet: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    var current: RecordingDevice
    var start: (RecordingDevice) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.sport) { group in
                    Section {
                        ForEach(group.devices) { device in
                            row(RecordingDevice(bikeID: device.id, kind: BikeKind(rawValue: device.kind) ?? .bike)) {
                                Label { Text(device.name) } icon: { BikeBadge(bike: device) }
                            }
                        }
                    } header: {
                        Text(group.sport.devicesTitle)
                    }
                }
                Section {
                    ForEach(RecordingDevice.vehicleTypes, id: \.self) { kind in
                        row(.without(kind)) {
                            Label { Text(kind.label) } icon: { Image(systemName: BikeBadge.symbol(kind)) }
                        }
                    }
                } header: {
                    Text("Vehicle Type")
                } footer: {
                    Text("For a bike or vehicle that is not yours. A bicycle ride counts in the cycling totals but towards none of your bikes; a car or motorcycle ride does not count in them.")
                }
            }
            .navigationTitle("What Are You Riding?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var groups: [(sport: Sport, devices: [RideExchange.Bike])] {
        (library.state?.devicesBySport() ?? []).map { ($0.sport, $0.devices.filter { !$0.isArchived }) }
            .filter { !$0.devices.isEmpty }
    }

    private func row(_ device: RecordingDevice, @ViewBuilder label: () -> some View) -> some View {
        Button { start(device) } label: {
            HStack {
                label()
                Spacer()
                if device == current { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
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
