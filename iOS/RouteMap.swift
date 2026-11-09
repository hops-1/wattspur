import MapKit
import SwiftUI
import WattspurCore
import WattspurMap

/// The track of a ride on the map, one line per recording, in the chosen map style (B-226).
/// Without `interactive` it is a picture: no panning or zooming, and every tap goes to the tile around it.
struct RouteMap: View {
    var route: RideExchange.Route
    var interactive = false
    /// The spot under the finger on the chart (B-221), as a dot on the track.
    var marker: CLLocationCoordinate2D?
    /// The track by lean angle (B-246); drawn instead of the plain line when there is one.
    var leanStretches: [RideMotion.LeanStretch] = []
    /// The track by road surface (B-248); the detail map switches between the two.
    var surfaceStretches: [RideMotion.SurfaceStretch] = []
    /// Which colouring the detail map shows, remembered.
    @AppStorage(PhoneSettingsKey.trackColouring) private var colouring: TrackColouring = .lean
    /// The track by height (B-283), worked out from the route once per route; every ride with heights has it.
    @State private var elevation: RouteElevation.Result?
    /// Apple's map or an OpenStreetMap style (B-226), the same for every map; remembered.
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard

    /// The colourings this ride has.
    private var available: [TrackColouring] {
        (leanStretches.isEmpty ? [] : [.lean]) + (surfaceStretches.isEmpty ? [] : [.surface])
            + (elevation == nil ? [] : [.elevation])
    }

    /// The colouring shown: the chosen one if the ride has it, else lean angle or surface. The height
    /// only when chosen, so a ride without motion keeps its plain line unless asked (B-283).
    private var shown: TrackColouring? {
        if colouring == .plain { return nil }
        if available.contains(colouring) { return colouring }
        return available.first { $0 != .elevation }
    }

    /// The colouring for the map's overlay.
    private var routeColouring: RouteColouring {
        switch shown {
        case .lean: .lean(leanStretches)
        case .surface: .surface(surfaceStretches)
        case .elevation: .elevation(elevation?.stretches ?? [])
        case nil, .plain?: .plain
        }
    }

