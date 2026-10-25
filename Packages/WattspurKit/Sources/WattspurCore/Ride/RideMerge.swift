import Foundation

/// Combines several rides into one (B-095, LIST-09).
///
/// The Bosch totals of the parts stay the source of truth: sums are added up,
/// maximums carried over, and averages computed from the sums or weighted by
/// moving time. Bosch leaves zero values out of average power and cadence, so
/// the weighted average is close to, but not exactly, what Bosch would show for
/// one long ride.
public enum RideMerge {
    /// One ride to merge, with the values stored for it.
    public struct Part: Sendable, Equatable {
        public var startDate: Date
        public var summary: RideSummary
        public var samples: [RideSample]
        public var workKilojoules: Double
        public var minAltitude: Double?
        public var maxAltitude: Double?

        public init(startDate: Date, summary: RideSummary, samples: [RideSample],
                    workKilojoules: Double, minAltitude: Double? = nil, maxAltitude: Double? = nil) {
            self.startDate = startDate
            self.summary = summary
            self.samples = samples
            self.workKilojoules = workKilojoules
            self.minAltitude = minAltitude
            self.maxAltitude = maxAltitude
        }

        var endDate: Date { startDate.addingTimeInterval(summary.elapsedTime) }
    }

    public struct Result: Sendable, Equatable {
        public var startDate: Date
        public var summary: RideSummary
        public var samples: [RideSample]
        public var workKilojoules: Double
        public var minAltitude: Double?
        public var maxAltitude: Double?
    }

    public enum MergeError: Error, Equatable {
        /// Fewer than two rides.
        case tooFewRides
        /// Two rides overlap in time, so their data would count twice.
        case overlapping
        /// The sample ride does not count anywhere, so it cannot become part of a ride.
        case containsSample
    }

    /// Merges the parts in time order. A gap on the same day (in `timeZone`)
    /// counts as a pause; across days only the parts' own times count, so the
    /// time series continues right after the previous part.
    public static func merge(_ parts: [Part], timeZone: TimeZone = .current) throws(MergeError) -> Result {
        guard parts.count >= 2 else { throw .tooFewRides }
        let sorted = parts.sorted { $0.startDate < $1.startDate }
        guard !overlaps(sorted) else { throw .overlapping }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let first = sorted[0]
        var samples: [RideSample] = []
        samples.reserveCapacity(sorted.reduce(0) { $0 + $1.samples.count })
        let layout = Self.layout(of: sorted, calendar: calendar)
        for (part, place) in zip(sorted, layout) {
            for sample in part.samples {
                var s = sample
                s.time += place.time
                s.distance = sample.distance.map { $0 + place.distance }
                samples.append(s)
            }
        }
        let elapsed = (layout.last?.time ?? 0) + sorted[sorted.count - 1].summary.elapsedTime
        let distance = sorted.reduce(0) { $0 + $1.summary.distance }

        let summaries = sorted.map(\.summary)
        let timerTime = summaries.reduce(0) { $0 + $1.timerTime }
        let summary = RideSummary(
            timerTime: timerTime,
            elapsedTime: elapsed,
            distance: distance,
            averageSpeed: timerTime > 0 ? distance / timerTime : nil,
            maxSpeed: summaries.compactMap(\.maxSpeed).max(),
            averagePower: weightedAverage(summaries, \.averagePower),
            maxPower: summaries.compactMap(\.maxPower).max(),
            averageCadence: weightedAverage(summaries, \.averageCadence),
            maxCadence: summaries.compactMap(\.maxCadence).max(),
            totalAscent: sum(summaries.compactMap(\.totalAscent)),
            totalDescent: sum(summaries.compactMap(\.totalDescent))
        )
        return Result(
            startDate: first.startDate,
            summary: summary,
            samples: samples,
            workKilojoules: sorted.reduce(0) { $0 + $1.workKilojoules },
            minAltitude: sorted.compactMap(\.minAltitude).min(),
            maxAltitude: sorted.compactMap(\.maxAltitude).max()
        )
    }

    /// Where each part (in time order) starts on the merged time and distance axes.
    private static func layout(of sorted: [Part], calendar: Calendar) -> [(time: TimeInterval, distance: Double)] {
        var result: [(time: TimeInterval, distance: Double)] = []
        var elapsed: TimeInterval = 0
        var distance = 0.0
        var previous: Part?
        for part in sorted {
            // Where this part starts on the merged time axis.
            var offset = elapsed
            if let previous, calendar.isDate(previous.startDate, inSameDayAs: part.startDate) {
                offset = part.startDate.timeIntervalSince(sorted[0].startDate)
            }
            result.append((offset, distance))
            elapsed = offset + part.summary.elapsedTime
            distance += part.summary.distance
            previous = part
        }
        return result
    }

