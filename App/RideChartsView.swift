import Charts
import SwiftUI
import WattspurKit

/// The four charts over distance: elevation, speed, cadence, power (B-019, TOUR-04).
/// In a wide window they are stacked; the carousel for narrow windows follows (TOUR-11).
struct RideChartsView: View {
    let ride: Ride
    /// Points for `axis`: `RideSeries.chartPoints(from:axis:)`.
    let points: [ChartPoint]
    var axis: ChartAxis = .distance
    /// Where the parts of a merged ride meet: a fine line in each chart (B-131).
    var joins: [RideMerge.Join] = []

    /// Where the joins lie on the x axis: kilometres, or minutes. Over time a pause between two parts
    /// is bracketed by two lines.
    private var joinX: [Double] {
        switch axis {
        case .distance:
            return joins.map { $0.distance / 1000 }
        case .time:
            return joins.flatMap { join in
                join.time - join.previousEndTime > 5 ? [join.previousEndTime / 60, join.time / 60] : [join.time / 60]
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if hasData(\.altitude) {
                ChartCard(
                    title: "Elevation", color: .metricElevation, points: points, axis: axis, joins: joinX, value: \.altitude, fixValue: \.altitude,
                    figures: [("Ascent", "\(ride.totalAscent.map(String.init) ?? "–") m"),
                              ("Descent", "\(ride.totalDescent.map(String.init) ?? "–") m")],
                    unit: "m", yDomain: niceDomain(points.compactMap(\.altitude), padding: 20)
                )
            } else {
                NoDataCard(title: "Elevation", message: "This file contains no elevation data.")
            }
            ChartCard(
                title: "Speed", color: .metricSpeed, points: points, axis: axis, joins: joinX, value: \.speedKmh, fixValue: \.speedKmh,
                figures: [("Max", RideFormat.speed(ride.maxSpeed)), ("Avg", RideFormat.speed(ride.averageSpeed))],
                unit: "km/h", yDomain: 0...max(10, (ride.maxSpeed ?? 0) * 3.6 * 1.05)
            )
            if hasData(\.cadence) {
                ChartCard(
                    title: "Cadence", color: .metricCadence, points: points, axis: axis, joins: joinX, value: \.cadence, fixValue: \.cadence,
                    figures: [("Max", "\(ride.maxCadence.map(String.init) ?? "–") \(String(localized: "rpm"))"),
                              ("Avg", "\(ride.averageCadence.map(String.init) ?? "–") \(String(localized: "rpm"))")],
                    unit: String(localized: "rpm"), yDomain: 0...max(10, Double(ride.maxCadence ?? 0) * 1.05)
                )
            } else {
                NoDataCard(title: "Cadence", message: "This file contains no cadence data.")
            }
            if hasData(\.power) {
                ChartCard(
                    title: "Power", color: .metricPower, points: points, axis: axis, joins: joinX, value: \.power, fixValue: \.power,
                    figures: [("Max", "\(ride.maxPower.map(String.init) ?? "–") W"),
                              ("Avg", "\(ride.averagePower.map(String.init) ?? "–") W")],
                    unit: "W", yDomain: 0...max(10, Double(ride.maxPower ?? 0) * 1.05)
                )
            } else {
                NoDataCard(title: "Power", message: "This file contains no power data.")
            }
        }
    }

    /// Whether the series has a value; the charts are drawn as before while the points are still being prepared.
    private func hasData(_ value: KeyPath<ChartPoint, Double?>) -> Bool {
        points.isEmpty || points.contains { $0[keyPath: value] != nil }
    }

    private func niceDomain(_ values: [Double], padding: Double) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        return (lo - padding)...(hi + padding)
    }
}