    var body: some View {
        PhoneMapView(mapType: mapType, segments: segments, colouring: routeColouring, marker: marker,
                     interactive: interactive, area: Self.rect(for: segments.flatMap { $0 }))
        .allowsHitTesting(interactive)
        // MapKit's "Legal" link still takes taps despite allowsHitTesting(false) and opens
        // Safari; a clear layer on top catches them, so they reach the tile (the attribution
        // stays visible, and the detail's map keeps the working link).
        .overlay {
            if !interactive {
                Color.clear.contentShape(.rect)
            }
        }
        .overlay(alignment: .bottomLeading) {
            switch shown {
            case .lean: LeanLegend().padding(8)
            case .surface: SurfaceLegend().padding(8)
            case .elevation: elevation.map { ElevationLegend(scale: $0.scale).padding(8) }
            case nil, .plain?: EmptyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            // The map style on the detail map (B-226); the same choice as under More.
            if interactive {
                MapTypeMenu(mapType: $mapType)
                    .padding(8)
            }
        }
        .overlay(alignment: .topLeading) {
            // A switch on the detail map between the colourings the ride has (B-248, B-283).
            if interactive, !available.isEmpty {
                Picker("Track Colour", selection: Binding(get: { shown ?? .plain }, set: { colouring = $0 })) {
                    ForEach(available + [.plain], id: \.self) { option in
                        Text(option.name).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .padding(8)
            }
        }
        .task(id: route.identity) {
            elevation = RouteElevation.stretches(route)
        }
        .accessibilityHidden(!interactive)
    }

    private var segments: [[CLLocationCoordinate2D]] {
        route.segments.map { segment in
            zip(segment.latitude, segment.longitude).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
        }
    }

    /// The track's bounding box with a margin, so the line does not touch the edges.
    static func rect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        let points = coordinates.map(MKMapPoint.init)
        guard let first = points.first else { return .world }
        var rect = MKMapRect(origin: first, size: MKMapSize(width: 0, height: 0))
        for point in points.dropFirst() {
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        let margin = max(rect.width, rect.height) * 0.15 + 200
        return rect.insetBy(dx: -margin, dy: -margin)
    }
}

/// Chooses the map style (B-226): Apple's three and the OpenStreetMap styles, as on the Mac.
struct MapTypeMenu: View {
    @Binding var mapType: RideMapType

    var body: some View {
        Menu {
            Picker("Map Style", selection: $mapType) {
                Section("Apple") {
                    ForEach(RideMapType.apple) { Text($0.label).tag($0) }
                }
                Section("OpenStreetMap") {
                    ForEach(RideMapType.openStreetMapStyles) { Text($0.label).tag($0) }
                }
            }
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.body)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("Map Style"))
    }
}

/// What the detail map colours the track by (B-248, B-283). Stored: only add cases.
enum TrackColouring: String {
    case lean, surface, elevation
    /// One colour, without a colouring.
    case plain

    var name: LocalizedStringKey {
        switch self {
        case .lean: "Lean Angle"
        case .surface: "Surface"
        case .elevation: "Route Elevation"
        case .plain: "Plain"
        }
    }
}

/// What the colours of the track by height mean (B-283): blue at the lowest point, red at the highest.
struct ElevationLegend: View {
    let scale: RouteElevation.Scale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Route Elevation").font(.caption2.weight(.semibold))
            HStack(spacing: 6) {
                Text(RideFormat.altitude(scale.lowest)).font(.caption2).monospacedDigit()
                Capsule()
                    .fill(LinearGradient(colors: (0..<RouteElevation.levels).map(Color.elevation), startPoint: .leading, endPoint: .trailing))
                    .frame(width: 50, height: 4)
                Text(RideFormat.altitude(scale.highest)).font(.caption2).monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Track coloured by elevation, from blue at \(RideFormat.altitude(scale.lowest)) to red at \(RideFormat.altitude(scale.highest))"))
    }
}

/// What the colours of the track by road surface mean (B-248).
private struct SurfaceLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Surface").font(.caption2.weight(.semibold))
            HStack(spacing: 6) {
                ForEach(RideMotion.SurfaceBand.allCases, id: \.self) { band in
                    HStack(spacing: 2) {
                        Capsule().fill(Color.surface(band)).frame(width: 10, height: 4)
                        Text(band.name).font(.caption2)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Track coloured by road surface: grey smooth, yellow uneven, brown rough"))
    }
}

extension RideMotion.SurfaceBand {
    /// "Smooth", "Uneven", "Rough".
    var name: LocalizedStringKey {
        switch self {
        case .smooth: "Smooth"
        case .uneven: "Uneven"
        case .rough: "Rough"
        }
    }
}

/// What the colours of the track by lean angle mean (B-246).
private struct LeanLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lean Angle").font(.caption2.weight(.semibold))
            HStack(spacing: 6) {
                ForEach(RideMotion.LeanBand.allCases, id: \.self) { band in
                    HStack(spacing: 2) {
                        Capsule().fill(Color.lean(band)).frame(width: 10, height: 4)
                        Text(verbatim: band == .extreme ? "40°+" : "\(Int(band.lowerBound))°")
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
        .accessibilityLabel(Text("Track coloured by lean angle, from green upright to purple at 40° and more"))
    }
}

/// The map of a ride once its route is loaded; a quiet placeholder until then or without GPS.
struct RideMap: View {
    @Environment(PhoneLibrary.self) private var library
    var ride: RideExchange.Ride
    /// For the sample ride, whose route is not in the store.
    var route: RideExchange.Route?
    var interactive = false
    var marker: CLLocationCoordinate2D?
    var leanStretches: [RideMotion.LeanStretch] = []
    var surfaceStretches: [RideMotion.SurfaceStretch] = []
    @State private var loaded: RideExchange.Route?
    @State private var finished = false

    var body: some View {
        Group {
            if let shown = route ?? loaded, shown.pointCount > 0 {
                RouteMap(route: shown, interactive: interactive, marker: marker, leanStretches: leanStretches,
                         surfaceStretches: surfaceStretches)
                    // A fresh map for each route: `Map(initialPosition:)` frames the track only once,
                    // so the tile "Last Ride" kept the view of the ride before (B-275), and of the
                    // recording after the Mac brought its Bosch file (B-279).
                    .id(shown.identity)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        if finished || ride.routeFile == nil {
                            Label("No GPS track", systemImage: "location.slash")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: ride.routeFile) {
            guard route == nil else { return }
            // Another ride in the same place (a new last ride): not the old track until the new one is loaded.
            if loaded?.rideID != ride.id { loaded = nil }
            loaded = await library.route(for: ride)
            finished = true
        }
    }
}
