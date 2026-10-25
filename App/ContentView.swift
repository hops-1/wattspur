import SwiftData
import SwiftUI
import WattspurKit

extension Notification.Name {
    /// Settings asks the main window to show the profile section.
    static let showProfile = Notification.Name("io.github.hops-1.wattspur.showProfile")
}

enum AppSection: Hashable {
    case rides, analysis, highlights, map, trash, profile
}

/// Main window: sidebar, ride list and detail (B-021).
///
/// The sidebar is our own view instead of the split view's sidebar column, because
/// the system column cannot shrink to an icon-only rail (it keeps a minimum width
/// and only hides completely).
struct ContentView: View {
    @State private var section: AppSection = .rides
    /// The main window, to bring it forward when Settings asks for the profile.
    @State private var window: NSWindow?
    @State private var selectedRideIDs: Set<UUID> = []
    /// Rides chosen in the list for the analysis (LIST-06); `nil` = analyse by period.
    @State private var analysisSelection: Set<UUID>?
    /// The selected rides are shown side by side (B-100, CMP-01).
    @State private var comparing = false
    /// "Import Rides…" on the empty map opens the list's import dialog.
    @State private var importRequested = false
    /// The map's visible area, kept while another section is open.
    @State private var mapMemory = MapMemory()
    /// Rides the analysis handed to the map ("Show on Map"); `nil` = the map's own period.
    @State private var mapAnalysisRides: Set<UUID>?
    /// What the lists beside the map and the analysis show (B-123, B-124).
    @State private var mapRidesInView: (ids: Set<UUID>, total: Int) = ([], 0)
    @State private var analysedRideIDs: Set<UUID> = []
    /// Where a ride opened from the list beside the map or the analysis, or from the
    /// highlights, came from; the ride detail then offers "Back to Map", "Back to
    /// Analysis" or "Back to Highlights" (⌘[).
    @State private var returnSection: AppSection?
    @AppStorage("sidebarCompact") private var sidebarCompact = false
    /// The ⌘-click tip goes away for good after the first multiple selection (B-113).
    @AppStorage(MultiSelectTip.storageKey) private var multiSelectTipDone = false
    @AppStorage("sidebarWidth") private var sidebarWidth = 220.0
    @AppStorage("listWidth") private var listWidth = 340.0
    @Environment(\.modelContext) private var modelContext
    @Environment(FolderWatcher.self) private var watcher
    @Environment(NewPathsStore.self) private var newPaths
    @Environment(BikeAssignmentNotice.self) private var assignmentNotice
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    /// The setup assistant shows until it was finished or skipped once (ONB-01).
    @AppStorage("setupCompleted") private var setupCompleted = false
    /// The one-time note after the update to 1.5 (B-138); the setup assistant sets it too.
    @AppStorage("bikesHintDone") private var bikesHintDone = false
    @Query(filter: #Predicate<Bike> { !$0.isArchived }, sort: \Bike.sortOrder) private var openBikes: [Bike]
    @Query private var allRides: [Ride]
    private var rideCount: Int { allRides.count }
    /// Tab and year shown in Highlights; the year tile and the record links open them.
    @State private var highlightsTab: HighlightsTab = .year
    @State private var highlightsYear: Int?
    /// "New record" after an import (ADV-R2).
    @State private var recordNotice: RecordNotice?
    /// The newest imported file; a change means something was imported (from any source).
    @Query(filter: #Predicate<ImportRecord> { $0.outcomeRaw == "imported" }, sort: \ImportRecord.date, order: .reverse)
    private var importEntries: [ImportRecord]

    // The body is split into stages (columns, layout, notices, body): one long
    // modifier chain was too much for the type checker of older Xcode versions.
    var body: some View {
        notices
            .frame(minWidth: 1000, minHeight: 640)
            .background(WindowReader { window = $0 })
            .onReceive(NotificationCenter.default.publisher(for: .showProfile)) { _ in
                section = .profile
                NSApplication.shared.activate()
                window?.makeKeyAndOrderFront(nil)
            }
            // Look up missing start-location time zones (new imports, or offline before).
            .task(id: rideCount) { await TimeZoneResolver.resolveMissing(in: modelContext) }
            // New paths follow every change of the rides (B-115); unchanged rides cost a hash.
            .onChange(of: allRides.map(\.overviewRouteVersion), initial: true) { newPaths.update(allRides) }
            .onChange(of: allRides.map(\.deletedAt)) { newPaths.update(allRides) }
            .onChange(of: allRides.map { $0.mergedInto?.id }) { newPaths.update(allRides) }
            // Import what arrived in the watched folder while Wattspur was closed (IMP-05).
            .task {
                RecordCheck.prepare()
                checkRecords()
                watcher.start()
            }
            .sheet(isPresented: Binding(get: { !setupCompleted }, set: { if !$0 { setupCompleted = true } })) {
                SetupAssistantView()
                    .environment(watcher)
            }
            #if DEBUG
            // Screenshots need a front window: MapKit does not draw in a window that is covered.
            .task { startDemoMode() }
            #endif
            .onChange(of: section) { sectionChanged() }
            // A single ride (or none) ends the comparison; more than 4 only pauses it.
            .onChange(of: selectedRideIDs) {
                if selectedRideIDs.count < 2 { comparing = false } else { multiSelectTipDone = true }
            }
    }

    private var layout: some View {
        // A fixed layout instead of NavigationSplitView: the split view restores
        // stored column widths and ignores our minimums, which squeezed the list.
        NavigationStack { columns }
            // The title would overlap our own sidebar; the list shows its own header instead.
            .toolbar(removing: .title)
            // Keep a regular-height toolbar: without one, macOS moves the traffic-light
            // buttons to the very top-left edge, outside our floating sidebar panel.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }

    private var columns: some View {
        HStack(spacing: 0) {
            SidebarRail(section: $section, compact: $sidebarCompact, width: sidebarWidth)
            ColumnResizeHandle(
                width: Binding(get: { sidebarCompact ? SidebarRail.compactWidth : sidebarWidth },
                               set: { setSidebarWidth($0) }),
                range: SidebarRail.compactWidth...320
            )
            if section == .analysis {
                scopedList(.analysis(analysedRideIDs))
                AnalysisView(selection: analysisSelection) { analysisSelection = nil } onShowOnMap: { ids in
                    mapAnalysisRides = ids
                    section = .map
                } onAnalysedRidesChange: { analysedRideIDs = $0 }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if section == .highlights {
                HighlightsView(tab: $highlightsTab, year: $highlightsYear) { ids in
                    // "Back to Highlights" returns to the same tab and year (B-128).
                    returnSection = .highlights
                    selectedRideIDs = Set(ids)
                    section = .rides
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if section == .profile {
                ProfileView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if section == .map {
                scopedList(.map(mapRidesInView.ids, total: mapRidesInView.total))
                AllRidesMapView(selectedRideIDs: selectedRideIDs, memory: $mapMemory, analysisRides: mapAnalysisRides,
                                onClearAnalysisRides: { mapAnalysisRides = nil },
                                onRidesInViewChange: { mapRidesInView = ($0, $1) },
                                onSelectRides: { selectedRideIDs = $0 },
                                onOpenRide: { id in
                                    returnSection = .map
                                    selectedRideIDs = [id]
                                    section = .rides
                                }) { ids in
                    analysisSelection = ids
                    section = .analysis
                } onImport: {
                    // The list beside the map opens the import dialog.
                    importRequested = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch section {
                    case .trash: TrashView()
                    default:
                        RideListView(selection: $selectedRideIDs, importRequested: $importRequested) { comparing = true } onShowYear: {
                            highlightsTab = .year
                            highlightsYear = nil
                            section = .highlights
                        }
                    }
                }
                .frame(width: listWidth)
                ColumnResizeHandle(width: $listWidth, range: 260...520, showsDivider: true)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Record, bike-hint and bike-assignment notices over the layout.
    private var notices: some View {
        layout
            .overlay(alignment: .top) {
                if let notice = recordNotice {
                    RecordNoticeView(notice: notice) {
                        if let id = notice.rideID { selectedRideIDs = [id] }
                        section = .rides
                        recordNotice = nil
                    } onClose: { recordNotice = nil }
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if showsBikesHint {
                    BikesHintBanner(bikeName: openBikes.first?.name.nonEmpty ?? RideLibrary.defaultBikeName) {
                        bikesHintDone = true
                        section = .profile
                    } onLater: { bikesHintDone = true }
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: showsBikesHint)
            .overlay(alignment: .bottom) {
                if let notice = assignmentNotice.current {
                    BikeAssignmentNoticeView(notice: notice) {
                        undoManager?.undo()
                        assignmentNotice.hide()
                    } onClose: { assignmentNotice.hide() }
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: recordNotice)
            .animation(.snappy, value: assignmentNotice.current)
            .task(id: assignmentNotice.current?.id) {
                guard let notice = assignmentNotice.current else { return }
                try? await Task.sleep(for: .seconds(10))
                if assignmentNotice.current?.id == notice.id { assignmentNotice.hide() }
            }
            .task(id: recordNotice?.id) {
                guard let notice = recordNotice else { return }
                AccessibilityNotification.Announcement("\(notice.title). \(notice.lines.joined(separator: ". "))").post()
                try? await Task.sleep(for: .seconds(20))
                if recordNotice?.id == notice.id { recordNotice = nil }
            }
            .onChange(of: importEntries.first?.date) { checkRecords() }
    }

    private func sectionChanged() {
        // Whoever has seen the profile needs no hint about it.
        if section == .profile { bikesHintDone = true }
        if section == .rides, returnSection == nil {
            // Back in the list, the analysis and the map return to their periods.
            analysisSelection = nil
            mapAnalysisRides = nil
        } else if section != .rides {
            returnSection = nil
        }
    }

    #if DEBUG
    private func startDemoMode() {
        guard DemoMode.isOn else { return }
        if let id = DemoMode.rideID { selectedRideIDs = [id] }
        NSApplication.shared.activate()
        switch DemoMode.section {
        case "analysis"?: section = .analysis
        case "highlights"?: section = .highlights
        case "records"?: highlightsTab = .records; section = .highlights
        case "goals"?: highlightsTab = .goals; section = .highlights
        case "map"?: section = .map
        case "profile"?: section = .profile
        default: break
        }
        switch DemoMode.window {
        case "settings"?: openSettings()
        case let id?: openWindow(id: id)
        case nil: break
        }
    }
    #endif

    /// Only for a library that was there before 1.5: the assistant already asks fresh ones.
    private var showsBikesHint: Bool {
        setupCompleted && !bikesHintDone && section != .profile && recordNotice == nil
    }

    /// The ride list beside the map or the analysis, limited to their rides; the
    /// selection is the same as under Rides (B-123, B-124).
    @ViewBuilder
    private func scopedList(_ scope: RideListScope) -> some View {
        RideListView(selection: $selectedRideIDs, importRequested: $importRequested, onCompare: {
            comparing = true
            section = .rides
        }, scope: scope) { id in
            returnSection = section
            selectedRideIDs = [id]
            section = .rides
        }
            .frame(width: listWidth)
        ColumnResizeHandle(width: $listWidth, range: 260...520, showsDivider: true)
    }

    @ViewBuilder
    private var detail: some View {
        if section == .trash || selectedRideIDs.isEmpty {
            ContentUnavailableView {
                Label("Select a ride", systemImage: "bicycle")
            } description: {
                if section != .trash && !multiSelectTipDone {
                    Text("⌘-click selects several rides, so you can analyze, compare or merge them.")
                }
            }
        } else if selectedRideIDs.count == 1, let id = selectedRideIDs.first {
            VStack(spacing: 0) {
                if let back = returnSection {
                    backBar(to: back)
                }
                RideDetailView(rideID: id) { selectedRideIDs = Set($0) } onShowRecords: {
                    highlightsTab = .records
                    section = .highlights
                }
            }
        } else if comparing && RideComparison.canCompare(count: selectedRideIDs.count) {
            CompareRidesView(rideIDs: selectedRideIDs) { selectedRideIDs = [$0] } onRemove: {
                selectedRideIDs.remove($0)
            } onDone: { comparing = false }
        } else {
            VStack(spacing: 0) {
                // Several rides of a day or a streak from the highlights (B-128).
                if let back = returnSection {
                    backBar(to: back)
                }
                MultiSelectionView(rideIDs: selectedRideIDs) {
                    analysisSelection = selectedRideIDs
                    section = .analysis
                } onCompare: { comparing = true } onMerged: { selectedRideIDs = [$0] }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// "‹ Back to Map" above a ride opened from the list beside the map or the analysis,
    /// "‹ Back to Highlights" above rides opened from the highlights.
    private func backBar(to target: AppSection) -> some View {
        HStack {
            Button {
                section = target
            } label: {
                switch target {
                case .map: Label("Back to Map", systemImage: "chevron.left")
                case .highlights: Label("Back to Highlights", systemImage: "chevron.left")
                default: Label("Back to Analysis", systemImage: "chevron.left")
                }
            }
            .buttonStyle(.glass)
            .keyboardShortcut("[", modifiers: .command)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
    }

    private func checkRecords() {
        if let notice = RecordCheck.run(in: modelContext) { recordNotice = notice }
    }

    /// Dragging the sidebar narrower than the snap point switches to icons only,
    /// wider switches back (with the full width kept between 180 and 320 pt).
    private func setSidebarWidth(_ width: Double) {
        let snap = 130.0
        if sidebarCompact {
            if width > snap { sidebarCompact = false; sidebarWidth = max(180, width) }
        } else if width < snap {
            sidebarCompact = true
        } else {
            sidebarWidth = min(320, max(180, width))
        }
    }
}

/// Hands the view's window to SwiftUI state.
private struct WindowReader: NSViewRepresentable {
    let onChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onChange(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { onChange(view.window) }
    }
}

/// A thin, draggable column boundary (replaces the split view's dividers).
struct ColumnResizeHandle: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    var showsDivider = false

    @State private var startWidth: Double?

    var body: some View {
        ZStack {
            if showsDivider { Divider() }
        }
        .frame(width: 1)
        .frame(maxHeight: .infinity)
        .overlay {
            // Wider invisible grab area around the line.
            Color.clear
                .frame(width: 9)
                .contentShape(Rectangle())
                .pointerStyle(.columnResize)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            let start = startWidth ?? width
                            startWidth = start
                            width = min(range.upperBound, max(range.lowerBound, start + value.translation.width))
                        }
                        .onEnded { _ in startWidth = nil }
                )
        }
        .zIndex(1)
        .accessibilityHidden(true)
    }
}

/// Floating sidebar in the macOS 26 style; full width or icons only.
struct SidebarRail: View {
    @Binding var section: AppSection
    @Binding var compact: Bool
    var width: Double = 220
    /// Wide enough that the window's traffic-light buttons sit inside the panel.
    static let compactWidth = 84.0
    @Query(filter: #Predicate<Ride> { $0.deletedAt != nil }) private var trashedRides: [Ride]
    @Query private var riders: [Rider]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Keep clear of the title bar: clicks there move the window instead of
            // reaching our buttons. Both modes start below the traffic lights.
            if compact {
                toggleButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, 44)
                    .padding(.bottom, 14)
            } else {
                HStack {
                    Text("Library")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    toggleButton
                }
                .padding(.leading, 10)
                .padding(.top, 40)
                .padding(.bottom, 4)
            }
            row("Rides", systemImage: "bicycle", target: .rides, shortcut: "1")
            row("Analysis", systemImage: "chart.bar", target: .analysis, shortcut: "2")
            row("Highlights", systemImage: "trophy", target: .highlights, shortcut: "4")
            // ⌘3 stays with the trash.
            row("Map", systemImage: "map", target: .map, shortcut: "5")

            Spacer()

            row("Trash", systemImage: "trash", target: .trash, shortcut: "3",
                badge: trashedRides.isEmpty ? nil : trashedRides.count)
            profileRow
        }
        .padding(10)
        .frame(width: compact ? Self.compactWidth : width)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator.opacity(0.6)))
        .padding(8)
        .ignoresSafeArea(.container, edges: .top)
    }

    /// The profile section: the rider's avatar and name (B-049, B-134).
    private var profileRow: some View {
        let rider = riders.first
        let name = rider?.name.nonEmpty
        let selected = section == .profile
        return Button { section = .profile } label: {
            HStack(spacing: 10) {
                RiderAvatar(rider: rider, size: 26)
                if !compact {
                    if let name { Text(verbatim: name).lineLimit(1) } else { Text("Profile") }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, compact ? 0 : 6)
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .background(selected ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("6", modifiers: .command)
        .help(Text("Profile"))
        .accessibilityLabel(Text("Profile"))
        .accessibilityValue(name.map { Text(verbatim: $0) } ?? Text(verbatim: ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .overlay(alignment: .top) { Divider() }
        .padding(.top, 4)
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.snappy) { compact.toggle() }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15))
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(compact ? "Expand Sidebar" : "Collapse Sidebar"))
        .accessibilityLabel(Text(compact ? "Expand Sidebar" : "Collapse Sidebar"))
        .keyboardShortcut("s", modifiers: [.command, .control])
    }

    /// A section button; ⌘1 … ⌘6 switch sections from anywhere in the window (NFR-16).
    private func row(_ title: LocalizedStringKey, systemImage: String, target: AppSection,
                     shortcut: KeyEquivalent, badge: Int? = nil,
                     enabled: Bool = true) -> some View {
        let selected = section == target
        return Button {
            section = target
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 17 : 14))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 22)
                if !compact {
                    Text(title)
                    Spacer(minLength: 4)
                    if let badge {
                        Text(verbatim: badge.formatted())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, compact ? 0 : 8)
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .background(selected ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .help(Text(title))
        .keyboardShortcut(shortcut, modifiers: .command)
        // In the icon-only rail the label is not visible, so name the button explicitly.
        .accessibilityLabel(Text(title))
        .accessibilityValue(badge.map { Text("\($0) rides") } ?? Text(verbatim: ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WattspurSchema.models, inMemory: true)
}
