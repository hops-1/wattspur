import SwiftData
import SwiftUI
import WattspurKit

/// Ride detail: map, key figures, details and charts (TOUR-01 … TOUR-05).
struct RideDetailView: View {
    let rideID: UUID
    /// Called with the original rides after splitting a merged ride (B-095).
    var onSplit: ([UUID]) -> Void = { _ in }
    /// Opens Highlights › Records (ADV-R2).
    var onShowRecords: () -> Void = {}
    @Query private var rides: [Ride]

    init(rideID: UUID, onSplit: @escaping ([UUID]) -> Void = { _ in }, onShowRecords: @escaping () -> Void = {}) {
        self.rideID = rideID
        self.onSplit = onSplit
        self.onShowRecords = onShowRecords
        _rides = Query(filter: #Predicate<Ride> { $0.id == rideID })
    }

    var body: some View {
        if let ride = rides.first {
            RideDetailContent(ride: ride, onSplit: onSplit, onShowRecords: onShowRecords)
        } else {
            ContentUnavailableView("Select a ride", systemImage: "bicycle")
        }
    }
}

private struct RideDetailContent: View {
    let ride: Ride
    let onSplit: ([UUID]) -> Void
    let onShowRecords: () -> Void
    /// All rides that count, to find the records this ride holds (ADV-R2).
    @Query(filter: Ride.listedPredicate)
    private var listedRides: [Ride]

    @AppStorage(SettingsKey.mapType) private var mapType: RideMapType = .standard
    /// "From pedal power" or "with profile" (SET-06, B-067).
    @AppStorage(SettingsKey.calorieMode) private var calorieMode: CalorieMode = .fromWork
    @Query private var riders: [Rider]
    private var calories: CalorieModel { CalorieModel(mode: calorieMode, rider: riders.first) }
    @Environment(NewPathsStore.self) private var newPaths
    @Environment(RideLibrary.self) private var sharedLibrary
    @State private var route: [RoutePoint] = []
    @State private var points: [ChartPoint] = []
    /// The same series over the time since the start (B-065).
    @State private var timePoints: [ChartPoint] = []
    /// x axis of the charts, remembered (TOUR-07).
    @AppStorage(SettingsKey.chartAxis) private var chartAxis: ChartAxis = .distance
    /// Where the parts of a merged ride meet (B-131).
    @State private var joins: [RideMerge.Join] = []
    /// The spot shared by the charts and the map (B-062).
    @State private var cursor = RideCursor()
    @State private var showDetails = true
    @State private var exporting = false

    var body: some View {
        GeometryReader { proxy in
            // The map stays in view, so the spot the charts point at never scrolls away (B-170);
            // only what is below it scrolls.
            VStack(spacing: 0) {
                header(mapHeight: Self.mapHeight(forWindow: proxy.size.height))
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                    .column()
                Divider()
                ScrollView {
                    content
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)
                        .column()
                }
            }
            .environment(cursor)
        }
        // Esc lets go of a held spot, and only then; without one it is left to the rest of the window.
        .background {
            Button("Release position") { cursor.release() }
                .keyboardShortcut(.cancelAction)
                .disabled(!cursor.isHeld)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .task(id: ride.id) {
            // Decoding ~3 000 samples is quick, but keep it out of every redraw.
            let samples = ride.samples
            route = RideSeries.route(from: samples)
            points = RideSeries.chartPoints(from: samples)
            timePoints = RideSeries.chartPoints(from: samples, axis: .time)
            cursor.reset(track: RideTrack(samples: samples))
            joins = sharedLibrary.joins(of: ride)
        }
    }
}

extension RideDetailContent {
    /// The map is a third of the window, between 200 and 340 points, so the text below keeps room.
    static func mapHeight(forWindow height: CGFloat) -> CGFloat {
        min(340, max(200, height * 0.36))
    }

    /// What stays in place: PDF and GPX export, name, source and the map.
    private func header(mapHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // PDF export at the top left, as in the comparison (P-20).
            HStack(spacing: 8) {
                PDFExportButton(isExporting: exporting, isDisabled: points.isEmpty && route.isEmpty) { target in
                    Task { await exportPDF(target) }
                }
                // GPX export next to it (B-112, IMP-09).
                Button("Export as GPX…", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    GPXExport.save(ride)
                }
                .buttonStyle(.glass)
                .disabled(route.isEmpty)
                .help(Text("Save the track for komoot, a navigation device or another app"))
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.name).font(.largeTitle.bold())
                    Text(RideFormat.longDate(ride.startDate, timeZone: ride.timeZone))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                RideBikeMenu(ride: ride)
                    .padding(.top, 6)
            }
            // Where a GPX ride comes from and why its totals are estimated (B-145).
            RideSourceLine(ride: ride)

