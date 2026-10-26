import Foundation

/// A route prepared for comparing it with many others (B-116, ROUTE-01, ROUTE-08).
///
/// The simplified route (`OverviewRoute`, B-104) is laid out as points every `spacing` metres in a
/// flat frame of its own (metres east and north of the middle of the route) and the points are
/// sorted into 50 m cells. A comparison then only has to look at the nine cells around a point
/// instead of every line of the other route, which makes one comparison cheap enough for a
/// library of a thousand rides. Built once per ride and kept in memory, never stored.
public struct RouteSignature: Sendable {
    /// Distance between the points laid along the route, in metres.
    public static let spacing = 10.0
    /// Routes shorter than this have no signature: a few metres cannot be "the same route".
    public static let minimumLength = 100.0
    /// Side of the cells the points are sorted into; also the reach of a comparison.
    static let cellSize = 50.0
    static let metresPerDegree = 6_371_000.0 * .pi / 180
    /// Below this share of the squared length an enclosed area counts as "no direction of
    /// travel" (an out-and-back ride, a thin loop).
    static let orientationLimit = 0.003

    /// Length of the route in metres, without the gaps between the parts of a merged ride.
    public let length: Double

    // The flat frame: x east, y north, in metres, around this point.
    let originLatitude: Double
    let originLongitude: Double
    let cosLatitude: Double
    // The points in route order.
    let xs: [Float]
    let ys: [Float]
    let minX: Double, maxX: Double, minY: Double, maxY: Double
    // The points sorted into cells: `cellKeys` ascending, the points of cell `i` are
    // `cellPoints[cellOffsets[i] ..< cellOffsets[i + 1]]` (indices into `xs` and `ys`).
    let cellKeys: [Int64]
    let cellOffsets: [Int32]
    let cellPoints: [Int32]
    /// The cells of the whole earth the route touches, for the search over many rides
    /// (`RouteIndex`); sorted and without repeats.
    let globalCells: [Int64]
    /// +1 counter-clockwise, -1 clockwise, 0 without a clear direction of travel.
    let orientation: Int

    /// `nil` for an empty route or one shorter than `minimumLength`.
    public init?(_ route: OverviewRoute) {
        guard let bounds = GeoBounds(route.segments.joined()) else { return nil }
        let lat0 = (bounds.minLatitude + bounds.maxLatitude) / 2
        let lon0 = (bounds.minLongitude + bounds.maxLongitude) / 2
        let cosLat = max(0.01, cos(lat0 * .pi / 180))
        let m = Self.metresPerDegree

        var xs: [Float] = [], ys: [Float] = []
        var total = 0.0
        for segment in route.segments {
            let plane = segment.map { (x: ($0.longitude - lon0) * cosLat * m, y: ($0.latitude - lat0) * m) }
            guard var previous = plane.first else { continue }
            xs.append(Float(previous.x))
            ys.append(Float(previous.y))
            var carried = 0.0 // metres since the last point laid
            for next in plane.dropFirst() {
                let length = hypot(next.x - previous.x, next.y - previous.y)
                total += length
                var at = Self.spacing - carried
                while at <= length {
                    let f = at / length
                    xs.append(Float(previous.x + (next.x - previous.x) * f))
                    ys.append(Float(previous.y + (next.y - previous.y) * f))
                    at += Self.spacing
                }
                carried = length - (at - Self.spacing)
                previous = next
            }
            if hypot(previous.x - Double(xs[xs.count - 1]), previous.y - Double(ys[ys.count - 1])) > 1 {
                xs.append(Float(previous.x))
                ys.append(Float(previous.y))
            }
        }
        guard xs.count >= 2, total >= Self.minimumLength else { return nil }

        self.length = total
        self.originLatitude = lat0
        self.originLongitude = lon0
        self.cosLatitude = cosLat
        self.xs = xs
        self.ys = ys
        minX = Double(xs.min() ?? 0)
        maxX = Double(xs.max() ?? 0)
        minY = Double(ys.min() ?? 0)
        maxY = Double(ys.max() ?? 0)

        // Points sorted into the cells of the frame.
        let order = xs.indices
            .map { (key: Self.frameKey(x: Double(xs[$0]), y: Double(ys[$0])), index: Int32($0)) }
            .sorted { ($0.key, $0.index) < ($1.key, $1.index) }
        var keys: [Int64] = []
        var offsets: [Int32] = []
        for (position, entry) in order.enumerated() where keys.last != entry.key {
            keys.append(entry.key)
            offsets.append(Int32(position))
        }
        offsets.append(Int32(order.count))
        cellKeys = keys
        cellOffsets = offsets
        cellPoints = order.map(\.index)

        // Cells of the earth, for the search over many rides.
        var cells = Set<Int64>()
        for i in xs.indices {
            let latitude = lat0 + Double(ys[i]) / m
            let longitude = lon0 + Double(xs[i]) / (m * cosLat)
            cells.insert(Self.globalKey(latitude: latitude, longitude: longitude))
        }
        globalCells = cells.sorted()

        // Direction of travel: the sign of the area the route encloses, closed by a straight line.
        var twiceArea = 0.0
        for i in xs.indices {
            let j = (i + 1) % xs.count
            twiceArea += Double(xs[i]) * Double(ys[j]) - Double(xs[j]) * Double(ys[i])
        }
        let ratio = twiceArea / 2 / (total * total)
        orientation = ratio > Self.orientationLimit ? 1 : ratio < -Self.orientationLimit ? -1 : 0
    }

