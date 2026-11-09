import MapKit
import SwiftUI
import WattspurCore
import WattspurKit
import WattspurMap

/// The tab “Map” (B-227): all rides on one map, as lines or as a heat map, filtered by period and
/// bike, like the Mac's map of all rides and with its logic from the package (`MapOverview`,
/// `RidesMapStyle`, `RouteHitTest`). Tapping a route lists the rides there; one opens its detail.
struct RidesMapScreen: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLandscape) private var isLandscape
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard
    @AppStorage(PhoneSettingsKey.ridesMapMode) private var mode: RidesMapStyle.Mode = .lines
    @AppStorage(PhoneSettingsKey.ridesMapPeriod) private var period: RidePeriod = .all
    @AppStorage(PhoneSettingsKey.ridesMapBike) private var bike: BikeFilter = .all

    @State private var overview = MapOverview(rides: [])
    @State private var style: RidesMapStyle?
    /// What `style` was made from; set together with it, so the map never pairs a new key with an old style.
    @State private var styleKey = ""
    /// The rides under the finger, in the sheet; drawn in the accent colour while it is open.
    @State private var picked: PickedRides?
    /// The ride chosen in the sheet, shown in the detail.
    @State private var openedID: UUID?

    struct PickedRides: Identifiable {
        let id = UUID()
        let rides: [MapRide]
    }

    /// The bikes in the filter: only with two or more, like the ride list (`RideFilter.resolved`).
    private var bikes: [RideExchange.Bike] { library.state?.bikes ?? [] }
    private var shownBike: BikeFilter {
        guard case .bike(let id) = bike, bikes.count > 1, bikes.contains(where: { $0.id == id }) else { return .all }
        return bike
    }

    private var filter: MapFilter {
        MapFilter(interval: period.interval(), bike: shownBike)
    }

    /// Changes when the filter, the library or the appearance changes; then the rides are collected again.
    private var dataKey: String {
        "\(period.rawValue)|\(shownBike.rawValue)|\(library.state?.generatedAt.timeIntervalSince1970 ?? 0)|\(library.state?.rides.count ?? 0)"
    }

    var body: some View {
        ZStack {
            if let style {
                RidesMapRepresentable(style: style, styleKey: styleKey, mapType: mapType,
                                      fitKey: overview.rides.map(\.id)) { coordinate, radius in
                    pick(at: coordinate, radius: radius)
                }
                .ignoresSafeArea(edges: isLandscape ? .all : [])
            } else {
                Rectangle().fill(.quaternary)
            }
            if style != nil, overview.rides.isEmpty {
                emptyState
            }
        }
        .overlay(alignment: .top) { controls }
        .overlay(alignment: .bottomLeading) {
            if mode == .heat, !overview.rides.isEmpty {
                HeatLegend()
                    .padding(8)
                    .padding(.leading, isLandscape ? LandscapeTabBar.height * 4 : 0)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let source = mapType.tileSource {
                TileAttribution(source: source)
                    .padding(.trailing, 6)
                    .padding(.bottom, 4)
            }
        }
        .navigationTitle("Map")
        .task(id: dataKey) { collect() }
        .onChange(of: mode) { _, _ in restyle() }
        .onChange(of: colorScheme) { _, _ in restyle() }
        .onChange(of: picked?.id) { _, _ in restyle() }
        .sheet(item: $picked) { picked in
            PickedRidesSheet(rides: picked.rides, bikes: bikes) { ride in
                self.picked = nil
                openedID = ride.id
            }
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $openedID) { id in
            if let ride = library.state?.rides.first(where: { $0.id == id }) {
                TourDetailView(ride: ride)
            }
        }
    }


    /// Collects the filtered rides; reading 1 000 overview routes is quick, so on the main thread
    /// like on the Mac (it reads the stored overview routes, not the time series).
    private func collect() {
        overview = library.mapOverview(filter: filter)
        restyle()
    }

    private func restyle() {
        let dark = colorScheme == .dark
        let accent = UIColor(Color.track).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)).cgColor
        // The rides under the finger stand out in the track colour while their list is open.
        let highlighted = Set(picked?.rides.map(\.id) ?? [])
        style = RidesMapStyle(rides: overview.rides, highlighted: [], selected: highlighted, focused: nil,
                              mode: highlighted.isEmpty ? mode : .lines, dark: dark,
                              highlightColor: { _ in accent }, highlightDash: { _ in [] }, accent: accent)
        // The map replaces its overlay only when this changes.
        styleKey = "\(dataKey)|\(mode.rawValue)|\(dark)|\(highlighted.map(\.uuidString).sorted().joined())"
    }

    private func pick(at coordinate: CLLocationCoordinate2D, radius: Double) {
        let near = RouteHitTest.rides(near: RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
                                      radius: radius, in: overview.rides)
        if !near.isEmpty { picked = PickedRides(rides: near) }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Period", selection: $period) {
                        ForEach(RidePeriod.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    Label { Text(period.label) } icon: { Image(systemName: "calendar") }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                }
                .buttonStyle(.glass)
                if bikes.count > 1 {
                    Menu {
                        Picker("Bike", selection: $bike) {
                            Text("All Bikes").tag(BikeFilter.all)
                            ForEach(bikes.filter { !$0.isArchived || BikeFilter.bike($0.id) == bike }) { bike in
                                Text(verbatim: bike.name).tag(BikeFilter.bike(bike.id))
                            }
                        }
                    } label: {
                        Label {
                            if let name = bikes.first(where: { BikeFilter.bike($0.id) == shownBike })?.name {
                                Text(verbatim: name)
                            } else {
                                Text("All Bikes")
                            }
                        } icon: { Image(systemName: "bicycle") }
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                    }
                    .buttonStyle(.glass)
                }
                Spacer(minLength: 0)
                MapTypeMenu(mapType: $mapType)
            }
            HStack {
                Picker("Display", selection: $mode) {
                    Text("Lines").tag(RidesMapStyle.Mode.lines)
                    Text("Heat Map").tag(RidesMapStyle.Mode.heat)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer(minLength: 0)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.leading, isLandscape ? 8 : 0)
    }

    /// “84 rides · 1 520 km”, and how many have no GPS.
    private var summary: String {
        let distance = overview.rides.reduce(0) { $0 + $1.figures.distance }
        var text = String(localized: "\(overview.rides.count) rides · \(RideFormat.distance(distance))")
        if overview.withoutGPS > 0 { text += " · " + String(localized: "\(overview.withoutGPS) without GPS") }
        return text
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Rides on the Map", systemImage: "map")
        } description: {
            Text("Choose another period or bike, or record a ride.")
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding()
    }
}

