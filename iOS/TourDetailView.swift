import Charts
import SwiftUI
import WattspurCore

/// The tour detail on the iPhone (B-210): the map with the track, the key figures as a grid and
/// the elevation profile. The values come finished from the Mac; the iPhone calculates nothing.
struct TourDetailView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    var ride: RideExchange.Ride
    /// For the sample ride, whose route is not in the folder.
    var route: RideExchange.Route?
    @State private var loaded: RideExchange.Route?

    private var shownRoute: RideExchange.Route? { route ?? loaded }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RideMap(ride: ride, route: route, interactive: true)
                    .frame(height: 300)
                    .clipShape(.rect(cornerRadius: 24))
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
                FigureGrid(ride: ride)
                if let shownRoute, ElevationProfile.hasAltitude(shownRoute) {
                    ElevationProfile(route: shownRoute)
                }
            }
            .padding()
        }
        .navigationTitle(ride.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only rides of the iPhone's own store, not the sample ride or the Mac's state (B-217).
            if library.canShare(ride), route == nil {
                ShareLink(item: library.sharedGPX(for: ride), preview: SharePreview(ride.name)) {
                    Label("Share GPX", systemImage: "square.and.arrow.up")
                }
            }
            if library.usesDatabase, route == nil {
                Button("Delete", systemImage: "trash") { confirmingDelete = true }
            }
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
    }
}

/// The key figures in tiles, two per row; only those the ride has.
struct FigureGrid: View {
    var ride: RideExchange.Ride

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(figures.indices, id: \.self) { index in
                let figure = figures[index]
                VStack(alignment: .leading, spacing: 4) {
                    Label(figure.title, systemImage: figure.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(figure.value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
        items.append(Item(title: "Total Time", value: RideFormat.duration(ride.elapsedTime), systemImage: "hourglass"))
        if let low = ride.minAltitude, let high = ride.maxAltitude {
            items.append(Item(title: "Altitude", value: "\(RideFormat.altitude(low)) – \(RideFormat.altitude(high))", systemImage: "mountain.2"))
        }
        return items
    }
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