    var start: (x: Double, y: Double) { (Double(xs[0]), Double(ys[0])) }
    var end: (x: Double, y: Double) { (Double(xs[xs.count - 1]), Double(ys[ys.count - 1])) }

    // MARK: - Cells

    /// Cell of a point in the frame: a pair of whole numbers packed into one.
    static func frameKey(x: Double, y: Double) -> Int64 {
        frameKey(column: Int((x / cellSize).rounded(.down)), row: Int((y / cellSize).rounded(.down)))
    }

    static func frameKey(column: Int, row: Int) -> Int64 {
        Int64(column) << 32 | Int64(UInt32(truncatingIfNeeded: row))
    }

    /// Cell of the earth: rows 50 m high everywhere; within a row the cells are 50 m wide at the
    /// row's middle latitude, so the grid is the same for every ride (like `NewPaths`).
    static func globalKey(latitude: Double, longitude: Double) -> Int64 {
        let rowHeight = cellSize / metresPerDegree
        let row = Int((latitude / rowHeight).rounded(.down))
        let middle = (Double(row) + 0.5) * rowHeight * .pi / 180
        let columnWidth = cellSize / (metresPerDegree * max(0.01, cos(middle)))
        return globalKey(row: row, column: Int((longitude / columnWidth).rounded(.down)))
    }

    static func globalKey(row: Int, column: Int) -> Int64 {
        Int64(row) << 32 | Int64(UInt32(truncatingIfNeeded: column))
    }

    /// The nine cells around a cell of the earth, itself included.
    static func globalNeighbours(of key: Int64) -> [Int64] {
        let row = Int(key >> 32)
        let column = Int(Int32(truncatingIfNeeded: key))
        var keys: [Int64] = []
        keys.reserveCapacity(9)
        for dRow in -1...1 {
            for dColumn in -1...1 { keys.append(globalKey(row: row + dRow, column: column + dColumn)) }
        }
        return keys
    }

    /// Index of `key` in `cellKeys`, or `nil`.
    func cell(_ key: Int64) -> Int? {
        var low = 0, high = cellKeys.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let found = cellKeys[middle]
            if found == key { return middle }
            if found < key { low = middle + 1 } else { high = middle - 1 }
        }
        return nil
    }
}

/// How alike two routes are, and whether they run the same way (B-116, ROUTE-01).
///
/// The score is the share of a route that lies within `reach` metres of the other route, looked at
/// in both directions; the smaller of the two shares counts. That keeps a short ride that lies on
/// a long one from being "similar" to it. The direction is a separate answer: the same route
/// ridden the other way has the same score but runs `reverse`.
public enum RouteSimilarity {
    /// How close a point has to lie to the other route to count as the same way, in metres.
    /// Measured to points every `RouteSignature.spacing` metres, so up to 5 m stricter in places.
    public static let reach = 50.0
    /// Start and end of two rides have to lie this close for them to run the same (or the other)
    /// way (decided with Nils 26.10.2026, Requirements 10.19).
    public static let endTolerance = 200.0
    /// The default and the range of the threshold (ROUTE-02).
    public static let defaultThreshold = 0.95
    public static let thresholdRange = 0.80...0.99

    /// A stored or typed threshold, brought into `thresholdRange` (a damaged setting becomes the default).
    public static func clampedThreshold(_ value: Double) -> Double {
        guard value.isFinite else { return defaultThreshold }
        return min(max(value, thresholdRange.lowerBound), thresholdRange.upperBound)
    }

    public enum Direction: Sendable, Equatable {
        /// Start with start, end with end.
        case same
        /// Start with end, end with start.
        case reverse
        /// The ends do not fit: a part of a route, or a ride that begins elsewhere.
        case none
    }

    public struct Match: Sendable, Equatable {
        /// 0…1.
        public var score: Double
        public var direction: Direction

        public init(score: Double, direction: Direction) {
            self.score = score
            self.direction = direction
        }

