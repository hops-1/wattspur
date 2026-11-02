import MapKit
import SwiftUI
import WattspurCore

/// The track of a ride on an Apple map, one line per recording. Without `interactive` it is a
/// picture: no panning or zooming, and every tap goes to the tile around it.
struct RouteMap: View {
    var route: RideExchange.Route
    var interactive = false

    var body: some View {
        Map(initialPosition: .rect(Self.rect(for: segments.flatMap { $0 })),
            interactionModes: interactive ? .all : []) {
            ForEach(segments.indices, id: \.self) { index in
                MapPolyline(coordinates: segments[index])
                    .stroke(Color.track, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
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

/// The map of a ride once its route is loaded; a quiet placeholder until then or without GPS.
struct RideMap: View {
    @Environment(PhoneLibrary.self) private var library
    var ride: RideExchange.Ride
    /// For the sample ride, whose route is not in the folder.
    var route: RideExchange.Route?
    var interactive = false
    @State private var loaded: RideExchange.Route?
    @State private var finished = false

    var body: some View {
        Group {
            if let shown = route ?? loaded, shown.pointCount > 0 {
                RouteMap(route: shown, interactive: interactive)
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
