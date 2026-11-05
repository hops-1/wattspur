import Charts
import SwiftUI
import WattspurCore

/// The charts of a ride as a carousel (B-090, TOUR-11): one measurement per page, swiped left and
/// right, with dots below like in the Flow app. Only the measurements the ride has get a page.
/// The points come from the iPhone's own store (B-241); without them the detail keeps the
/// elevation profile.
struct RideChartCarousel: View {
    var ride: RideExchange.Ride
    var points: [ChartPoint]
    /// Where on the ride the finger is (B-221); the detail shows it on the map.
    var track: RideTrack
    @Binding var spot: RideTrack.Fix?
    /// Lower in landscape, where the screen is short (B-243).
    var height: CGFloat = 290
    @State private var page: ChartMeasure?

    private var measures: [ChartMeasure] { ChartMeasure.available(in: points) }

    var body: some View {
        TabView(selection: $page) {
            ForEach(measures) { measure in
                ChartPage(measure: measure, ride: ride, points: points, track: track, spot: $spot)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 36)
                    .tag(Optional(measure))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: measures.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: height)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .onAppear { if page == nil { page = measures.first } }
        .onChange(of: page) { spot = nil }
    }
}

/// One page: the name, two figures and the chart over the distance. Touch and hold, then move the
/// finger: a line marks the spot, the figures give way to the values there, and the map shows it.
private struct ChartPage: View {
    var measure: ChartMeasure
    var ride: RideExchange.Ride
    var points: [ChartPoint]
    var track: RideTrack
    @Binding var spot: RideTrack.Fix?
    @State private var selectedKm: Double?

    private struct Figure {
        var title: LocalizedStringResource
        var value: String
    }