        /// Is it the same route at `threshold`? The other way round only with `includeReverse`
        /// (ROUTE-04).
        public func isSimilar(threshold: Double, includeReverse: Bool) -> Bool {
            guard score >= threshold else { return false }
            return direction == .same || (includeReverse && direction == .reverse)
        }
    }

    public static func compare(_ a: RouteSignature, _ b: RouteSignature) -> Match {
        Match(score: min(coverage(of: a, by: b), coverage(of: b, by: a)), direction: direction(a, b))
    }

    /// Like `compare`, but gives up early (`nil`) when the score is certainly below `floor`.
    static func compare(_ a: RouteSignature, _ b: RouteSignature, atLeast floor: Double) -> Match? {
        let ab = coverage(of: a, by: b, floor: floor)
        guard ab >= floor else { return nil }
        let ba = coverage(of: b, by: a, floor: floor)
        guard ba >= floor else { return nil }
        return Match(score: min(ab, ba), direction: direction(a, b))
    }

    /// The share of `a` (0…1) that lies within `reach` metres of `b`. With a `floor`, stops as
    /// soon as the share cannot reach it any more and returns what it knows so far (below the floor).
    public static func coverage(of a: RouteSignature, by b: RouteSignature, floor: Double = 0) -> Double {
        let map = Frame(from: a, to: b)
        let stride = 2 // every second point: one point every 20 m
        let last = a.xs.count - 1
        let count = (last + stride - 1) / stride + 1
        let allowedMisses = Int((1 - floor) * Double(count))
        var covered = 0, misses = 0
        var index = 0
        while true {
            let i = min(index, last)
            if isNear(map.x(Double(a.xs[i])), map.y(Double(a.ys[i])), in: b) { covered += 1 } else {
                misses += 1
                if misses > allowedMisses { return Double(covered) / Double(count) }
            }
            if i == last { break }
            index += stride
        }
        return Double(covered) / Double(count)
    }

    public static func direction(_ a: RouteSignature, _ b: RouteSignature) -> Direction {
        let map = Frame(from: a, to: b)
        let aStart = map.point(a.start), aEnd = map.point(a.end)
        let bStart = b.start, bEnd = b.end
        func distance(_ p: (x: Double, y: Double), _ q: (x: Double, y: Double)) -> Double { hypot(p.x - q.x, p.y - q.y) }
        let tolerance = endTolerance
        let same = distance(aStart, bStart) <= tolerance && distance(aEnd, bEnd) <= tolerance
        let reverse = distance(aStart, bEnd) <= tolerance && distance(aEnd, bStart) <= tolerance
        switch (same, reverse) {
        case (false, false): return .none
        case (true, false): return .same
        case (false, true): return .reverse
        case (true, true):
            // Start and end lie together (a loop, or out and back): the way round decides.
            return a.orientation * b.orientation < 0 ? .reverse : .same
        }
    }

    // MARK: - Geometry

    /// The map from the frame of one route into the frame of another.
    struct Frame {
        let scaleX: Double, shiftX: Double, shiftY: Double

        init(from a: RouteSignature, to b: RouteSignature) {
            let m = RouteSignature.metresPerDegree
            scaleX = a.cosLatitude > 0 ? b.cosLatitude / a.cosLatitude : 1
            shiftX = (a.originLongitude - b.originLongitude) * m * b.cosLatitude
            shiftY = (a.originLatitude - b.originLatitude) * m
        }

        func x(_ x: Double) -> Double { x * scaleX + shiftX }
        func y(_ y: Double) -> Double { y + shiftY }
        func point(_ p: (x: Double, y: Double)) -> (x: Double, y: Double) { (x(p.x), y(p.y)) }
    }

    /// Does a point of the frame of `b` lie within `reach` of one of the points of `b`?
    private static func isNear(_ x: Double, _ y: Double, in b: RouteSignature) -> Bool {
        let r = reach
        guard x >= b.minX - r, x <= b.maxX + r, y >= b.minY - r, y <= b.maxY + r else { return false }
        let column = Int((x / RouteSignature.cellSize).rounded(.down))
        let row = Int((y / RouteSignature.cellSize).rounded(.down))
        let limit = r * r
        for dColumn in -1...1 {
            for dRow in -1...1 {
                guard let cell = b.cell(RouteSignature.frameKey(column: column + dColumn, row: row + dRow)) else { continue }
                for position in Int(b.cellOffsets[cell])..<Int(b.cellOffsets[cell + 1]) {
                    let point = Int(b.cellPoints[position])
                    let dx = Double(b.xs[point]) - x, dy = Double(b.ys[point]) - y
                    if dx * dx + dy * dy <= limit { return true }
                }
            }
        }
        return false
    }
}
