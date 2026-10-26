import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// The "Rides" list: all rides, newest first, grouped by month (LIST-01, LIST-03).
struct RideListView: View {
    /// Several rides can be selected and analysed together (LIST-06).
    @Binding var selection: Set<UUID>
    /// Set by "Import Rides…" on the empty map; opens the import dialog here.
    @Binding var importRequested: Bool
    /// "Similar to: …" (B-118); the main list only. Held by `ContentView`, so it stays when a ride is opened.
    @Binding var similarFilter: SimilarRidesFilter?
    /// Opens the comparison for 2–4 selected rides (CMP-01).
    var onCompare: () -> Void = {}
    /// Opens the year in review from the year tile (LIST-04).
    var onShowYear: () -> Void = {}
    /// Beside the map or the analysis: only these rides (B-123, B-124).
    var scope: RideListScope? = nil
    /// Double-click, Return or "Open in Ride Detail" beside the map and the analysis.
    var onOpen: ((UUID) -> Void)? = nil

    @Environment(ImportLog.self) private var importLog
    @Environment(FolderWatcher.self) private var watcher
    @Environment(MergeSuggestionCenter.self) private var suggestions
    @Environment(RouteSimilarityStore.self) private var similarity
    @Environment(\.openWindow) private var openWindow
    /// The window's undo manager: ⌘Z undoes renaming, trashing, merging and splitting.
    @Environment(\.undoManager) private var undoManager
    /// Parts of a merged ride are hidden; the merged ride stands for them (B-095).
    @Query(filter: Ride.listedPredicate, sort: \Ride.startDate, order: .reverse)
    private var rides: [Ride]
    /// The rows show a bike symbol from two bikes on (B-136).
    @Query private var bikes: [Bike]
    /// The bike filter of this list, remembered (B-137).
    @AppStorage(SettingsKey.bikeFilterRides) private var bikeFilterChoice: BikeFilter = .all
    private var bikeFilter: BikeFilter { scope == nil ? bikeFilterChoice.resolved(knownBikeIDs: Set(bikes.map(\.id))) : .all }
    /// The source filter of this list, remembered (B-145); only with a ride from a GPX file.
    @AppStorage(SettingsKey.sourceFilterRides) private var sourceFilterChoice: SourceFilter = .all
    private var hasGPXRides: Bool { rides.contains { $0.source == .gpx } }
    private var sourceFilter: SourceFilter { scope == nil ? sourceFilterChoice.resolved(hasGPXRides: hasGPXRides) : .all }
    /// Copies of the list's filters for the year in review (B-145).
    @AppStorage(SettingsKey.bikeFilterHighlights) private var highlightsBikeFilter: BikeFilter = .all
    @AppStorage(SettingsKey.sourceFilterHighlights) private var highlightsSourceFilter: SourceFilter = .all

    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var isDropTargeted = false
    /// The manual import: bike question, duplicate decisions, notice (B-144).
    @State private var flow = ImportFlow()
    @State private var renaming: Ride?
    @State private var newName = ""
    @AppStorage(SettingsKey.rideSortOrder) private var sortOrder: RideSortOrder = .date
    @AppStorage(SettingsKey.ridePeriod) private var period: RidePeriod = .all
    @AppStorage(SettingsKey.multiSelectTipDone) private var multiSelectTipDone = false
    /// Where the slider of a new "Similar to" filter starts (SET, ROUTE-02).
    @AppStorage(SettingsKey.similarRoutesThreshold) private var similarDefault = RouteSimilarity.defaultThreshold
    /// Rides waiting for "Move to trash?" when several are selected.
    @State private var trashCandidates: Set<UUID>?
    /// Rides waiting in the "Merge rides" sheet (B-095).
    @State private var mergeCandidates: MergeCandidates?

    /// Search, period filter and sort order applied (LIST-05). With "Similar to" only the rides on that
    /// route, the ride asked about first.
    private var filteredRides: [Ride] {
        let base = rides
            .filter { scope?.rideIDs.contains($0.id) ?? true }
            .filter { $0.isOnBike(bikeFilter) && $0.isFromSource(sourceFilter) }
            .filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
            // Beside the map or the analysis, their own period decides.
            .filter { scope != nil || period.contains($0.startDate) }
        guard let filter = activeSimilarFilter else {
            return base.sorted { sortOrder.areInIncreasingOrder($0.sortKey, $1.sortKey) }
        }
        let hits = similarHits ?? [:]
        var matches = base.filter { $0.id != filter.referenceID && hits[$0.id] != nil }
        switch filter.sort {
        case .similarity:
            matches.sort { (hits[$0.id]?.score ?? 0, $0.startDate) > (hits[$1.id]?.score ?? 0, $1.startDate) }
        case .date:
            matches.sort { $0.startDate > $1.startDate }
        }
        return rides.filter { $0.id == filter.referenceID } + matches
    }

