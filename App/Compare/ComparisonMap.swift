import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

// MARK: - Map of all compared routes

/// The routes on one map, each in its column's colour and dash, with its marker at the start.
struct ComparisonMap: View {
    let rides: [Ride]
    let routes: [UUID: [RoutePoint]]
    @Binding var mapType: RideMapType
    /// The layer "Curvy roads" (B-183): the roads in the visible area, below the routes.
    @Environment(CurvyRoadsStore.self) private var curvyStore
    @AppStorage(SettingsKey.showsCurvyRoads) private var showsCurvyRoads = false
    @State private var visibleRegion: MKCoordinateRegion?

    private static let height: CGFloat = 340

    private var curvyRoads: CurvyRoadSet? { curvyStore.set(enabled: showsCurvyRoads) }

    /// The roads that touch the visible area, once it is small enough to show them.
    private var visibleRoads: [(id: Int, road: CurvyRoad)] {
        guard let roads = curvyRoads, let region = visibleRegion,
              region.span.latitudeDelta * 111_320 / Self.height <= CurvyRoads.maximumMetresPerPoint else { return [] }
        let halfLatitude = region.span.latitudeDelta / 2, halfLongitude = region.span.longitudeDelta / 2
        return roads.roads.enumerated().compactMap { index, road in
            road.intersects(minLatitude: region.center.latitude - halfLatitude, maxLatitude: region.center.latitude + halfLatitude,
                            minLongitude: region.center.longitude - halfLongitude, maxLongitude: region.center.longitude + halfLongitude)
                ? (index, road) : nil
        }
    }

    private func coordinates(_ ride: Ride) -> [CLLocationCoordinate2D] {
        (routes[ride.id] ?? []).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var hasRoutes: Bool { rides.contains { (routes[$0.id]?.count ?? 0) > 1 } }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            ForEach(visibleRoads, id: \.id) { entry in
                MapPolyline(coordinates: entry.road.coordinates2D)
                    .stroke(Color.curvyRoad(veryCurvy: entry.road.isVeryCurvy),
                            style: StrokeStyle(lineWidth: entry.road.isVeryCurvy ? 4 : 3, lineCap: .round, lineJoin: .round))
            }
            ForEach(Array(rides.enumerated()), id: \.element.id) { index, ride in
                let line = coordinates(ride)
                if line.count > 1 {
                    MapPolyline(coordinates: line)
                        .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: line)
                        .stroke(ComparisonStyle.color(index),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round,
                                                   dash: ComparisonStyle.dash(index).map { $0 * 1.6 }))
                }
                if let start = line.first {
                    Annotation(coordinate: start) {
                        Image(systemName: ComparisonStyle.marker(index))
                            .font(.system(size: 11))
                            .foregroundStyle(ComparisonStyle.color(index))
                            .padding(4)
                            .background(.white, in: Circle())
                            .shadow(radius: 1.5)
                    } label: {
                        Text(verbatim: ride.name)
                    }
                }
            }
        }
        // Fit the map again when rides are added or removed.
        .id(rides.map(\.id))
        .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
        .mapStyle(mapType.style)
        .mapControls {
            MapZoomStepper()
            MapCompass()
            MapScaleView()
        }
        .frame(height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // This map shows Apple's maps only, so only the road data needs a credit.
        .mapCredits(for: .standard, curvyRoads: curvyRoads != nil)
        .overlay(alignment: .bottomLeading) {
            if curvyRoads != nil {
                CurvyRoadsLegend()
                    .padding(.leading, 12)
                    // Above Apple's map attribution, which must stay visible.
                    .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Only Apple's maps until this map can show tiles (B-061c); an OpenStreetMap style shows the standard map.
            Picker("Map type", selection: $mapType) {
                ForEach(RideMapType.apple) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(6)
            .glassEffect(.regular, in: Capsule())
            .padding(12)
        }
        .overlay {
            if !hasRoutes && !routes.isEmpty {
                ContentUnavailableView("No GPS data", systemImage: "location.slash")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Map of the compared routes"))
    }
}