/// A chart the file has no data for (B-145): a GPX file often has no power, cadence or elevation.
private struct NoDataCard: View {
    let title: LocalizedStringResource
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            HStack(spacing: 8) {
                Image(systemName: "ellipsis").foregroundStyle(.secondary).accessibilityHidden(true)
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ChartCard: View {
    let title: LocalizedStringResource
    let color: Color
    let points: [ChartPoint]
    let axis: ChartAxis
    /// Where the parts of a merged ride meet, in the unit of the x axis.
    let joins: [Double]
    let value: KeyPath<ChartPoint, Double?>
    /// The same value on a `RideTrack.Fix`, for the spot of the coupling (B-062).
    let fixValue: KeyPath<RideTrack.Fix, Double?>
    let figures: [(LocalizedStringKey, String)]
    let unit: String
    let yDomain: ClosedRange<Double>

    /// Kilometres or minutes since the start.
    private func x(_ point: ChartPoint) -> Double {
        axis == .distance ? point.distanceKm : point.seconds / 60
    }

    /// Not there in the PDF: the coupling with the map is for the screen only (B-062).
    @Environment(RideCursor.self) private var cursor: RideCursor?

    /// Where a spot lies on the x axis.
    private func x(_ fix: RideTrack.Fix) -> Double {
        axis == .distance ? fix.distanceKm : fix.time / 60
    }

    private var maxX: Double { points.last.map(x) ?? 1 }

    /// A step in minutes that gives about five labels.
    private var minuteStep: Double {
        [1.0, 2, 5, 10, 15, 30, 60, 120, 180, 240, 360].first { maxX / $0 <= 6 } ?? 720
    }

    /// "12.3 km · 24.1 km/h" for the spot of the coupling, with a pin while it is held.
    private func readout(_ fix: RideTrack.Fix) -> some View {
        let position = axis == .distance ? "\(fix.distanceKm.formatted(.number.precision(.fractionLength(1)))) km"
                                         : Self.clock(fix.time / 60)
        let digits = unit == "km/h" ? 1 : 0
        let text = fix[keyPath: fixValue].map { "\(position) · \($0.formatted(.number.precision(.fractionLength(digits)))) \(unit)" } ?? position
        return HStack(spacing: 4) {
            if cursor?.isHeld == true { Image(systemName: "pin.fill").imageScale(.small) }
            Text(verbatim: text).monospacedDigit()
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }

    /// "1:05" for 65 minutes.
    private static func clock(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 28) {
                Text(title).font(.title3.bold())
                if let fix = cursor?.current { readout(fix) }
                Spacer()
                ForEach(figures.indices, id: \.self) { i in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(figures[i].0).font(.caption).foregroundStyle(.secondary)
                        Text(verbatim: figures[i].1).font(.title3.weight(.semibold)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Chart {
                ForEach(points) { point in
                    if let y = point[keyPath: value] {
                        // The area starts at the bottom of the axis, not at zero, so it
                        // never reaches below the plot when the axis does not start at 0.
                        AreaMark(
                            x: .value("Distance", x(point)),
                            yStart: .value(unit, yDomain.lowerBound),
                            yEnd: .value(unit, y),
                            series: .value("Segment", point.segment)
                        )
                        .foregroundStyle(color.opacity(0.18))
                        .interpolationMethod(.monotone)
                        LineMark(x: .value("Distance", x(point)), y: .value(unit, y), series: .value("Segment", point.segment))
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: 1.6))
                            .interpolationMethod(.monotone)
                    }
                }
                ForEach(joins, id: \.self) { km in
                    RuleMark(x: .value("Distance", km))
                        .foregroundStyle(color.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
                if let fix = cursor?.current {
                    RuleMark(x: .value("Distance", x(fix)))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: cursor?.isHeld == true ? [] : [4, 3]))
                    if let y = fix[keyPath: fixValue] {
                        PointMark(x: .value("Distance", x(fix)), y: .value(unit, y))
                            .symbolSize(50)
                            .foregroundStyle(color)
                    }
                }
            }
            .chartOverlay { proxy in
                if let cursor {
                    GeometryReader { geometry in
                        let plot = proxy.plotFrame.map { geometry[$0] } ?? .zero
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    if let value: Double = proxy.value(atX: location.x - plot.minX) {
                                        cursor.hover(atX: value, axis: axis)
                                    }
                                case .ended:
                                    cursor.endHover()
                                }
                            }
                            .onTapGesture { cursor.toggleHold() }
                            .accessibilityHidden(true)
                    }
                }
            }
            .chartXScale(domain: 0...maxX)
            .chartYScale(domain: yDomain)
            .chartPlotStyle { $0.clipped() }
            .chartXAxis {
                AxisMarks(values: axis == .distance ? AxisMarkValues.automatic(desiredCount: 5)
                                                    : .stride(by: minuteStep)) { mark in
                    AxisGridLine()
                    AxisValueLabel {
                        if let value = mark.as(Double.self) {
                            if axis == .distance {
                                Text(verbatim: "\(value.formatted(.number.precision(.fractionLength(0)))) km")
                            } else {
                                Text(verbatim: Self.clock(value))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { mark in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    AxisValueLabel {
                        if let v = mark.as(Double.self) { Text(verbatim: "\(v.formatted(.number.precision(.fractionLength(0)))) \(unit)") }
                    }
                }
            }
            .frame(height: 170)
            .accessibilityLabel(Text(title))
            .accessibilityChartDescriptor(
                RideChartDescriptor(title: String(localized: title), unit: unit, points: points, axis: axis, value: value)
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
    }
}

extension Color {
    /// Metric colours from the mockup, with lighter variants for dark mode.
    static let metricElevation = Color.adaptive(light: 0x4F7A5A, dark: 0x7FB58A)
    static let metricSpeed = Color.adaptive(light: 0x0A6ED1, dark: 0x4DA3FF)
    static let metricCadence = Color.adaptive(light: 0x7A4FC9, dark: 0xA98BEF)
    static let metricPower = Color.adaptive(light: 0xC2410C, dark: 0xFF8A4C)
    /// Bars that are not picked: at least 3:1 against the window background (NFR-16).
    static let chartInactive = Color.adaptive(light: 0x86868B, dark: 0x7C7C80)

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
        #else
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
        #endif
    }
}