    var body: some View {
        let values = points.compactMap { point in point[keyPath: measure.value].map { (km: point.distanceKm, y: $0) } }
        let domain = yDomain(values.map(\.y))
        // From the start to the end of the ride; left alone, Charts rounds up (30.7 km → 40 km).
        let lastKm = max(points.map(\.distanceKm).max() ?? 0, 0.1)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
                if let spot {
                    Text(verbatim: readout(spot))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                } else {
                    ForEach(figures.indices, id: \.self) { index in
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(figures[index].title).font(.caption).foregroundStyle(.secondary)
                            Text(verbatim: figures[index].value).font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                        .padding(.leading, 12)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Chart(values, id: \.km) { value in
                AreaMark(x: .value("Distance", value.km),
                         yStart: .value(unit, measure == .lean ? 0 : domain.lowerBound), yEnd: .value(unit, value.y))
                    .foregroundStyle(color.opacity(0.15))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Distance", value.km), y: .value(unit, value.y))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .interpolationMethod(.monotone)
                if let spot {
                    RuleMark(x: .value("Distance", spot.distanceKm))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .chartXSelection(value: $selectedKm)
            .onChange(of: selectedKm) {
                spot = selectedKm.flatMap { track.fix(atDistanceKm: $0) }
            }
            .chartXScale(domain: 0...lastKm)
            .chartYScale(domain: domain)
            .chartPlotStyle { $0.clipped() }
            .chartXAxisLabel("km")
            .chartYAxisLabel(unit)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(accessibilitySummary))
        }
    }

    private var title: LocalizedStringResource {
        switch measure {
        case .speed: "Speed"
        case .power: "Power"
        case .cadence: "Cadence"
        case .heartRate: "Heart Rate"
        case .altitude: "Elevation"
        case .lean: "Lean Angle"
        }
    }

    private var symbol: String {
        switch measure {
        case .speed: "speedometer"
        case .power: "bolt"
        case .cadence: "arrow.trianglehead.2.clockwise"
        case .heartRate: "heart"
        case .altitude: "mountain.2"
        case .lean: "angle"
        }
    }

    private var color: Color {
        switch measure {
        case .speed: .blue
        case .power: .orange
        case .cadence: .purple
        case .heartRate: .red
        case .altitude: .track
        case .lean: .indigo
        }
    }

    private var unit: String {
        switch measure {
        case .speed: "km/h"
        case .power: "W"
        case .cadence: String(localized: "rpm")
        case .heartRate: String(localized: "bpm")
        case .altitude: "m"
        case .lean: "°"
        }
    }

    /// Max and average from the ride's own figures where it has them, like on the Mac; the heart
    /// rate and the highest cadence come from the chart points.
    private var figures: [Figure] {
        let range = measure.range(in: points)
        func whole(_ value: Double?) -> String { value.map { "\(Int($0.rounded())) \(unit)" } ?? "–" }
        switch measure {
        case .speed:
            return [Figure(title: "Max", value: ride.maxSpeed.map(RideFormat.speed) ?? "–"),
                    Figure(title: "Avg", value: ride.averageSpeed.map(RideFormat.speed) ?? "–")]
        case .power:
            return [Figure(title: "Max", value: whole(ride.maxPower.map(Double.init) ?? range?.max)),
                    Figure(title: "Avg", value: whole(ride.averagePower.map(Double.init) ?? range?.mean))]
        case .cadence:
            return [Figure(title: "Max", value: whole(range?.max)),
                    Figure(title: "Avg", value: whole(ride.averageCadence.map(Double.init) ?? range?.mean))]
        case .heartRate:
            return [Figure(title: "Max", value: whole(range?.max)), Figure(title: "Avg", value: whole(range?.mean))]
        case .altitude:
            return [Figure(title: "Ascent", value: ride.totalAscent.map(RideFormat.ascent) ?? "–"),
                    Figure(title: "Descent", value: ride.totalDescent.map(RideFormat.ascent) ?? "–")]
        case .lean:
            // Positive is left; the chart keeps the strongest lean of each slice.
            let leans = points.compactMap(\.lean)
            return [Figure(title: "Left", value: RideFormat.lean(max(leans.max() ?? 0, 0))),
                    Figure(title: "Right", value: RideFormat.lean(max(-(leans.min() ?? 0), 0)))]
        }
    }

    /// "12,3 km · 24,1 km/h" for the spot under the finger.
    private func readout(_ fix: RideTrack.Fix) -> String {
        let position = "\(fix.distanceKm.formatted(.number.precision(.fractionLength(1)))) km"
        guard let value = fix[keyPath: measure.fixValue] else { return position }
        if measure == .lean {
            let side = value > 0 ? String(localized: "left") : value < 0 ? String(localized: "right") : ""
            return "\(position) · \(RideFormat.lean(value)) \(side)".trimmingCharacters(in: .whitespaces)
        }
        let digits = measure == .speed ? 1 : 0
        return "\(position) · \(value.formatted(.number.precision(.fractionLength(digits)))) \(unit)"
    }

    /// Speed, power, cadence and heart rate from zero; the altitude around its range, so a flat
    /// ride does not look like a mountain. Speed and power end at the ride's own maximum like on the
    /// Mac, so a single GPS jump in one slice does not squash the chart (it is cut off instead).
    private func yDomain(_ values: [Double]) -> ClosedRange<Double> {
        let low = values.min() ?? 0, high = values.max() ?? 1
        switch measure {
        case .altitude:
            let padding = max(10, (high - low) * 0.1)
            return (low - padding)...(high + padding)
        case .speed:
            return 0...max(10, (ride.maxSpeed.map { $0 * 3.6 } ?? high) * 1.05)
        case .power:
            return 0...max(10, (ride.maxPower.map(Double.init) ?? high) * 1.05)
        case .cadence, .heartRate:
            return 0...max(10, high * 1.05)
        case .lean:
            // Around 0, the same both ways: left above, right below.
            let reach = max(15, abs(low), abs(high)) * 1.05
            return -reach...reach
        }
    }

    private var accessibilitySummary: String {
        figures.map { figure in "\(String(localized: figure.title)) \(figure.value)" }.joined(separator: ", ")
    }
}