/// The steps of the heat map: how many different rides passed an area (B-108).
private struct HeatLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rides per Area").font(.caption2.weight(.semibold))
            HStack(spacing: 4) {
                ForEach(DensityStep.allCases, id: \.self) { step in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(Color(cgColor: RidesMapStyle.stepColors[step] ?? CGColor(gray: 0.5, alpha: 1)))
                            .frame(width: 26, height: 6)
                        Text(verbatim: step.range.upperBound.map { $0 == step.range.lowerBound ? "\($0)" : "\(step.range.lowerBound)–\($0)" }
                             ?? "\(step.range.lowerBound)+")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Heat map: rides per area, from blue for one ride to red for 20 and more"))
    }
}

/// The rides whose route passes the tapped spot, newest first; one opens its detail.
private struct PickedRidesSheet: View {
    let rides: [MapRide]
    let bikes: [RideExchange.Bike]
    let open: (MapRide) -> Void

    var body: some View {
        NavigationStack {
            List(rides) { ride in
                Button { open(ride) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ride.name).font(.headline).foregroundStyle(.primary)
                        Text("\(RideFormat.shortDate(ride.figures.startDate, timeZone: nil)) · \(RideFormat.distance(ride.figures.distance))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Text("\(rides.count) Rides Here"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The map of all rides: an `MKMapView`, because SwiftUI's `Map` cannot draw a custom overlay; one
/// overlay for all rides keeps 1 000 rides smooth (the same as on the Mac).
private struct RidesMapRepresentable: UIViewRepresentable {
    let style: RidesMapStyle
    let styleKey: String
    let mapType: RideMapType
    /// Changes when the shown rides change; the map then fits them again.
    let fitKey: [UUID]
    /// A tap: the coordinate and 10 pt in metres at the current zoom.
    let onTap: (CLLocationCoordinate2D, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> FittingMapView {
        let map = FittingMapView()
        map.delegate = context.coordinator
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.showsCompass = false
        map.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        return map
    }

    func updateUIView(_ map: FittingMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        if coordinator.mapType != mapType {
            coordinator.mapType = mapType
            map.show(mapType, muted: true)
        }
        if coordinator.styleKey != styleKey {
            coordinator.styleKey = styleKey
            map.removeOverlays(map.drawnOverlays)
            map.addOverlay(RidesMapOverlay(style: style), level: map.drawnOverlayLevel)
        }
        if coordinator.fitKey != fitKey {
            coordinator.fitKey = fitKey
            let rect = style.boundingRect
            if !rect.isNull {
                let margin = max(rect.width, rect.height) * 0.08 + 300
                map.area = rect.insetBy(dx: -margin, dy: -margin)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var mapType: RideMapType?
        var styleKey: String?
        var fitKey: [UUID]?
        var onTap: (CLLocationCoordinate2D, Double) -> Void = { _, _ in }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let map = recognizer.view as? MKMapView else { return }
            // 10 pt of the screen, so a tap feels the same at every zoom (as on the Mac).
            let (coordinate, radius) = map.metres(across: 10, at: recognizer.location(in: map))
            onTap(coordinate, radius)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            MapRenderers.renderer(for: overlay)
        }
    }
}
