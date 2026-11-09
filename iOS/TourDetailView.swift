import Charts
import MapKit
import SwiftUI
import WattspurCore

/// The tour detail on the iPhone (B-210): the map with the track, the key figures as a grid and
/// the charts: with the iPhone's own store a carousel of all measurements (B-090), otherwise the
/// elevation profile from the route.
struct TourDetailView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var editing = false
    /// The ride as it was opened; `ride` follows later changes such as a new name (B-240).
    private var opened: RideExchange.Ride
    /// For the sample ride, whose route is not in the store.
    var route: RideExchange.Route?
    @State private var loaded: RideExchange.Route?
    /// The measurements for the carousel (B-090, B-241); only from the iPhone's own store.
    @State private var chartPoints: [ChartPoint] = []
    /// The time series, to look up the spot under the finger on a chart (B-221).
    @State private var track = RideTrack(samples: [])
    /// That spot; the map shows it as a dot while the finger stays on the chart.
    @State private var spot: RideTrack.Fix?
    /// Lean, acceleration and sprint, and the track by lean angle (B-246); only rides recorded with
    /// the motion sensors.
    @State private var motion: RideMotion?
    @State private var leanStretches: [RideMotion.LeanStretch] = []
    @State private var surfaceStretches: [RideMotion.SurfaceStretch] = []

    private var marker: CLLocationCoordinate2D? {
        guard let latitude = spot?.latitude, let longitude = spot?.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var shownRoute: RideExchange.Route? { route ?? loaded }
    /// Beside the list of rides in landscape (B-243): the name as a heading instead of the title.
    private var embedded: Bool
    @Environment(\.isLandscape) private var isLandscape

    init(ride: RideExchange.Ride, route: RideExchange.Route? = nil, embedded: Bool = false) {
        opened = ride
        self.route = route
        self.embedded = embedded
    }

    /// The current state of the ride in the library, after an edit here or on the Mac.
    private var ride: RideExchange.Ride {
        library.state?.rides.first { $0.id == opened.id } ?? opened
    }

    var body: some View {
        Group {
            if embedded {
                besideList
            } else if isLandscape {
                landscape
            } else {
                portrait
            }
        }
        // In landscape the name is a heading beside the map; the slim bar keeps only Back and the buttons.
        .modifier(DetailTitle(title: embedded || isLandscape ? nil : ride.name))
        .hidesTabBarInLandscape()
        .toolbar {
            // Beside the list in landscape there is no title bar: the buttons sit in the heading.
            if !embedded { actions }
        }
        .sheet(isPresented: $editing) {
            EditRideSheet(ride: ride)
        }
        .confirmationDialog("Move this ride to the trash?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                library.moveToTrash(ride)
                dismiss()
            }
        } message: {
            Text("You can restore it in More › Trash for 30 days.")
        }
        .task(id: ride.routeFile) {
            if route == nil { loaded = await library.route(for: ride) }
        }
        // Again when the Mac changed the ride: its route file name changes with it (R-62).
        .task(id: "\(ride.id)|\(ride.routeFile ?? "")") {
            // Decoding a few thousand samples is quick, but keep it out of every redraw; once (R-33).
            guard route == nil else { return }
            let detail = library.detail(for: ride)
            chartPoints = detail.chartPoints
            track = detail.track
            motion = detail.motion?.figures
            leanStretches = detail.motion?.lean ?? []
            surfaceStretches = detail.motion?.surface ?? []
        }
    }

    private var portrait: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RideMap(ride: ride, route: route, interactive: true, marker: marker, leanStretches: leanStretches,
                        surfaceStretches: surfaceStretches)
                    .frame(height: 300)
                    .clipShape(.rect(cornerRadius: 24))
                // Right below the map, so both stay on screen while the finger is on a chart (B-221).
                if hasCarousel {
                    RideChartCarousel(ride: ride, points: chartPoints, track: track, spot: $spot)
                }
                info
                FigureGrid(ride: ride, motion: motion)
                elevationProfile
            }
            .padding()
        }
    }

    /// Landscape (B-243): the map on the left over the whole height, figures and charts on the
    /// right; map and chart stay side by side while the finger is on a chart (B-221).
    private var landscape: some View {
        HStack(spacing: 16) {
            RideMap(ride: ride, route: route, interactive: true, marker: marker, leanStretches: leanStretches,
                        surfaceStretches: surfaceStretches)
                .clipShape(.rect(cornerRadius: 24))
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.45 }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ride.name)
                            .font(.title3.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        info
                    }
                    if hasCarousel {
                        RideChartCarousel(ride: ride, points: chartPoints, track: track, spot: $spot, height: 230)
                    }
                    FigureGrid(ride: ride, motion: motion)
                    elevationProfile
                }
                .padding(.bottom)
            }
        }
        .padding(.horizontal)
    }

    /// Beside the list of rides in landscape (B-243): name and date as a heading, a small map next
    /// to the figures, the charts below.
    private var besideList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ride.name)
                            .font(.title3.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        info
                    }
                    Spacer(minLength: 0)
                    actions
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                }
                HStack(alignment: .top, spacing: 12) {
                    RideMap(ride: ride, route: route, interactive: true, marker: marker, leanStretches: leanStretches,
                        surfaceStretches: surfaceStretches)
                        .frame(width: 170, height: 190)
                        .clipShape(.rect(cornerRadius: 20))
                    FigureGrid(ride: ride, motion: motion, compact: true)
                }
                if hasCarousel {
                    RideChartCarousel(ride: ride, points: chartPoints, track: track, spot: $spot, height: 230)
                }
                elevationProfile
            }
            .padding()
        }
    }

    /// Share, edit and delete; only rides of the iPhone's own store, not the sample ride or the
    /// Mac's state (B-217).
    @ViewBuilder private var actions: some View {
        if library.canShare(ride), route == nil {
            ShareLink(item: library.sharedGPX(for: ride), preview: SharePreview(ride.name)) {
                Label("Share GPX", systemImage: "square.and.arrow.up")
            }
        }
        if library.database != nil, route == nil {
            Button("Edit", systemImage: "pencil") { editing = true }
            Button("Delete", systemImage: "trash") { confirmingDelete = true }
        }
    }

    private var hasCarousel: Bool { !ChartMeasure.available(in: chartPoints).isEmpty }

    /// Date, bike and whether the figures are estimated.
    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(RideFormat.date(ride.startDate, timeZone: ride.timeZone))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let bike = library.state?.bike(withID: ride.bikeID) {
                Label { Text(bike.name) } icon: { BikeBadge(bike: bike) }
                    .font(.subheadline)
            }
            if ride.estimated {
                Label("Figures estimated from GPS", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Without the carousel, the elevation profile from the route.
    @ViewBuilder private var elevationProfile: some View {
        if !hasCarousel, let shownRoute, ElevationProfile.hasAltitude(shownRoute) {
            ElevationProfile(route: shownRoute)
        }
    }
}

/// The ride's name as the title, except beside the list in landscape, where the list keeps its own.
private struct DetailTitle: ViewModifier {
    var title: String?

    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

/// The key figures in tiles, two per row; only those the ride has.
struct FigureGrid: View {
    var ride: RideExchange.Ride
    /// From the motion sensors (B-246); `nil` for other rides.
    var motion: RideMotion? = nil
    /// Smaller tiles, beside the map in landscape (B-243).
    var compact = false

    private var spacing: CGFloat { compact ? 8 : 12 }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)], spacing: spacing) {
            ForEach(figures.indices, id: \.self) { index in
                let figure = figures[index]
                VStack(alignment: .leading, spacing: 4) {
                    // Beside the map the tiles are narrow: the title without its icon, on one line.
                    Label(figure.title, systemImage: figure.systemImage)
                        .labelStyle(compact ? AnyLabelStyle(.titleOnly) : AnyLabelStyle(.titleAndIcon))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 1 : nil)
                        .minimumScaleFactor(compact ? 0.8 : 1)
                    Text(figure.value)
                        .font(compact ? .headline : .title3.weight(.semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(compact ? 8 : 12)
                .glassEffect(.regular, in: .rect(cornerRadius: compact ? 12 : 16))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private struct Item {
        var title: LocalizedStringKey
        var value: String
        var systemImage: String
    }

    private var figures: [Item] {
        var items = [
            Item(title: "Distance", value: RideFormat.distance(ride.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath"),
            Item(title: "Riding Time", value: RideFormat.duration(ride.timerTime), systemImage: "clock"),
        ]
        if let speed = ride.averageSpeed {
            items.append(Item(title: "Average Speed", value: RideFormat.speed(speed), systemImage: "speedometer"))
        }
        if let speed = ride.maxSpeed {
            items.append(Item(title: "Max. Speed", value: RideFormat.speed(speed), systemImage: "gauge.with.dots.needle.67percent"))
        }
        if let ascent = ride.totalAscent {
            items.append(Item(title: "Ascent", value: RideFormat.ascent(ascent), systemImage: "arrow.up.right"))
        }
        if let descent = ride.totalDescent {
            items.append(Item(title: "Descent", value: RideFormat.ascent(descent), systemImage: "arrow.down.right"))
        }
        if let power = ride.averagePower {
            items.append(Item(title: "Average Power", value: "\(power) W", systemImage: "bolt"))
        }
        if let power = ride.maxPower {
            items.append(Item(title: "Max. Power", value: "\(power) W", systemImage: "bolt.fill"))
        }
        if let cadence = ride.averageCadence {
            items.append(Item(title: "Average Cadence", value: String(localized: "\(cadence) rpm"), systemImage: "arrow.trianglehead.2.clockwise"))
        }
        if let work = ride.work {
            items.append(Item(title: "Work", value: "\(Int(work.rounded())) kJ", systemImage: "flame"))
        }
        if let motion {
            items.append(Item(title: "Max. Lean Left", value: RideFormat.lean(motion.maxLeanLeft), systemImage: "arrow.turn.up.left"))
            items.append(Item(title: "Max. Lean Right", value: RideFormat.lean(motion.maxLeanRight), systemImage: "arrow.turn.up.right"))
            if let g = motion.strongestAcceleration {
                items.append(Item(title: "Max. Acceleration", value: RideFormat.gForce(g), systemImage: "arrow.up.forward.circle"))
            }
            if let g = motion.strongestBraking {
                items.append(Item(title: "Max. Braking", value: RideFormat.gForce(g), systemImage: "exclamationmark.octagon"))
            }
            if let sprint = motion.sprint {
                items.append(Item(title: "0–\(Int(sprint.targetKmh)) km/h", value: RideFormat.seconds(sprint.seconds), systemImage: "stopwatch"))
            }
            if let share = motion.roughShare {
                items.append(Item(title: "Uneven Surface", value: RideFormat.percent(share), systemImage: "road.lanes"))
            }
        }
        items.append(Item(title: "Total Time", value: RideFormat.duration(ride.elapsedTime), systemImage: "hourglass"))
        if let low = ride.minAltitude, let high = ride.maxAltitude {
            items.append(Item(title: "Altitude", value: "\(RideFormat.altitude(low)) – \(RideFormat.altitude(high))", systemImage: "mountain.2"))
        }
        return items
    }
}

/// Either label style, chosen at run time.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView

    init(_ style: some LabelStyle) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// The altitude over the distance, from the simplified route (one point every 20 m).
struct ElevationProfile: View {
    var route: RideExchange.Route

    private struct Point: Identifiable {
        var id: Int
        var kilometres: Double
        var altitude: Double
        var segment: Int
    }

    static func hasAltitude(_ route: RideExchange.Route) -> Bool {
        route.segments.contains { $0.altitude.contains { $0 != nil } }
    }

    private var points: [Point] {
        var result: [Point] = []
        for (index, segment) in route.segments.enumerated() {
            for (distance, altitude) in zip(segment.distance, segment.altitude) {
                guard let altitude else { continue }
                result.append(Point(id: result.count, kilometres: distance / 1000, altitude: altitude, segment: index))
            }
        }
        return result
    }

    var body: some View {
        let points = points
        let low = points.map(\.altitude).min() ?? 0
        let high = points.map(\.altitude).max() ?? 0
        // Some room below and above, at least 20 m, so a flat ride does not look like a mountain.
        let padding = max(10, (high - low) * 0.1)
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation Profile")
                .font(.headline)
            Chart(points) { point in
                AreaMark(x: .value("Distance", point.kilometres),
                         yStart: .value("Altitude", low - padding),
                         yEnd: .value("Altitude", point.altitude),
                         series: .value("Part", point.segment))
                    .foregroundStyle(Color.track.opacity(0.15))
                LineMark(x: .value("Distance", point.kilometres), y: .value("Altitude", point.altitude),
                         series: .value("Part", point.segment))
                    .foregroundStyle(Color.track)
            }
            .chartYScale(domain: (low - padding)...(high + padding))
            .chartXAxisLabel("km")
            .chartYAxisLabel("m")
            .frame(height: 180)
            .accessibilityLabel(Text("Elevation profile from \(RideFormat.altitude(low)) to \(RideFormat.altitude(high))"))
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
