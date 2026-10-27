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

    private func coordinates(_ ride: Ride) -> [CLLocationCoordinate2D] {
        (routes[ride.id] ?? []).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var hasRoutes: Bool { rides.contains { (routes[$0.id]?.count ?? 0) > 1 } }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
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
        .mapStyle(mapType.style)
        .mapControls {
            MapZoomStepper()
            MapCompass()
            MapScaleView()
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