    /// A spot where two parts of a merged ride meet (B-131).
    public struct Join: Sendable, Equatable {
        /// A position at the join with the direction of travel there.
        public struct End: Sendable, Equatable {
            public var latitude: Double
            public var longitude: Double
            /// Degrees clockwise from north.
            public var heading: Double
        }

        /// Seconds on the merged time axis where the next part starts.
        public var time: TimeInterval
        /// Seconds on the merged time axis where the previous part ends; less than `time` after a pause.
        public var previousEndTime: TimeInterval
        /// Metres on the merged distance axis (the parts' distances added up).
        public var distance: Double
        /// One end where the parts meet, two (end of the earlier part, start of the next) if there is a
        /// gap in space; none without positions.
        public var ends: [End]
    }

    /// Parts closer than this count as meeting at one spot, in metres.
    public static let joinGap = 25.0
    /// The heading is taken over at least this many metres, so GPS jitter does not turn it.
    static let headingSpan = 10.0

    /// Where the parts meet, in time order; one join per transition, so `parts.count - 1`.
    public static func joins(of parts: [Part], timeZone: TimeZone = .current) -> [Join] {
        let sorted = parts.sorted { $0.startDate < $1.startDate }
        guard sorted.count >= 2 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let layout = layout(of: sorted, calendar: calendar)
        return (1..<sorted.count).map { i in
            let before = sorted[i - 1], after = sorted[i]
            let previousEnd = end(of: before.samples)
            let nextStart = start(of: after.samples)
            var ends: [Join.End] = []
            switch (previousEnd, nextStart) {
            case let (a?, b?):
                ends = RideMergeSuggestion.distance((a.latitude, a.longitude), (b.latitude, b.longitude)) <= joinGap ? [a] : [a, b]
            case let (a?, nil): ends = [a]
            case let (nil, b?): ends = [b]
            case (nil, nil): break
            }
            return Join(time: layout[i].time, previousEndTime: layout[i - 1].time + before.summary.elapsedTime,
                        distance: layout[i].distance, ends: ends)
        }
    }

    private static func end(of samples: [RideSample]) -> Join.End? {
        let positions = samples.filter { $0.latitude != nil && $0.longitude != nil }
        guard let last = positions.last else { return nil }
        guard let earlier = positions.reversed().dropFirst().first(where: { far($0, last) }) else { return nil }
        return Join.End(latitude: last.latitude!, longitude: last.longitude!, heading: bearing(from: earlier, to: last))
    }

    private static func start(of samples: [RideSample]) -> Join.End? {
        let positions = samples.filter { $0.latitude != nil && $0.longitude != nil }
        guard let first = positions.first else { return nil }
        guard let later = positions.dropFirst().first(where: { far($0, first) }) else { return nil }
        return Join.End(latitude: first.latitude!, longitude: first.longitude!, heading: bearing(from: first, to: later))
    }

    private static func far(_ a: RideSample, _ b: RideSample) -> Bool {
        RideMergeSuggestion.distance((a.latitude!, a.longitude!), (b.latitude!, b.longitude!)) >= headingSpan
    }

    /// Degrees clockwise from north, 0 ..< 360.
    private static func bearing(from a: RideSample, to b: RideSample) -> Double {
        let lat1 = a.latitude! * .pi / 180, lat2 = b.latitude! * .pi / 180
        let dLon = (b.longitude! - a.longitude!) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// `true` if any ride starts before the previous one (in time order) has ended.
    public static func overlaps(_ parts: [Part]) -> Bool {
        let sorted = parts.sorted { $0.startDate < $1.startDate }
        return zip(sorted, sorted.dropFirst()).contains { $1.startDate < $0.endDate }
    }

    /// Average weighted by moving time, over the parts that have a value.
    private static func weightedAverage(_ summaries: [RideSummary], _ value: KeyPath<RideSummary, Int?>) -> Int? {
        let weighted = summaries.compactMap { s in s[keyPath: value].map { (Double($0), s.timerTime) } }
        let weight = weighted.reduce(0) { $0 + $1.1 }
        guard weight > 0 else { return nil }
        return Int((weighted.reduce(0) { $0 + $1.0 * $1.1 } / weight).rounded())
    }

    private static func sum(_ values: [Int]) -> Int? {
        values.isEmpty ? nil : values.reduce(0, +)
    }
}
