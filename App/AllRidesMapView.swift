import MapKit
import SwiftData
import SwiftUI
import WattspurKit

/// The "Map" section (v1.4, ⌘5): all rides on one map as komoot-like heat lines,
/// filtered by period or by the rides selected in the list, with the totals of
/// the rides in the visible area below (AGG-05, AGG-06, MAP-04a; B-106, B-107, B-114).
struct AllRidesMapView: View {
    /// The rides selected in the list.
    let selectedRideIDs: Set<UUID>
    /// Kept by the window, so ⌘5 comes back to the same area after another section.
    @Binding var memory: MapMemory
    /// "Show on Map" from the analysis: exactly these rides instead of the map's period.
    var analysisRides: Set<UUID>? = nil
    var onClearAnalysisRides: () -> Void = {}
    /// "Show in Analysis" for the rides in the visible area.
    /// The rides in the visible area and all shown rides, for the list beside the map (B-123).
    var onRidesInViewChange: (Set<UUID>, Int) -> Void = { _, _ in }
    /// "Select all N in the list" in the popover (B-109).
    var onSelectRides: (Set<UUID>) -> Void = { _ in }
    /// "Open in Ride Detail" in the popover's info card (B-109).
    var onOpenRide: (UUID) -> Void = { _ in }
    let onShowInAnalysis: (Set<UUID>) -> Void
    let onImport: () -> Void

    @Query(sort: \Ride.startDate) private var rides: [Ride]
    @AppStorage(SettingsKey.mapPeriod) private var kind: AnalysisPeriodKind = .all
    /// The bike filter of the map, remembered (B-137, B-110).
    @AppStorage(SettingsKey.bikeFilterMap) private var bikeFilterChoice: BikeFilter = .all
    /// The source filter of the map, the same way (B-145).
    @AppStorage(SettingsKey.sourceFilterMap) private var sourceFilterChoice: SourceFilter = .all
    private var hasGPXRides: Bool { rides.contains { $0.source == .gpx } }
    @Query private var bikes: [Bike]
    @AppStorage(SettingsKey.mapType) private var mapType: RideMapType = .standard
    /// Heat lines or heat map (B-107, B-108).
    @AppStorage(SettingsKey.mapMode) private var mode: RidesMapStyle.Mode = .lines
    /// Off: only the map, without lines or heat map; a second click on the chosen display.
    @AppStorage(SettingsKey.mapShowsRides) private var showsRides = true
    @State private var offset = 0
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd = Date.now
    @State private var onlySelected = false
    @State private var fitRequest = 0
    @State private var exporting = false
    @State private var cache = MapCache()
    /// The rides at a clicked spot (B-109, MAP-05).
    @State private var popover: MapPopover?
    @Environment(NewPathsStore.self) private var newPaths
    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar { .current }

    private var period: AnalysisPeriod {
        let start = calendar.startOfDay(for: min(customStart, customEnd))
        let endDay = calendar.startOfDay(for: max(customStart, customEnd))
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return AnalysisPeriod(kind: kind, offset: offset, customInterval: DateInterval(start: start, end: end))
    }

    private var showsSelection: Bool { analysisRides == nil && onlySelected && !selectedRideIDs.isEmpty }

