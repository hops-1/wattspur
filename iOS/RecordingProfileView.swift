import Charts
import SwiftUI
import WattspurCore

/// The height or speed profile of the ride so far (B-277), growing while recording. One swipe away
/// from the figures, in portrait below the map and in landscape in the bar on the left. The choice
/// between height and speed is remembered.
struct RecordingProfileView: View {
    var recording: RideRecording
    var compact = false
    @AppStorage(PhoneSettingsKey.recordingProfileKind) private var kind: RecordingProfile.Kind = .elevation

    var body: some View {
        // Worked out once per drawing, from at most 150 points (RecordingProfile), so a long ride
        // stays as light as a short one.
        let points = RecordingProfile.points(recording, kind: kind)
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Picker("Profile", selection: $kind) {
                Text("Altitude").tag(RecordingProfile.Kind.elevation)
                Text("Speed").tag(RecordingProfile.Kind.speed)
            }
            .pickerStyle(.segmented)
            .controlSize(compact ? .small : .regular)
            if points.count < 2 {
                Text("The profile appears after the first few hundred metres.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                chart(points)
            }
        }
    }

    /// One point of the chart: km and metres or km/h.
    private struct Plotted: Identifiable {
        let km: Double
        let value: Double
        var id: Double { km }
    }

    private func chart(_ points: [RecordingProfile.Point]) -> some View {
        let plotted = points.map { Plotted(km: $0.distance / 1000, value: value(of: $0)) }
        let domain = Self.domain(plotted.map(\.value), speed: kind == .speed)
        return Chart(plotted) { point in
            AreaMark(x: .value("Distance", point.km), yStart: .value("Base", domain.lowerBound),
                     yEnd: .value("Value", point.value))
                .foregroundStyle(Color.track.opacity(0.18))
            LineMark(x: .value("Distance", point.km), y: .value("Value", point.value))
                .foregroundStyle(Color.track)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: domain)
        .chartXAxisLabel(position: .bottom, alignment: .trailing) { Text(verbatim: "km") }
        .chartYAxisLabel { Text(verbatim: kind == .elevation ? "m" : "km/h") }
        .accessibilityLabel(Text(kind == .elevation ? "Altitude profile of the ride so far" : "Speed profile of the ride so far"))
    }

    /// Some room above and below, and at least 20 m or 10 km/h, so a flat ride stays flat; speed from 0.
    private static func domain(_ values: [Double], speed: Bool) -> ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let span = max(high - low, speed ? 10 : 20)
        let bottom = speed ? 0 : low - span * 0.1
        return bottom...(max(high, bottom + span) + span * 0.1)
    }

    /// Metres, or km/h for speed.
    private func value(of point: RecordingProfile.Point) -> Double {
        kind == .speed ? point.value * 3.6 : point.value
    }
}

