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

    var body: some View {
        Map(initialPosition: .rect(Self.rect(for: segments.flatMap { $0 })),
            interactionModes: interactive ? .all : []) {
            if leanStretches.isEmpty {
                ForEach(segments.indices, id: \.self) { index in
                    MapPolyline(coordinates: segments[index])
                        .stroke(Color.track, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            } else {
                ForEach(leanStretches.indices, id: \.self) { index in
                    let stretch = leanStretches[index]
                    MapPolyline(coordinates: zip(stretch.latitude, stretch.longitude).map {
                        CLLocationCoordinate2D(latitude: $0, longitude: $1)
                    })
                    .stroke(Color.lean(stretch.band), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
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
            if !leanStretches.isEmpty { LeanLegend().padding(8) }
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
    @State private var loaded: RideExchange.Route?
    @State private var finished = false

    var body: some View {
        Group {
            if let shown = route ?? loaded, shown.pointCount > 0 {
                RouteMap(route: shown, interactive: interactive, marker: marker, leanStretches: leanStretches)
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
            loaded = await library.route(for: ride)
            finished = true
        }
    }
}