    var body: some View {
        let interval = period.interval(calendar: calendar)
        let filter = MapFilter(interval: interval, selectedIDs: analysisRides ?? (showsSelection ? selectedRideIDs : nil),
                               bike: bikeFilterChoice.resolved(knownBikeIDs: Set(bikes.map(\.id))),
                               source: sourceFilterChoice.resolved(hasGPXRides: hasGPXRides))
        let overview = cache.overview(rides, filter: filter)
        // 1 to 4 selected rides in the comparison's colours, oldest first like there.
        let highlighted = showsSelection && (1...RideComparison.allowedCount.upperBound).contains(overview.rides.count)
            ? overview.rides.sorted { $0.figures.startDate < $1.figures.startDate }.map(\.id) : []
        // A ride selected in the list beside the map stands out (B-123).
        let selected = highlighted.isEmpty ? selectedRideIDs : []
        // 1 to 4 selected rides are always shown as lines in the comparison's style.
        let shownMode: RidesMapStyle.Mode = highlighted.isEmpty ? mode : .lines
        let focused = popover?.focus
        let style = cache.style(overview, highlighted: highlighted, selected: selected, focused: focused, mode: shownMode,
                                dark: colorScheme == .dark)
        let visibleRect = memory.area
        let area = visibleRect.map(GeoBounds.init)
        let inView = area.map { overview.rides(touching: $0) } ?? overview.rides
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 28)
                .frame(height: 52)
            VStack(alignment: .leading, spacing: 14) {
                PDFExportButton(isExporting: exporting, isDisabled: overview.rides.isEmpty) { target in
                    Task {
                        await exportPDF(overview: overview, highlighted: highlighted, mode: shownMode, inView: inView,
                                        interval: interval, to: target)
                    }
                }
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Map").font(.largeTitle.bold())
                        Text(verbatim: subtitle(overview, interval: interval)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                map(overview: overview, style: style, highlighted: highlighted)
                if !overview.rides.isEmpty {
                    AreaTiles(rides: inView, total: overview.rides.count, isSelection: showsSelection,
                              newPathsDistance: newPathsDistance(inView)) {
                        onShowInAnalysis(Set(inView.map(\.id)))
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .onChange(of: kind) { offset = 0 }
        .onChange(of: Set(inView.map(\.id)), initial: true) { onRidesInViewChange($1, overview.rides.count) }
        .onChange(of: overview.rides.count) { onRidesInViewChange(Set(inView.map(\.id)), $1) }
        .onChange(of: selectedRideIDs.isEmpty) { if selectedRideIDs.isEmpty { onlySelected = false } }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            if let analysisRides {
                analysisChip(count: analysisRides.count)
            } else {
                periodControls
                    // The period does not apply while only the selected rides are shown.
                    .disabled(showsSelection)
                BikeFilterMenu(filter: $bikeFilterChoice)
                    .disabled(showsSelection)
                SourceFilterMenu(filter: $sourceFilterChoice, hasGPXRides: hasGPXRides)
                    .disabled(showsSelection)
            }
            Spacer()
            // Switching it on replaces the rides from the analysis (feedback from Nils).
            Toggle(isOn: Binding(get: { showsSelection }, set: { on in
                onlySelected = on
                if on { onClearAnalysisRides() }
            })) {
                Text("Only selected rides (\(selectedRideIDs.count))")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(selectedRideIDs.isEmpty)
            .help(selectedRideIDs.isEmpty ? Text("Select rides in the list with ⌘-click first") : Text("Show only the rides selected in the list"))
        }
    }

    /// Like the selection chip in the analysis: the map shows the analysed rides.
    private func analysisChip(count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar")
            Text("\(count) rides from the analysis")
            Button(action: onClearAnalysisRides) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help(Text("Show the map's own period instead"))
            .accessibilityLabel(Text("Show the map's own period instead"))
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.14), in: Capsule())
    }

    private var periodControls: some View {
        HStack(spacing: 12) {
            Picker("Period", selection: $kind) {
                ForEach(AnalysisPeriodKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if kind.isSteppable {
                HStack(spacing: 4) {
                    Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                        .help(Text("Previous period"))
                        .accessibilityLabel(Text("Previous period"))
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button { offset = min(0, offset + 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(offset >= 0)
                        .help(Text("Next period"))
                        .accessibilityLabel(Text("Next period"))
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            if kind == .custom {
                DatePicker("From", selection: $customStart, displayedComponents: .date).fixedSize()
                DatePicker("To", selection: $customEnd, displayedComponents: .date).fixedSize()
            }
        }
    }

    private func subtitle(_ overview: MapOverview, interval: DateInterval?) -> String {
        let totals = overview.totals
        let count = String(localized: "\(totals.rideCount) rides")
        var parts = [count, RideFormat.distance(totals.distance)]
        if analysisRides != nil {
            parts[0] = String(localized: "\(totals.rideCount) rides from the analysis")
        } else if showsSelection {
            parts[0] = String(localized: "\(totals.rideCount) selected rides")
        } else {
            parts.append(AnalysisModel.title(kind: kind, interval: interval, calendar: calendar))
        }
        if overview.withoutGPS > 0 {
            parts.append(String(localized: "\(overview.withoutGPS) without GPS not on the map"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Map

    @ViewBuilder
    private func map(overview: MapOverview, style: RidesMapStyle, highlighted: [UUID]) -> some View {
        let key = "\(colorScheme == .dark)|\(style.mode)|\(highlighted)|\(selectedRideIDs.sorted())|\(popover?.focus?.uuidString ?? "")|\(overview.rides.map(\.id))"
        let ids = overview.rides.map(\.id)
        // 1 to 4 selected rides are what the map shows, so they are never hidden.
        let hidesRides = !showsRides && highlighted.isEmpty
        RidesMapRepresentable(style: style, styleKey: key, showsRides: !hidesRides, mapType: mapType, fitKey: ids,
                              onVisibleAreaChange: { memory = MapMemory(area: $0, rideIDs: ids) }, fitRequest: $fitRequest,
                              restoredArea: memory.rideIDs == ids ? memory.area : nil) { coordinate, radius, point in
            // Nothing to click on while the rides are hidden.
            guard !hidesRides else { popover = nil; return }
            let hits = RouteHitTest.rides(near: RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
                                          radius: radius, in: overview.rides)
            popover = hits.isEmpty ? nil : MapPopover(point: point, rides: hits)
            // Beside every route: nothing stands out any more, also not the rides
            // selected in the list (B-129). With "Only selected rides" the selection
            // is what the map shows, so it stays.
            if hits.isEmpty && !showsSelection && !selectedRideIDs.isEmpty {
                onSelectRides([])
            }
        }
            .frame(minHeight: 320, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if let popover {
                    GeometryReader { geometry in
                        MapPopoverView(popover: popover, onFocus: { self.popover?.focus = $0 }, onClose: { self.popover = nil },
                                       onSelectAll: { onSelectRides(Set(popover.rides.map(\.id))) },
                                       onOpen: onOpenRide, newPathsDistance: { newPathsDistance([$0]) })
                            .offset(popover.offset(in: geometry.size))
                    }
                }
            }
            .onChange(of: ids) { popover = nil }
            .onExitCommand { popover = nil }
            .tileAttribution(for: mapType)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    Button { fitRequest += 1 } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .help(Text("Show all rides"))
                        .accessibilityLabel(Text("Show all rides"))
                        .disabled(overview.rides.isEmpty)
                    // Lines or heat map moved here from the header (B-061).
                    MapCustomizeButton(mapType: $mapType, mode: $mode, showsRides: $showsRides,
                                       modeDisabled: !highlighted.isEmpty || overview.rides.isEmpty)
                }
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                if !overview.rides.isEmpty && !hidesRides {
                    MapLegend(highlighted: highlighted.compactMap { id in overview.rides.first { $0.id == id } }, mode: style.mode)
                        .padding(.leading, 12)
                        // Above Apple's map attribution, which must stay visible.
                        .padding(.bottom, 40)
                }
            }
            .overlay(alignment: .top) {
                if overview.preparing > 0 {
                    let total = overview.preparing + overview.rides.count + overview.withoutGPS
                    PreparingBanner(done: total - overview.preparing, total: total)
                        .padding(.top, 12)
                }
            }
            .overlay {
                if overview.rides.isEmpty && overview.preparing == 0 {
                    emptyState(overview)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Map of all rides"))
            .accessibilityValue(Text(verbatim: subtitle(overview, interval: period.interval(calendar: calendar))))
    }

    @ViewBuilder
    private func emptyState(_ overview: MapOverview) -> some View {
        let anyRide = rides.contains { $0.countsInStatistics }
        Group {
            if showsSelection || analysisRides != nil {
                ContentUnavailableView("No GPS Data", systemImage: "location.slash",
                                       description: Text("The selected rides have no route."))
            } else if anyRide && kind != .all {
                ContentUnavailableView {
                    Label("No Rides in This Period", systemImage: "map")
                } description: {
                    Text("Choose another period or show all rides.")
                } actions: {
                    Button("Show All Rides") { kind = .all }
                }
            } else if anyRide {
                ContentUnavailableView("No GPS Data", systemImage: "location.slash",
                                       description: Text("None of your rides has a route."))
            } else {
                ContentUnavailableView {
                    Label("No Rides on the Map Yet", systemImage: "map")
                } description: {
                    Text("Import FIT files from the Flow app or GPX files. The sample ride only appears here when you select it in the list.")
                } actions: {
                    Button("Import Rides…", action: onImport)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Kilometres on new paths of these rides (B-115); `nil` while they are computed.
    private func newPathsDistance(_ mapRides: [MapRide]) -> Double? {
        let byID = Dictionary(rides.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let distances = mapRides.compactMap { byID[$0.id].flatMap(newPaths.newDistance(for:)) }
        return distances.count == mapRides.count ? distances.reduce(0, +) : nil
    }

    // MARK: PDF

    private func exportPDF(overview: MapOverview, highlighted: [UUID], mode: RidesMapStyle.Mode, inView: [MapRide], interval: DateInterval?,
                           to target: PDFExport.Target) async {
        exporting = true
        defer { exporting = false }
        // The PDF is always light, so the lines are drawn for the light appearance.
        let style = RidesMapStyle(rides: overview.rides, highlighted: highlighted, mode: mode, dark: false)
        let report = MapReport(style: style, area: memory.area ?? style.boundingRect, mapType: mapType,
                               subtitle: subtitle(overview, interval: interval), inView: inView,
                               total: overview.rides.count, isSelection: showsSelection,
                               newPathsDistance: newPathsDistance(inView))
        PDFExport.deliver(await report.pdfData(), fileName: PDFExport.fileName(String(localized: "Map")), to: target)
    }
}

// MARK: - Pieces

/// The visible area of the map and the rides it was showing, kept while another
/// section is open. Only for the same rides it is restored; otherwise the map
/// fits the rides again.
struct MapMemory {
    var area: MKMapRect?
    var rideIDs: [UUID] = []
}

/// "In the visible area": the rides whose route touches the visible part of the
/// map, with their whole Bosch totals (AGG-06, B-114).
struct AreaTiles: View {
    let rides: [MapRide]
    let total: Int
    let isSelection: Bool
    /// Kilometres on new paths (B-115); no tile while unknown.
    var newPathsDistance: Double? = nil
    var onShowInAnalysis: (() -> Void)?

    var body: some View {
        let sums = RideAggregate(rides.map(\.figures))
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(isSelection ? "Selected rides in the visible area" : "In the visible area")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("\(rides.count) of \(total) rides, whole rides with their totals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let onShowInAnalysis {
                    Button("Show in Analysis", systemImage: "chevron.right", action: onShowInAnalysis)
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.link)
                        .disabled(rides.isEmpty)
                }
            }
            HStack(spacing: 10) {
                MapTile("Rides", value: rides.count.formatted())
                MapTile("Distance", value: RideFormat.distanceValue(sums.distance), unit: "km")
                MapTile("Ride time", value: AnalysisFormat.hoursMinutes(sums.timerTime))
                MapTile("Ascent", value: sums.ascent.formatted(.number.precision(.fractionLength(0))), unit: "m")
                MapTile("Avg speed", value: RideFormat.speedValue(sums.averageSpeed), unit: "km/h")
                if let newPathsDistance {
                    MapTile("New paths", value: RideFormat.distanceValue(newPathsDistance), unit: "km")
                }
            }
        }
    }
}

private struct MapTile: View {
    let label: LocalizedStringKey
    let value: String
    var unit = ""

    init(_ label: LocalizedStringKey, value: String, unit: String = "") {
        self.label = label
        self.value = value
        self.unit = unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: value).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                if !unit.isEmpty { Text(verbatim: unit).font(.callout).foregroundStyle(.secondary) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// "How often ridden" with line samples, or the selected rides with colour and dash.
struct MapLegend: View {
    let highlighted: [MapRide]
    var mode: RidesMapStyle.Mode = .lines
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if highlighted.isEmpty && mode == .heat {
                Text("Rides per area").font(.caption.weight(.bold))
                HStack(spacing: 3) {
                    ForEach(DensityStep.allCases, id: \.self) { step in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(cgColor: RidesMapStyle.stepColors[step] ?? .black).opacity(RidesMapStyle.heatAlpha))
                                .frame(width: 44, height: 12)
                            Text(verbatim: step.legendLabel).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Different rides per area, the same steps in every period.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 230, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if highlighted.isEmpty {
                Text("How often ridden").font(.caption.weight(.bold))
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach([1, 5, 20, 60], id: \.self) { n in
                        VStack(spacing: 4) {
                            sample(rides: n)
                            Text(verbatim: n == 60 ? "60×+" : "\(n)×").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Each ride is a translucent line; routes you ride often become wider and stronger.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 230, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Selected rides").font(.caption.weight(.bold))
                ForEach(Array(highlighted.enumerated()), id: \.element.id) { index, ride in
                    HStack(spacing: 8) {
                        ComparisonLegendMark(index: index)
                        Text(verbatim: ride.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(verbatim: RideFormat.distance(ride.figures.distance)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    /// What `n` overlapping rides look like, drawn the same way as on the map.
    private func sample(rides n: Int) -> some View {
        let opacity = RidesMapStyle.legendOpacity(rides: n)
        let color = Color(cgColor: RidesMapStyle(rides: [], highlighted: [], dark: colorScheme == .dark).heatColor)
        return ZStack {
            Capsule().fill(color.opacity(opacity.band)).frame(width: 36, height: RidesMapStyle.bandWidth)
            Capsule().fill(color.opacity(opacity.thin)).frame(width: 36, height: RidesMapStyle.thinWidth)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

/// Shown while the routes of rides from before v1.4 are still being prepared (B-104).
struct PreparingBanner: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("Preparing routes…").font(.caption.weight(.semibold))
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .frame(width: 140)
            Text("\(done) of \(total) rides").font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Decoding all routes and converting them for MapKit takes a moment with many
/// rides. The section redraws on every pan (the tiles follow the visible area),
/// so both are kept until the rides, the filter or the drawing change.
@MainActor
final class MapCache {
    private var overviewKey: Int?
    private var overviewValue = MapOverview(rides: [])
    private var styleKey: Int?
    private var styleValue = RidesMapStyle(rides: [], highlighted: [], dark: false)

    func overview(_ rides: [Ride], filter: MapFilter) -> MapOverview {
        var hasher = Hasher()
        hasher.combine(filter.interval)
        hasher.combine(filter.selectedIDs)
        hasher.combine(filter.bike)
        for ride in rides {
            // Everything that decides whether and how a ride is on the map.
            hasher.combine(ride.id)
            hasher.combine(ride.overviewRouteVersion)
            hasher.combine(ride.overviewRouteData)
            hasher.combine(ride.deletedAt)
            hasher.combine(ride.mergedInto?.id)
            hasher.combine(ride.isSample)
            hasher.combine(ride.startDate)
            hasher.combine(ride.bike?.id)
            hasher.combine(ride.name)
        }
        let key = hasher.finalize()
        if key != overviewKey {
            overviewKey = key
            overviewValue = MapOverview(rides, filter: filter)
        }
        return overviewValue
    }

    func style(_ overview: MapOverview, highlighted: [UUID], selected: Set<UUID>, focused: UUID?,
               mode: RidesMapStyle.Mode, dark: Bool) -> RidesMapStyle {
        var hasher = Hasher()
        hasher.combine(focused)
        hasher.combine(mode)
        hasher.combine(overviewKey)
        hasher.combine(highlighted)
        hasher.combine(selected)
        hasher.combine(dark)
        let key = hasher.finalize()
        if key != styleKey {
            styleKey = key
            styleValue = RidesMapStyle(rides: overview.rides, highlighted: highlighted, selected: selected, focused: focused,
                                       mode: mode, dark: dark)
        }
        return styleValue
    }
}

extension DensityStep {
    /// "1", "2–4", "5–9", "10–19", "20+" under the swatches of the heat map's legend.
    var legendLabel: String {
        let (low, high) = range
        guard let high else { return "\(low)+" }
        return low == high ? "\(low)" : "\(low)–\(high)"
    }
}