            RideMapView(route: route, mapType: mapType, joins: joins, newStretches: newPaths.result(for: ride)?.stretches ?? [])
                .frame(height: mapHeight)
                // A fresh map for each ride; route and new paths update it in place,
                // drawn in a fixed order (B-127).
                .id(ride.id)
                .overlay(alignment: .topTrailing) {
                    Picker("Map type", selection: $mapType) {
                        ForEach(RideMapType.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .padding(6)
                    .glassEffect(.regular, in: Capsule())
                    .padding(12)
                }
        }
    }

    /// What scrolls below the map: banners, key figures, details and charts.
    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            if ride.isSample {
                SampleRideBanner()
            }
            if ride.isMerged {
                MergedRideBanner(ride: ride, onSplit: onSplit)
            }
            if ride.isSample {
                Text("The route is moved and shortened by 500 m at the start and end; power, cadence and totals are real.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let held = heldRecords
            if !held.isEmpty {
                RecordBanner(records: held, onShowRecords: onShowRecords)
            }
            let fresh = newPaths.result(for: ride)
            KeyFiguresGrid(ride: ride, records: Set(held.map(\.kind)), calories: calories)
            if let fresh, !ride.isSample {
                NewPathsFigure(share: fresh.share, distance: fresh.share * ride.distance)
                    .frame(maxWidth: 420, alignment: .leading)
            }

            DisclosureGroup("Details", isExpanded: $showDetails) {
                DetailsGrid(ride: ride, records: Set(held.map(\.kind)))
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            Picker("Chart axis", selection: $chartAxis) {
                Text("Distance").tag(ChartAxis.distance)
                Text("Time").tag(ChartAxis.time)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help(Text("What the charts show along the bottom"))
            RideChartsView(ride: ride, points: chartPoints, axis: chartAxis, joins: joins)
        }
    }

    /// The records this ride holds now, each with the best value of all other rides.
    private var heldRecords: [RecordBanner.Held] {
        guard ride.countsInStatistics else { return [] }
        let calendar = GoalPeriod.calendar()
        let all = listedRides.filter(\.countsInStatistics).map(\.highlightRide)
        let kinds = RideRecords.kinds(heldBy: ride.id, in: RideRecords.records(all, calendar: calendar))
        guard !kinds.isEmpty else { return [] }
        let others = RideRecords.records(all.filter { $0.id != ride.id }, calendar: calendar)
        return kinds.map { kind in RecordBanner.Held(kind: kind, nextBest: others.first { $0.kind == kind }?.value) }
    }

    private var chartPoints: [ChartPoint] { chartAxis == .time ? timePoints : points }

    private func exportPDF(_ target: PDFExport.Target) async {
        exporting = true
        defer { exporting = false }
        let report = RideReport(ride: ride, route: route, points: chartPoints, mapType: mapType, axis: chartAxis, joins: joins, calories: calories)
        PDFExport.deliver(await report.pdfData(), fileName: report.fileName, to: target)
    }
}

/// "Record: highest avg speed · next best 26.1 km/h" above the key figures (ADV-R2).
private struct RecordBanner: View {
    struct Held {
        let kind: RecordKind
        let nextBest: Double?
    }

    let records: [Held]
    let onShowRecords: () -> Void

    private var text: String {
        records.map { held in
            let title = HighlightsFormat.title(held.kind)
            guard let next = held.nextBest else { return title }
            return String(localized: "\(title) (next best \(HighlightsFormat.text(held.kind, next)))")
        }
        .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("\(Text(records.count == 1 ? "Record:" : "Records:").bold()) \(text)")
                .font(.callout)
            Spacer(minLength: 8)
            Button("All Records", action: onShowRecords)
                .buttonStyle(.link)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }
}

/// The key figures in the order of the Flow app (TOUR-03).
struct KeyFiguresGrid: View {
    let ride: Ride
    /// Records the ride holds; their figures get a badge (ADV-R2).
    var records: Set<RecordKind> = []
    var calories: CalorieModel = .fromWork

    /// `nil` without power: the calories come from the work (B-145).
    private var kilocalories: Double? {
        ride.hasPowerData ? calories.kilocalories(workKilojoules: ride.workKilojoules, rideTime: ride.timerTime, on: ride.startDate) : nil
    }

    /// What a figure that is not there says under the dash, for rides from a GPX file only; a Bosch ride
    /// without a value stays with the dash.
    private var notInFile: String? { ride.source == .gpx ? String(localized: "Not in the file") : nil }

    private var co2: Double { ride.distance / 1000 * 0.159 }

    /// Ride time, distance, speed and ascent were computed from the GPS points (B-142).
    private var totalsEstimated: Bool { ride.summaryEstimatedFromGPS }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 20) {
            GridRow {
                Figure("Ride time", value: RideFormat.duration(ride.timerTime), approximate: totalsEstimated,
                       isRecord: records.contains(.longestDuration))
                Figure("Distance", value: RideFormat.distanceValue(ride.distance), unit: "km", approximate: totalsEstimated,
                       isRecord: records.contains(.longestDistance))
                Figure("Avg speed", value: RideFormat.speedValue(ride.averageSpeed), unit: "km/h", approximate: totalsEstimated,
                       isRecord: records.contains(.highestAverageSpeed))
                Figure("Ascent", value: ride.totalAscent.map(String.init) ?? "–", unit: "m", approximate: totalsEstimated,
                       caption: ride.totalAscent == nil ? notInFile : nil, isRecord: records.contains(.mostAscent))
            }
            GridRow {
                Figure("Avg power", value: ride.averagePower.map(String.init) ?? "–", unit: "W",
                       caption: ride.averagePower == nil ? notInFile : nil, isRecord: records.contains(.highestAveragePower))
                Figure("Avg cadence", value: ride.averageCadence.map(String.init) ?? "–", unit: String(localized: "rpm"),
                       caption: ride.averageCadence == nil ? notInFile : nil)
                Figure("Calories", value: kilocalories.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "–", unit: "kcal",
                       estimated: kilocalories != nil, note: calories.note,
                       caption: kilocalories == nil && ride.source == .gpx ? String(localized: "Needs power data") : nil)
                Figure("CO₂ saved", value: co2.formatted(.number.precision(.fractionLength(1))), unit: "kg", estimated: true,
                       note: String(localized: "Calculated from the distance"),
                       caption: ride.source == .gpx ? String(localized: "From the distance") : nil)
            }
        }
    }
}

/// Additional figures (TOUR-05).
struct DetailsGrid: View {
    let ride: Ride
    /// Records the ride holds; their figures get a badge (ADV-R2, B-122).
    var records: Set<RecordKind> = []

