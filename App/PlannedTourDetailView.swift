import Charts
import MapKit
import SwiftData
import SwiftUI
import WattspurKit

/// One planned tour (B-385, design B-371 “Mac”): the map with the blue line on top, below it the
/// name with the figures, the elevation profile and the actions rename, share GPX and trash.
struct PlannedTourDetailView: View {
    let route: PlannedRoute

    @Environment(RideLibrary.self) private var sharedLibrary
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var scheme
    private var library: RideLibrary { sharedLibrary.using(undoManager) }

    /// Read once per tour in `.task`, not in `body` (rule 16).
    @State private var loaded: Loaded?
    @State private var renaming = false
    @State private var newName = ""

    private struct Loaded {
        let id: UUID
        let coordinates: [CLLocationCoordinate2D]
        let profile: [ProfilePoint]
    }

    struct ProfilePoint: Identifiable {
        let id: Int
        let km: Double
        let altitude: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            map
                .frame(maxWidth: .infinity)
                .frame(minHeight: 260, maxHeight: .infinity)
            info
        }
        .task(id: route.id) { load() }
        .alert("Rename Tour", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Rename") { library.rename(route, to: newName) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var map: some View {
        if let loaded, loaded.id == route.id, let start = loaded.coordinates.first {
            Map(initialPosition: .automatic) {
                MapPolyline(coordinates: loaded.coordinates)
                    .stroke(PlannedTourColor.line(scheme), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                Annotation(String(localized: "Start"), coordinate: start, anchor: .center) {
                    Circle()
                        .fill(Color(red: 0x2E / 255, green: 0x9E / 255, blue: 0x4F / 255))
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 12, height: 12)
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapZoomStepper(); MapCompass(); MapScaleView() }
            // A new tour starts with its whole line in view.
            .id(route.id)
            .accessibilityLabel(Text("Map of the planned tour"))
        } else {
            Rectangle().fill(.quaternary)
        }
    }

    // MARK: - Name, figures, profile, actions

    private var info: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: route.name)
                        .font(.title2.bold())
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Text(verbatim: PlannedTourText.figures(of: route))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                actions
            }
            profile
            Text("Navigation comes with a later version, on the iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                newName = route.name
                renaming = true
            } label: {
                Label("Rename…", systemImage: "pencil")
            }
            if let file = PlannedTourFile(route: route) {
                ShareLink(item: file, preview: SharePreview(file.fileName)) {
                    Label("Share GPX", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) {
                library.moveToTrash([route])
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .help(Text("Rename, share or move the tour to the trash"))
    }

    @ViewBuilder
    private var profile: some View {
        let points = loaded?.id == route.id ? loaded?.profile ?? [] : []
        let line = PlannedTourColor.line(scheme)
        Group {
            if points.count >= 2 {
                Chart(points) { point in
                    AreaMark(x: .value("Distance", point.km), yStart: .value("Elevation", lowest(points)), yEnd: .value("Elevation", point.altitude))
                        .foregroundStyle(line.opacity(scheme == .dark ? 0.25 : 0.15))
                    LineMark(x: .value("Distance", point.km), y: .value("Elevation", point.altitude))
                        .foregroundStyle(line)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartYScale(domain: lowest(points)...max(highest(points), lowest(points) + 20))
                .chartXScale(domain: 0...max(points.last?.km ?? 1, 0.1))
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { if let km = value.as(Double.self) { Text(verbatim: "\(km.formatted()) km") } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel { if let m = value.as(Double.self) { Text(verbatim: "\(Int(m)) m") } }
                    }
                }
                .frame(height: 110)
                .accessibilityLabel(Text("Elevation profile"))
            } else {
                Text("This tour has no elevation data.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func lowest(_ points: [ProfilePoint]) -> Double {
        ((points.map(\.altitude).min() ?? 0) / 10).rounded(.down) * 10
    }

    private func highest(_ points: [ProfilePoint]) -> Double {
        ((points.map(\.altitude).max() ?? 0) / 10).rounded(.up) * 10
    }

    // MARK: - Loading

    private func load() {
        let points = route.points
        loaded = Loaded(id: route.id,
                        coordinates: points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                        profile: Self.profile(of: points))
    }

    /// Height over distance, at most about 400 points for the chart.
    static func profile(of points: [PlannedTour.Point]) -> [ProfilePoint] {
        var result: [ProfilePoint] = []
        var metres = 0.0
        let step = max(1, points.count / 400)
        for (index, point) in points.enumerated() {
            if index > 0 { metres += distance(points[index - 1], point) }
            guard index % step == 0 || index == points.count - 1, let altitude = point.altitude else { continue }
            result.append(ProfilePoint(id: index, km: metres / 1000, altitude: altitude))
        }
        return result
    }

    /// Great-circle distance in metres.
    private static func distance(_ a: PlannedTour.Point, _ b: PlannedTour.Point) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
