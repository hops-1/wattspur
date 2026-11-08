import MapKit
import SwiftUI
import WattspurCore

/// The track of a ride on an Apple map, one line per recording. Without `interactive` it is a
/// picture: no panning or zooming, and every tap goes to the tile around it.
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

    /// A coloured piece of the track.
    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let coordinates: [CLLocationCoordinate2D]
    }

    private func pieces<Band>(_ stretches: [RideMotion.Stretch<Band>], _ color: (Band) -> Color) -> [Piece] {
        stretches.enumerated().map { index, stretch in
            Piece(id: index, color: color(stretch.band),
                  coordinates: zip(stretch.latitude, stretch.longitude).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) })
        }
    }

    /// The colouring shown: the chosen one if the ride has it, else the other.
    private var shown: TrackColouring? {
        switch (leanStretches.isEmpty, surfaceStretches.isEmpty) {
        case (true, true): nil
        case (false, true): .lean
        case (true, false): .surface
        case (false, false): colouring
        }
    }

    var body: some View {
        Map(initialPosition: .rect(Self.rect(for: segments.flatMap { $0 })),
            interactionModes: interactive ? .all : []) {
            switch shown {
            case .lean:
                ForEach(pieces(leanStretches, Color.lean)) { piece in
                    MapPolyline(coordinates: piece.coordinates)
                        .stroke(piece.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            case .surface:
                ForEach(pieces(surfaceStretches, Color.surface)) { piece in
                    MapPolyline(coordinates: piece.coordinates)
                        .stroke(piece.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            case nil:
                ForEach(segments.indices, id: \.self) { index in
                    MapPolyline(coordinates: segments[index])
                        .stroke(Color.track, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
            if let marker {
                Annotation("", coordinate: marker, anchor: .center) {
                    Circle()
                        .fill(Color.track)
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .accessibilityHidden(true)
                }
            }
        }
        // A fresh map for each colouring: SwiftUI's Map keeps the lines it has drawn and does not
        // take new colours for them, so a switch between lean and surface showed the old ones.
        .id(shown)
        .mapControlVisibility(interactive ? .automatic : .hidden)
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
            case nil: EmptyView()
            }
        }
        .overlay(alignment: .topLeading) {
            // Both colourings there: a switch on the detail map (B-248).
            if interactive, !leanStretches.isEmpty, !surfaceStretches.isEmpty {
                Picker("Track Colour", selection: $colouring) {
                    Text("Lean Angle").tag(TrackColouring.lean)
                    Text("Surface").tag(TrackColouring.surface)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .padding(8)
            }
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

/// What the detail map colours the track by (B-248).
enum TrackColouring: String {
    case lean, surface
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
    /// For the sample ride, whose route is not in the folder.
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
