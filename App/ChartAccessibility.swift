import Accessibility
import Foundation
import SwiftUI
import WattspurKit

// Audio Graphs (NFR-16): VoiceOver can play a chart as a rising and falling tone
// and step through its data points. Each chart hands VoiceOver a description of
// its axes and series through `.accessibilityChartDescriptor(_:)`.

/// A ride chart over distance: elevation, speed, cadence or power (TOUR-04).
struct RideChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let unit: String
    let points: [ChartPoint]
    var axis: ChartAxis = .distance
    let value: KeyPath<ChartPoint, Double?>

    /// About 200 points are plenty to hear the shape and keep stepping through them bearable.
    private static let maxPoints = 200

    func makeChartDescriptor() -> AXChartDescriptor {
        let step = max(1, points.count / Self.maxPoints)
        let samples = stride(from: 0, to: points.count, by: step).compactMap { i -> (Double, Double)? in
            points[i][keyPath: value].map { (axis == .distance ? points[i].distanceKm : points[i].seconds / 60, $0) }
        }
        let ys = samples.map(\.1)
        let unit = unit
        let last = points.last.map { axis == .distance ? $0.distanceKm : $0.seconds / 60 } ?? 1
        let xAxis = AXNumericDataAxisDescriptor(
            title: axis == .distance ? String(localized: "Distance") : String(localized: "Time"),
            range: 0...max(last, 0.1),
            gridlinePositions: []
        ) {
            axis == .distance ? "\($0.formatted(.number.precision(.fractionLength(1)))) km"
                : String(localized: "\(Int($0.rounded())) min")
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: (ys.min() ?? 0)...max(ys.max() ?? 1, (ys.min() ?? 0) + 1),
            gridlinePositions: []
        ) { "\($0.formatted(.number.precision(.fractionLength(0)))) \(unit)" }
        let series = AXDataSeriesDescriptor(
            name: title, isContinuous: true,
            dataPoints: samples.map { AXDataPoint(x: $0.0, y: $0.1) }
        )
        return AXChartDescriptor(
            title: title,
            summary: axis == .distance ? String(localized: "\(title) over the distance of the ride")
                : String(localized: "\(title) over the time of the ride"),
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// The bar chart per day, week, month or year (AGG-04).
struct BarChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let unit: String
    /// Bar label and value, oldest first.
    let bars: [(label: String, value: Double, formatted: String)]

    func makeChartDescriptor() -> AXChartDescriptor {
        let unit = unit
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Period"),
            categoryOrder: bars.map(\.label)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: 0...max(bars.map(\.value).max() ?? 1, 1),
            gridlinePositions: []
        ) { "\($0.formatted(.number.precision(.fractionLength(0)))) \(unit)" }
        let series = AXDataSeriesDescriptor(
            name: title, isContinuous: false,
            dataPoints: bars.map { AXDataPoint(x: $0.label, y: $0.value, label: $0.formatted) }
        )
        return AXChartDescriptor(
            title: title, summary: nil,
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// A trend chart: the value of each ride and the moving average (TREND-01).
struct TrendChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let unit: String
    let points: [TrendPoint]
    /// Speed is stored in m/s and shown in km/h.
    let factor: Double
    let digits: Int

    func makeChartDescriptor() -> AXChartDescriptor {
        let unit = unit
        let digits = digits
        let dates = points.map { $0.date.timeIntervalSinceReferenceDate }
        let values = points.flatMap { [$0.value * factor, $0.movingAverage * factor] }
        let first = dates.first ?? 0
        let xAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Date"),
            range: first...max(dates.last ?? 1, first + 1),
            gridlinePositions: []
        ) { Date(timeIntervalSinceReferenceDate: $0).formatted(date: .abbreviated, time: .omitted) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: (values.min() ?? 0)...max(values.max() ?? 1, (values.min() ?? 0) + 1),
            gridlinePositions: []
        ) { "\($0.formatted(.number.precision(.fractionLength(digits)))) \(unit)" }
        let perRide = AXDataSeriesDescriptor(
            name: String(localized: "Per ride"), isContinuous: false,
            dataPoints: points.map { AXDataPoint(x: $0.date.timeIntervalSinceReferenceDate, y: $0.value * factor) }
        )
        let average = AXDataSeriesDescriptor(
            name: String(localized: "5-ride average"), isContinuous: true,
            dataPoints: points.map { AXDataPoint(x: $0.date.timeIntervalSinceReferenceDate, y: $0.movingAverage * factor) }
        )
        return AXChartDescriptor(
            title: title, summary: nil,
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [perRide, average]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// Charts of 2–4 rides on top of each other (CMP-05): one series per ride.
struct ComparisonChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let unit: String
    let series: [(name: String, points: [ChartPoint])]
    let value: KeyPath<ChartPoint, Double?>

    private static let maxPoints = 150

    func makeChartDescriptor() -> AXChartDescriptor {
        let value = value
        let sampled = series.map { s -> (String, [(Double, Double)]) in
            let step = max(1, s.points.count / Self.maxPoints)
            let values = stride(from: 0, to: s.points.count, by: step).compactMap { i -> (Double, Double)? in
                s.points[i][keyPath: value].map { (s.points[i].distanceKm, $0) }
            }
            return (s.name, values)
        }
        let ys = sampled.flatMap { $0.1.map(\.1) }
        let xs = sampled.flatMap { $0.1.map(\.0) }
        let unit = unit
        let xAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Distance"),
            range: 0...max(xs.max() ?? 1, 0.1),
            gridlinePositions: []
        ) { "\($0.formatted(.number.precision(.fractionLength(1)))) km" }
        let yAxis = AXNumericDataAxisDescriptor(
            title: title,
            range: (ys.min() ?? 0)...max(ys.max() ?? 1, (ys.min() ?? 0) + 1),
            gridlinePositions: []
        ) { "\($0.formatted(.number.precision(.fractionLength(0)))) \(unit)" }
        return AXChartDescriptor(
            title: title,
            summary: String(localized: "\(title) of the compared rides over the distance"),
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [],
            series: sampled.map { name, values in
                AXDataSeriesDescriptor(name: name, isContinuous: true,
                                       dataPoints: values.map { AXDataPoint(x: $0.0, y: $0.1) })
            }
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}