    /// The filter, in the main list only.
    private var activeSimilarFilter: SimilarRidesFilter? { scope == nil ? similarFilter : nil }

    /// The rides on the route by id; `nil` while the first search runs.
    private var similarHits: [UUID: RouteIndex.Hit]? {
        guard let filter = activeSimilarFilter, let hits = similarity.hits(for: filter) else { return nil }
        return Dictionary(hits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The rides of the year card: the bike and the source of the list apply, search and period do not.
    /// The year in review opens with the same filters (B-145).
    private var yearRides: [Ride] {
        rides.filter { $0.isOnBike(bikeFilter) && $0.isFromSource(sourceFilter) }
    }

    /// Sorted by date the list is grouped by month; other orders show one flat list.
    private var groups: [(id: String, title: String?, rides: [Ride])] {
        guard sortOrder == .date, activeSimilarFilter == nil else { return [("all", nil, filteredRides)] }
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: filteredRides) {
            calendar.dateInterval(of: .month, for: $0.startDate)?.start ?? $0.startDate
        }
        return byMonth.keys.sorted(by: >).map { month in
            (month.description, month.formatted(.dateTime.month(.wide).year()), byMonth[month] ?? [])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let scope {
                Label { Text(scope.note) } icon: { Image(systemName: scope.systemImage) }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            } else if activeSimilarFilter == nil, yearRides.contains(where: \.countsInStatistics) {
                YearTileView(rides: yearRides) {
                    highlightsBikeFilter = bikeFilter
                    highlightsSourceFilter = sourceFilter
                    onShowYear()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            if let group = suggestedGroup {
                MergeSuggestionBanner(group: group) {
                    mergeCandidates = MergeCandidates(ids: Set(group.rideIDs), suggestion: group)
                } onDismiss: {
                    suggestions.dismiss(group)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.opacity)
            }
            list
            if scope == nil && !multiSelectTipDone && rides.count >= 2 {
                MultiSelectTip { multiSelectTipDone = true }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: multiSelectTipDone)
        .animation(.snappy, value: suggestedGroup?.rideIDs)
        // Rides the watched folder imported (B-096).
        .onChange(of: watcher.lastSummary) {
            suggestions.suggest(involving: watcher.lastSummary.importedRideIDs, library: library)
        }
    }

    /// The first suggestion whose rides are all still in the list (not trashed or merged since).
    private var suggestedGroup: RideMergeSuggestion.Group? {
        let ids = Set(rides.map(\.id))
        return suggestions.pending.first { $0.rideIDs.allSatisfy(ids.contains) }
    }

    /// Rides that hold a record now get a star (ADV-R2).
    private var recordHolders: Set<UUID> {
        let records = RideRecords.records(rides.filter(\.countsInStatistics).map(\.highlightRide), calendar: GoalPeriod.calendar())
        return Set(records.filter(\.kind.isRideRecord).flatMap(\.rideIDs))
    }

    private var list: some View {
        let holders = recordHolders
        let hits = similarHits
        return List(selection: $selection) {
            ForEach(groups, id: \.id) { group in
                Section {
                    ForEach(group.rides) { ride in
                        RideRow(ride: ride, isRecord: holders.contains(ride.id), showsBike: bikes.count >= 2,
                                similarity: similarBadge(for: ride, hits: hits))
                            .tag(ride.id)
                    }
                } header: {
                    if let title = group.title { Text(verbatim: title) }
                }
            }
        }
        .navigationTitle("Rides")
        .overlay {
            if let filter = activeSimilarFilter {
                similarOverlay(filter)
            } else if let scope, !rides.isEmpty, filteredRides.isEmpty, searchText.isEmpty {
                ContentUnavailableView(scope.emptyTitle, systemImage: scope.systemImage)
            } else if !rides.isEmpty && filteredRides.isEmpty {
                ContentUnavailableView("No Matching Rides", systemImage: "line.3.horizontal.decrease.circle",
                                       description: Text("Change the search or the period."))
            } else if rides.isEmpty {
                ContentUnavailableView {
                    Label("No Rides Yet", systemImage: "bicycle")
                } description: {
                    Text("Drop FIT files exported from the Bosch eBike Flow app here – or GPX files from other bikes and bike computers.")
                } actions: {
                    Button("Import Rides…") { showingImporter = true }
                }
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            importFiles(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: Self.importTypes, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .onChange(of: importRequested, initial: true) {
            guard importRequested else { return }
            importRequested = false
            showingImporter = true
        }
        // Right-click acts on the whole selection when the clicked row is part of it.
        .contextMenu(forSelectionType: UUID.self) { ids in
            contextMenu(for: ids)
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first { onOpen?(id) }
        }
        .onDeleteCommand { requestTrash(selection) }
        .onChange(of: similarFilter, initial: true) { refreshSimilar() }
        .onChange(of: rides.map(\.overviewRouteVersion)) { refreshSimilar() }
        .onChange(of: rides.map(\.id)) {
            // The ride asked about went to the trash or into a merged ride.
            if scope == nil, let filter = similarFilter, !rides.contains(where: { $0.id == filter.referenceID }) {
                similarFilter = nil
            }
            refreshSimilar()
        }
        .confirmationDialog(
            Text("Move \(trashCandidates?.count ?? 0) rides to the trash?"),
            isPresented: Binding(get: { trashCandidates != nil }, set: { if !$0 { trashCandidates = nil } }),
            presenting: trashCandidates
        ) { ids in
            Button("Move to Trash", role: .destructive) { moveToTrash(ids) }
            Button("Cancel", role: .cancel) { trashCandidates = nil }
        } message: { _ in
            Text("You can restore them from the trash for 30 days.")
        }
        .sheet(item: $mergeCandidates) { candidates in
            MergeRidesSheet(rideIDs: candidates.ids, undoManager: undoManager) {
                selection = [$0]
                if let suggestion = candidates.suggestion { suggestions.dismiss(suggestion) }
            }
        }
        .importFlow(flow)
        .alert("Rename Ride", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let ride = renaming { library.rename(ride, to: newName) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    /// Title, count, actions above the list. A plain VStack instead of a
    /// safe-area inset: the inset was counted twice after switching sections.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rides").font(.title2.bold())
                    // The sample ride is listed but not counted (ONB-02).
                    Group {
                        if let scope {
                            Text(scope.count)
                        } else {
                            if bikeFilter.isActive || sourceFilter.isActive {
                                Text("\(rides.count { !$0.isSample && $0.isOnBike(bikeFilter) && $0.isFromSource(sourceFilter) }) of \(rides.count { !$0.isSample }) rides")
                            } else {
                                Text("\(rides.count { !$0.isSample }) rides total")
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button { openWindow(id: "importLog") } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(Text("Import Log"))
                .accessibilityLabel(Text("Import Log"))
                Button { showingImporter = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(Text("Import FIT or GPX files"))
                .accessibilityLabel(Text("Import Rides…"))
                .keyboardShortcut("o", modifiers: .command)
            }
            .padding(.bottom, 8)
            // From two bikes on: which bike new rides go to (B-135).
            ImportBikeMenu()
                .padding(.bottom, 8)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search rides", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Clear search"))
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.quaternary.opacity(0.6), in: Capsule())
                filterMenu
            }
            if isFiltered {
                activeFilterChip
                    .padding(.top, 8)
            }
            if scope == nil, let current = similarFilter {
                let referenceID = current.referenceID
                // Not `Binding($similarFilter)`: that unwraps the optional again while the bar fades out
                // after ✕ set it to nil, and crashes.
                SimilarRidesBar(filter: Binding(get: { similarFilter ?? current }, set: { similarFilter = $0 }),
                                referenceName: rides.first { $0.id == referenceID }?.name ?? "",
                                found: similarHits?.count ?? 0,
                                shown: filteredRides.count { $0.id != referenceID },
                                isSearching: similarity.isSearching) {
                    withAnimation(.snappy) { similarFilter = nil }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    
    }
    /// `true` when the list differs from the default (all rides, newest first).
    private var isFiltered: Bool { (scope == nil && period != .all) || sortOrder != .date || bikeFilter.isActive || sourceFilter.isActive }

    private func resetFilters() {
        withAnimation(.snappy) {
            period = .all
            sortOrder = .date
            bikeFilterChoice = .all
            sourceFilterChoice = .all
        }
    }

    /// Shows what is active; one click on ✕ brings back the full list.
    private var activeFilterChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.caption.weight(.semibold))
            activeFilterText
                .font(.caption.weight(.medium))
            Button(action: resetFilters) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help(Text("Show all rides"))
            .accessibilityLabel(Text("Show all rides"))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// What differs from the default: period, sort order, bike and source, separated by dots.
    private var activeFilterText: Text {
        let periodActive = scope == nil && period != .all
        var parts: [Text] = []
        if periodActive { parts.append(Text(period.label)) }
        if sortOrder != .date { parts.append(periodActive ? Text(sortOrder.label) : Text("Sorted by \(Text(sortOrder.label))")) }
        if let bike = bikes.first(where: { $0.id == bikeFilter.bikeID }) { parts.append(Text(verbatim: bike.name)) }
        if sourceFilter.isActive { parts.append(Text(sourceFilter.title)) }
        guard let first = parts.first else { return Text(verbatim: "") }
        return parts.dropFirst().reduce(first) { Text("\($0) · \($1)") }
    }

    /// Sort order and period (LIST-05). Filled icon while something differs from the default.
    private var filterMenu: some View {
        Menu {
            if isFiltered {
                Button("Reset", systemImage: "arrow.counterclockwise", action: resetFilters)
                Divider()
            }
            if activeSimilarFilter == nil {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(RideSortOrder.allCases) { Text($0.label).tag($0) }
                }
            }
            if scope == nil {
                Picker("Period", selection: $period) {
                    ForEach(RidePeriod.allCases) { Text($0.label).tag($0) }
                }
                BikeFilterPicker(filter: $bikeFilterChoice)
                SourceFilterPicker(filter: $sourceFilterChoice, hasGPXRides: hasGPXRides)
            }
        } label: {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 18))
                .foregroundStyle(isFiltered ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text("Sort and filter"))
        .accessibilityLabel(Text("Sort and filter"))
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<UUID>) -> some View {
        if !ids.isEmpty {
            let single = ids.count == 1 ? rides.first { ids.contains($0.id) } : nil
            if let onOpen, let single {
                Button("Open in Ride Detail") { onOpen(single.id) }
                Divider()
            }
            Button("Rename…") {
                if let single {
                    newName = single.name
                    renaming = single
                }
            }
            .disabled(single == nil)
            if scope == nil {
                Button("Show Similar Rides", systemImage: "point.3.connected.trianglepath.dotted") {
                    if let single { showSimilar(to: single) }
                }
                .disabled(single.map { !SimilarRidesFilter.canStart(from: $0) } ?? true)
            }
            Button("Export as GPX…") { if let single { GPXExport.save(single) } }
                .disabled(single == nil)
            if ids.count > 1 {
                if RideComparison.canCompare(count: ids.count) {
                    Button("Compare \(ids.count) Rides") {
                        selection = ids
                        onCompare()
                    }
                }
                Button("Merge \(ids.count) Rides…") { mergeCandidates = MergeCandidates(ids: ids) }
            }
            if let single, single.isMerged {
                Button("Split into Original Rides") { selection = Set(library.split(single).map(\.id)) }
            }
            BikeAssignMenu(rides: rides.filter { ids.contains($0.id) }) {
                Label("Assign Bike", systemImage: "bicycle")
            }
            Divider()
            Button("Move to Trash", role: .destructive) { requestTrash(ids) }
        }
    }

    private func showSimilar(to ride: Ride) {
        guard SimilarRidesFilter.canStart(from: ride) else { return }
        withAnimation(.snappy) {
            similarFilter = SimilarRidesFilter(referenceID: ride.id, threshold: RouteSimilarity.clampedThreshold(similarDefault))
        }
        selection = [ride.id]
    }

    private func refreshSimilar() {
        // The lists beside the map and the analysis leave the search of the main list alone.
        guard scope == nil else { return }
        similarity.refresh(similarFilter, rides: rides)
    }

    private func similarBadge(for ride: Ride, hits: [UUID: RouteIndex.Hit]?) -> SimilarityBadge? {
        guard let filter = activeSimilarFilter else { return nil }
        if ride.id == filter.referenceID { return .reference }
        return hits?[ride.id].map { .match(score: $0.score, reverse: $0.direction == .reverse) }
    }

    /// Instead of the list's own empty notes while "Similar to" is on.
    @ViewBuilder
    private func similarOverlay(_ filter: SimilarRidesFilter) -> some View {
        let found = similarHits?.count
        if similarity.referenceHasRoute(for: filter) == false {
            ContentUnavailableView("This ride has no route", systemImage: "location.slash",
                                   description: Text("Only rides with GPS can be compared by route."))
        } else if found == nil {
            ProgressView().controlSize(.small)
        } else if found == 0 {
            ContentUnavailableView {
                Label("No Similar Rides", systemImage: "point.3.connected.trianglepath.dotted")
            } description: {
                Text("No other ride is \(filter.threshold.formatted(.percent.precision(.fractionLength(0)))) similar. Lower the similarity or include the opposite direction.")
            }
        } else if filteredRides.count <= 1 {
            ContentUnavailableView("No Matching Rides", systemImage: "line.3.horizontal.decrease.circle",
                                   description: Text("Change the search, the bike or the period."))
        }
    }

    @Environment(RideLibrary.self) private var sharedLibrary
    private var library: RideLibrary { sharedLibrary.using(undoManager) }

    private static let importTypes: [UTType] = [UTType(filenameExtension: "fit") ?? .data, UTType(filenameExtension: "gpx") ?? .xml]

    private func importFiles(_ urls: [URL]) {
        flow.onImported = { ids in
            suggestions.suggest(involving: ids, library: library)
            if let last = ids.last { selection = [last] }
        }
        flow.onSelect = { selection = [$0] }
        flow.start(urls, library: library, importLog: importLog)
    }

    /// One ride goes to the trash right away (⌘Z undoes it); several ask first.
    private func requestTrash(_ ids: Set<UUID>) {
        if ids.count > 1 { trashCandidates = ids } else { moveToTrash(ids) }
    }

    private func moveToTrash(_ ids: Set<UUID>) {
        // Collect the rides before touching the selection, which the list updates.
        let targets = rides.filter { ids.contains($0.id) }
        selection.subtract(ids)
        trashCandidates = nil
        library.moveToTrash(targets)
    }
}

/// The ride list beside the map or the analysis shows only their rides (B-123, B-124).
struct RideListScope: Equatable {
    var rideIDs: Set<UUID>
    /// "31 of 46 rides in the visible area" under the title.
    var count: LocalizedStringKey
    /// What the list follows, in the bar above it.
    var note: LocalizedStringKey
    var emptyTitle: LocalizedStringKey
    var systemImage: String

    static func map(_ ids: Set<UUID>, total: Int) -> Self {
        RideListScope(rideIDs: ids, count: "\(ids.count) of \(total) rides in the visible area",
                      note: "Only rides in the visible area – follows panning and zooming.",
                      emptyTitle: "No Rides in the Visible Area", systemImage: "map")
    }

    static func analysis(_ ids: Set<UUID>) -> Self {
        RideListScope(rideIDs: ids, count: "\(ids.count) rides in this analysis",
                      note: "Only the rides in this analysis – follows the period.",
                      emptyTitle: "No Rides in This Period", systemImage: "chart.bar")
    }
}

/// The selection handed to the merge sheet.
struct MergeCandidates: Identifiable {
    let id = UUID()
    let ids: Set<UUID>
    /// Set when the merge was suggested after an import (B-096).
    var suggestion: RideMergeSuggestion.Group?
}

/// One row: route preview (B-064), name, date and the three key numbers (LIST-01).
struct RideRow: View {
    let ride: Ride
    var isRecord = false
    /// Shows the bike's symbol at the end of the second line (B-136, from two bikes on).
    var showsBike = false
    /// With "Similar to": the ride asked about, or how similar this one is (B-118).
    var similarity: SimilarityBadge? = nil

    var body: some View {
        HStack(spacing: 12) {
            RoutePreviewView(ride: ride)
            details
        }
        .padding(.vertical, 4)
        // One VoiceOver element per row: route, name, date, time, distance, speed.
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(ride.name).font(.headline)
                if ride.isSample { SampleBadge() }
                if ride.isMerged { MergedBadge(count: ride.parts?.count ?? 0) }
                if isRecord {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .help(Text("Holds a record"))
                        .accessibilityLabel(Text("Holds a record"))
                }
                if let similarity { SimilarityTag(badge: similarity) }
                Spacer()
                Text(RideFormat.relativeDate(ride.startDate, timeZone: ride.timeZone))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .center) {
                Text(verbatim: "\(RideFormat.duration(ride.timerTime)) · \(RideFormat.distance(ride.distance)) · \(RideFormat.speed(ride.averageSpeed))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let badge = ride.sourceBadge { SourcePill(badge: badge) }
                if showsBike, let bike = ride.bike {
                    RideRowBike(bike: bike)
                }
            }
        }
    }
}

/// The bike's symbol in a row; light on the accent colored background of a selected row.
private struct RideRowBike: View {
    let bike: Bike
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        BikeChip(kind: bike.kind, color: bike.color, size: 22, onAccent: prominence == .increased, accessibilityName: bike.name)
            .help(Text(verbatim: bike.name))
    }
}

/// A quiet tip below the list (B-113): testers did not find out that ⌘-click selects
/// several rides. It goes away after the first multiple selection or with ✕.
struct MultiSelectTip: View {
    static let storageKey = SettingsKey.multiSelectTipDone
    let onHide: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .accessibilityHidden(true)
            Text("⌘-click selects several rides – to analyze, compare or merge them.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onHide) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .help(Text("Hide tip"))
            .accessibilityLabel(Text("Hide tip"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}

/// Summary shown after an import (simple form of the import log, IMP-06).
struct ImportReport: Identifiable {
    struct Entry {
        let url: URL
        let result: ImportResult
    }

    let id = UUID()
    let entries: [Entry]
    var extraLines: [String] = []
    /// Results that get their own question (a GPX or a Bosch file for a GPX ride, B-144) and are not
    /// part of the all-at-once question for plain duplicates.
    var excluded: Set<UUID> = []

    /// Rides that were already there and are decided on together (IMP-02).
    var duplicates: [Entry] {
        entries.filter { $0.result.outcome.existingRideID != nil && !excluded.contains($0.result.id) }
    }

    /// `true` if there is something to tell besides duplicates and attached GPX files, which have
    /// their own question or notice.
    var hasNews: Bool {
        !extraLines.isEmpty || entries.contains { entry in
            switch entry.result.outcome {
            case .imported, .unsupported, .failed: true
            case .duplicate, .attached, .fitForGPX: false
            }
        }
    }

    /// At most this many file or ride names are listed; the rest is only counted,
    /// so the alert keeps its button on screen even for hundreds of files.
    static let maxListedNames = 5

    /// Imported count and problems, without duplicates. Unsupported files are
    /// summarised by type instead of being listed one by one.
    private var summaryLines: [String] {
        var imported = 0
        var unsupported: [String] = []
        var unreadable: [String] = []
        for entry in entries {
            switch entry.result.outcome {
            case .imported: imported += 1
            case .duplicate, .attached, .fitForGPX: break
            case .unsupported: unsupported.append(entry.result.fileName)
            case .failed: unreadable.append(entry.result.fileName)
            }
        }
        var lines = entries.isEmpty ? [] : [String(localized: "\(imported) rides imported")]
        if !unsupported.isEmpty {
            let types = Set(unsupported.map(Self.typeLabel)).sorted().formatted(.list(type: .and))
            lines.append(String(localized: "\(unsupported.count) files skipped, file type not supported yet: \(types)"))
        }
        lines += Self.unreadableLines(unreadable) + extraLines
        return lines
    }

    /// "x.fit: file could not be read" for the first few, then "3 more files could not be read".
    static func unreadableLines(_ fileNames: [String]) -> [String] {
        var lines = fileNames.prefix(maxListedNames).map { String(localized: "\($0): file could not be read") }
        let rest = fileNames.count - maxListedNames
        if rest > 0 { lines.append(String(localized: "\(rest) more files could not be read")) }
        return lines
    }

    /// ".gpx", or "no extension".
    private static func typeLabel(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext.isEmpty ? String(localized: "no extension") : ".\(ext)"
    }

    var message: String { summaryLines.joined(separator: "\n") }

    /// Message of the duplicate dialog: what happened so far, then the question.
    var duplicateQuestion: String {
        var names = duplicates.prefix(Self.maxListedNames).map { RideLibrary.parseFileName($0.result.fileName).title }
        let rest = duplicates.count - Self.maxListedNames
        if rest > 0 { names.append(String(localized: "\(rest) more")) }
        var lines = summaryLines
        lines.append(String(localized: "Already in your library: \(names.formatted(.list(type: .and)))"))
        lines.append(String(localized: "Update them from the new files? Your names are kept."))
        return lines.joined(separator: "\n")
    }
}

extension RideSortOrder {
    var label: LocalizedStringKey {
        switch self {
        case .date: "Date"
        case .distance: "Distance"
        case .duration: "Ride time"
        case .ascent: "Ascent"
        case .averagePower: "Avg power"
        }
    }
}

extension RidePeriod {
    var label: LocalizedStringKey {
        switch self {
        case .all: "All Rides"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        case .thisYear: "This Year"
        case .last30Days: "Last 30 Days"
        case .last365Days: "Last 365 Days"
        }
    }
}
