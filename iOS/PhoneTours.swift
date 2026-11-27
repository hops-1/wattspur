import SwiftUI
import WattspurCore

/// The tab “Tours” (B-373, list B of B-371): planned tours, e.g. from komoot, as cards with a
/// preview of the line in blue. The search field with “+” and the filter pills sit at the top, as in
/// the rides; there is no title. In landscape and on the iPad the chosen tour is shown beside the list.
///
/// Everything shown comes from `PhoneLibrary.plannedTours`, read in `reload()`; nothing here reads the
/// store (rule 16).
struct PlannedToursView: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(PhoneImport.self) private var phoneImport
    @Environment(\.isLandscape) private var isLandscape
    @Environment(\.isPadLayout) private var isPadLayout
    @State private var filter = PlannedTourFilter()
    /// The tour beside the list in landscape and on the iPad; the newest until one is tapped.
    @State private var selection: UUID?
    /// The tour whose name is being changed, from the context menu.
    @State private var renaming: PlannedTourSummary?
    /// A tour opened without a tap: `-WattspurDemoOpenTour YES` in Debug builds, for the simulator.
    @State private var openedID: UUID?

    /// The width this view has; on an iPad in portrait beside the sidebar it can be too narrow for
    /// list and detail side by side.
    @State private var width: CGFloat = 1000

    /// List and detail side by side: in landscape on the iPhone, on the iPad when there is room for
    /// both (an iPad mini in portrait beside the open sidebar has not).
    private var sideBySide: Bool { isLandscape || (isPadLayout && width >= Self.splitWidth) }

    /// The list (320 pt) and a detail of at least 360 pt.
    static let splitWidth: CGFloat = 680

    var body: some View {
        let shown = filter.apply(library.plannedTours)
        Group {
            if sideBySide {
                split(shown)
            } else {
                list(shown)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .navigationTitle(isPadLayout ? "Planned Tours" : "Tours")
        .sheet(item: $renaming) { tour in
            RenameTourSheet(tour: tour)
        }
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "WattspurDemoOpenTour") { openedID = library.plannedTours.first?.id }
        }
        #endif
    }

    // MARK: - Layouts

    /// Portrait on the iPhone: the cards, each opening the detail.
    private func list(_ shown: [PlannedTourSummary]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if library.problem != nil { StateLine() }
                ForEach(shown) { tour in
                    NavigationLink {
                        PlannedTourDetailView(tour: tour)
                    } label: {
                        PlannedTourCard(tour: tour)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { actions(for: tour) }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await library.refresh() }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) { filterBar(shown) }
        .overlay { emptyState(shown) }
        .navigationDestination(isPresented: Binding(get: { openedID != nil && !sideBySide },
                                                    set: { if !$0 { openedID = nil } })) {
            if let tour = library.plannedTours.first(where: { $0.id == openedID }) {
                PlannedTourDetailView(tour: tour)
            }
        }
    }

    /// Landscape (as the rides, B-243) and the iPad: the cards on the left, the detail on the right.
    private func split(_ shown: [PlannedTourSummary]) -> some View {
        let chosen = shown.first { $0.id == selection } ?? shown.first
        return HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if library.problem != nil { StateLine() }
                    ForEach(shown) { tour in
                        Button {
                            selection = tour.id
                        } label: {
                            PlannedTourCard(tour: tour, compact: true, selected: tour.id == chosen?.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(tour.id == chosen?.id ? .isSelected : [])
                        .contextMenu { actions(for: tour) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await library.refresh() }
            .scrollDismissesKeyboard(.immediately)
            .tabBarRoomInLandscape()
            .safeAreaInset(edge: .top, spacing: 0) { filterBar(shown) }
            .frame(width: 320)
            .overlay { emptyState(shown) }
            Divider()
            if let chosen {
                PlannedTourDetailView(tour: chosen, embedded: true)
                    .id(chosen.id)
            } else {
                Color.clear
            }
        }
    }

    private func filterBar(_ shown: [PlannedTourSummary]) -> some View {
        PlannedTourFilterBar(filter: $filter, compact: sideBySide,
                             hasSeveralSources: Set(library.plannedTours.map(\.source)).count > 1,
                             shown: shown.count, total: library.plannedTours.count,
                             importFiles: { phoneImport.choosingFiles = true })
    }

    @ViewBuilder private func emptyState(_ shown: [PlannedTourSummary]) -> some View {
        if library.plannedTours.isEmpty {
            ContentUnavailableView {
                Label("No Planned Tours", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
            } description: {
                Text("Plan a tour in komoot or another planner, export it as GPX and share it with Wattspur, or import the file here.")
            } actions: {
                Button("Import GPX File …") { phoneImport.choosingFiles = true }
            }
        } else if shown.isEmpty {
            ContentUnavailableView {
                Label("No Matches", systemImage: "magnifyingglass")
            } description: {
                Text("Change the search or the filters.")
            } actions: {
                Button("Show All Tours") { filter = PlannedTourFilter() }
            }
        }
    }

    @ViewBuilder private func actions(for tour: PlannedTourSummary) -> some View {
        ShareLink(item: library.sharedGPX(for: tour), preview: SharePreview(tour.name)) {
            Label("Share GPX", systemImage: "square.and.arrow.up")
        }
        Button("Rename …", systemImage: "pencil") { renaming = tour }
        Button("Move to Trash", systemImage: "trash", role: .destructive) { library.moveToTrash(tour) }
    }
}

// MARK: - Card

/// A tour as a card: the line on the left, name and figures on the right.
struct PlannedTourCard: View {
    var tour: PlannedTourSummary
    /// Smaller, in the list beside the detail.
    var compact = false
    var selected = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            PlannedTourPreview(points: tour.preview)
                .frame(width: compact ? 64 : 84, height: compact ? 64 : 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(tour.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(PlannedTourFormat.figures(tour))
                    .font(.subheadline)
                    .monospacedDigit()
                Text(PlannedTourFormat.kind(tour))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !compact {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(compact ? 8 : 10)
        .background(selected ? AnyShapeStyle(PlannedTourColor.line(scheme).opacity(0.16)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                    in: .rect(cornerRadius: compact ? 16 : 20))
        .contentShape(.rect(cornerRadius: compact ? 16 : 20))
        .accessibilityElement(children: .combine)
    }
}

/// The line of a tour, drawn without a map: a map per card would cost memory (B-382), and the shape
/// alone tells the tours apart. Start and end as dots.
struct PlannedTourPreview: View {
    var points: [PlannedTour.Point]
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let color = PlannedTourColor.line(scheme)
        Canvas { context, size in
            let projected = Self.project(points, into: size, inset: 8)
            guard projected.count > 1, let first = projected.first, let last = projected.last else { return }
            var path = Path()
            path.addLines(projected)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            for (spot, filled) in [(last, false), (first, true)] {
                let dot = Path(ellipseIn: CGRect(x: spot.x - 4, y: spot.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(filled ? color : Color(.systemBackground)))
                context.stroke(dot, with: .color(color), lineWidth: 2)
            }
        }
        .background(color.opacity(0.1), in: .rect(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    /// The points in the box, north up, with the same scale on both axes.
    static func project(_ points: [PlannedTour.Point], into size: CGSize, inset: CGFloat) -> [CGPoint] {
        guard let first = points.first else { return [] }
        // Longitude shrinks towards the poles.
        let xScale = cos(first.latitude * .pi / 180)
        let xs = points.map { $0.longitude * xScale }
        let ys = points.map(\.latitude)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }
        let width = max(maxX - minX, 1e-9), height = max(maxY - minY, 1e-9)
        let box = CGSize(width: max(size.width - 2 * inset, 1), height: max(size.height - 2 * inset, 1))
        let scale = min(box.width / width, box.height / height)
        let offsetX = inset + (box.width - width * scale) / 2
        let offsetY = inset + (box.height - height * scale) / 2
        return zip(xs, ys).map { x, y in
            CGPoint(x: offsetX + (x - minX) * scale, y: offsetY + (maxY - y) * scale)
        }
    }
}

/// How the figures of a tour read in the list and the detail.
enum PlannedTourFormat {
    /// “42.3 km · ↑ 512 m”.
    static func figures(_ tour: PlannedTourSummary) -> String {
        let distance = RideFormat.distance(tour.distance)
        guard let ascent = tour.ascent else { return distance }
        return "\(distance) · ↑ \(RideFormat.ascent(ascent))"
    }

    /// “Loop · komoot”.
    static func kind(_ tour: PlannedTourSummary) -> String {
        "\(shape(tour)) · \(source(tour.source))"
    }

    static func shape(_ tour: PlannedTourSummary) -> String {
        tour.isLoop ? String(localized: "Loop") : String(localized: "One Way")
    }

    static func source(_ source: PlannedTour.Source) -> String {
        switch source {
        case .komoot: "komoot"
        case .gpx: String(localized: "GPX File")
        }
    }
}

// MARK: - Search and filters

/// Search field with “+” and the filter pills above the tours, in the look of `RideFilterBar`.
struct PlannedTourFilterBar: View {
    @Binding var filter: PlannedTourFilter
    var compact = false
    /// The source pill only when the tours come from more than one source.
    var hasSeveralSources = false
    var shown: Int
    var total: Int
    var importFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: 8) {
                searchField
                Button(action: importFiles) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: compact ? 32 : 36, height: compact ? 32 : 36)
                        .background(Color.secondary.opacity(0.12), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Import GPX File …"))
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) { pills }
            }
            .scrollIndicators(.hidden)
            if filter.isActive {
                Text("\(shown) of \(total) tours")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, compact ? 6 : 8)
        .background(.bar, ignoresSafeAreaEdges: [])
    }

    @ViewBuilder private var pills: some View {
        pill("Loops", active: filter.shape == .loop) { filter.shape = filter.shape == .loop ? .all : .loop }
        pill("One Way", active: filter.shape == .oneWay) { filter.shape = filter.shape == .oneWay ? .all : .oneWay }
        Menu {
            Picker("Distance", selection: $filter.distance) {
                ForEach(RideDistanceBand.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            FilterChip(title: filter.distance == .all ? "Distance" : filter.distance.label, active: filter.distance != .all)
        }
        if hasSeveralSources {
            Menu {
                Picker("Source", selection: $filter.source) {
                    Text("All sources").tag(PlannedTour.Source?.none)
                    ForEach(PlannedTour.Source.allCases, id: \.self) { source in
                        Text(verbatim: PlannedTourFormat.source(source)).tag(PlannedTour.Source?.some(source))
                    }
                }
            } label: {
                if let source = filter.source {
                    FilterChip(verbatim: PlannedTourFormat.source(source), active: true)
                } else {
                    FilterChip(title: "Source", active: false)
                }
            }
        }
        if filter.hasFilters {
            Button {
                filter.distance = .all
                filter.shape = .all
                filter.source = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Reset"))
        }
    }

    /// A pill that switches on and off, without a menu.
    private func pill(_ title: LocalizedStringKey, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .font(.subheadline.weight(active ? .semibold : .regular))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .foregroundStyle(active ? Color.track : Color.primary)
                .background(active ? Color.track.opacity(0.15) : Color.secondary.opacity(0.12), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search tours", text: $filter.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !filter.text.isEmpty {
                Button { filter.text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: compact ? 32 : 36)
        .background(Color.secondary.opacity(0.12), in: .capsule)
    }
}

// MARK: - Rename

/// A new name for a tour; iCloud brings it to the other devices.
struct RenameTourSheet: View {
    @Environment(PhoneLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    let tour: PlannedTourSummary
    @State private var name: String

    init(tour: PlannedTourSummary) {
        self.tour = tour
        _name = State(initialValue: tour.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .submitLabel(.done)
                    .onSubmit(save)
            }
            .navigationTitle("Rename Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func save() {
        library.rename(tour, to: name)
        dismiss()
    }
}