    private var elevationRange: String {
        guard let lo = ride.minAltitude, let hi = ride.maxAltitude else { return "–" }
        return "\(Int(lo.rounded()))–\(Int(hi.rounded())) m"
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
            GridRow {
                Detail("Total time", RideFormat.duration(ride.elapsedTime))
                Detail("Paused", RideFormat.duration(ride.pausedTime))
                Detail("Descent", "\(ride.totalDescent.map(String.init) ?? "–") m")
                Detail("Max speed", RideFormat.speed(ride.maxSpeed), isRecord: records.contains(.highestSpeed))
            }
            GridRow {
                Detail("Max power", "\(ride.maxPower.map(String.init) ?? "–") W", isRecord: records.contains(.highestPower))
                Detail("Max cadence", "\(ride.maxCadence.map(String.init) ?? "–") \(String(localized: "rpm"))",
                       isRecord: records.contains(.highestCadence))
                Detail("Work", ride.hasPowerData ? "\(Int(ride.workKilojoules.rounded())) kJ" : "–")
                Detail("Elevation min–max", elevationRange)
            }
            GridRow {
                Detail("Best 1-minute power", ride.bestPower1Min.map { "\($0) W" } ?? "–",
                       isRecord: records.contains(.bestPower1Min))
            }
        }
    }
}

private struct Detail: View {
    let label: LocalizedStringKey
    let value: String
    var isRecord = false

    init(_ label: LocalizedStringKey, _ value: String, isRecord: Bool = false) {
        self.label = label
        self.value = value
        self.isRecord = isRecord
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label)
                if isRecord { RecordTag() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(verbatim: value).font(.body.weight(.medium)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// "★ Record" next to a figure that is one (ADV-R2).
private struct RecordTag: View {
    var body: some View {
        // Text in the primary colour, so it stays readable; the star carries the accent.
        HStack(spacing: 3) {
            Image(systemName: "star.fill").foregroundStyle(Color.accentColor)
            Text("Record").foregroundStyle(.primary)
        }
        .font(.caption2.bold())
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Color.accentColor.opacity(0.16), in: Capsule())
    }
}

private struct Figure: View {
    let label: LocalizedStringKey
    let value: String
    var unit: String = ""
    var estimated = false
    /// "≈" next to the label: the total comes from the GPS points of a GPX file (B-145).
    var approximate = false
    /// The text of the info next to an estimate.
    var note = String(localized: "Estimated from your pedal power")
    /// A line under the value, e.g. "Not in the file".
    var caption: String?
    var isRecord = false

    init(_ label: LocalizedStringKey, value: String, unit: String = "", estimated: Bool = false, approximate: Bool = false,
         note: String? = nil, caption: String? = nil, isRecord: Bool = false) {
        if let note { self.note = note }
        self.label = label
        self.value = value
        self.unit = unit
        self.estimated = estimated
        self.approximate = approximate
        self.caption = caption
        self.isRecord = isRecord
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                if approximate {
                    Text(verbatim: "≈")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.estimate)
                        .help(Text("Totals estimated"))
                        .accessibilityLabel(Text("Totals estimated"))
                }
                if estimated {
                    Image(systemName: "info.circle")
                        .help(Text(verbatim: note))
                        .accessibilityLabel(Text(verbatim: note))
                }
                if isRecord { RecordTag() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: value).font(.system(size: 28, weight: .semibold))
                if !unit.isEmpty {
                    Text(verbatim: unit).foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            if let caption {
                Text(verbatim: caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// The reading width of the detail page, left aligned.
    func column() -> some View {
        frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
