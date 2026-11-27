import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// “Planned Tours” in the sidebar (B-385, design B-371 “Mac”): a table with name, distance, ascent
/// and source, a drop zone for GPX files from komoot, the detail beside it (`PlannedTourDetailView`).
struct PlannedToursView: View {
    @Binding var selection: UUID?

    @Environment(RideLibrary.self) private var sharedLibrary
    @Environment(ImportLog.self) private var importLog
    @Environment(\.undoManager) private var undoManager
    private var library: RideLibrary { sharedLibrary.using(undoManager) }

    @Query(filter: PlannedRoute.listedPredicate, sort: \PlannedRoute.createdAt, order: .reverse)
    private var routes: [PlannedRoute]

    /// The manual import with its question “Ride or planned tour?” (B-372), as in the ride list.
    @State private var flow = ImportFlow()
    @State private var showingImporter = false
    @State private var isDropTargeted = false
    /// The tours before an import: a new one is selected once it is there.
    @State private var routesBeforeImport: Set<UUID>?
    @State private var renaming: PlannedRoute?
    @State private var newName = ""
    /// The small line in each row, worked out once per tour and not in `body` (rule 16).
    @State private var shapes: [UUID: [CGPoint]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            if routes.isEmpty {
                empty
            } else {
                table
            }
            dropZone
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
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [GPXExport.contentType],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .importFlow(flow)
        .alert("Rename Tour", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let route = renaming { library.rename(route, to: newName) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .onChange(of: routes.map(\.id), initial: true) { _, ids in
            selectImported(ids)
            if let id = selection, !ids.contains(id) { selection = nil }
            if selection == nil { selection = ids.first }
        }
        .task(id: routes.map(\.id)) { loadShapes() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Planned Tours").font(.title2.bold())
                Text("\(routes.count) tours")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Import GPX…") { showingImporter = true }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var table: some View {
        Table(routes, selection: $selection) {
            TableColumn("Name") { route in
                HStack(spacing: 8) {
                    TourShape(points: shapes[route.id] ?? [])
                        .stroke(selection == route.id ? Color.white : PlannedTourColor.line(scheme),
                                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(verbatim: route.name).lineLimit(1)
                }
                .help(Text(verbatim: route.name))
            }
            .width(min: 100, ideal: 140)
            TableColumn("Distance") { route in
                Text(verbatim: ValueFormat.distance(route.distance)).monospacedDigit()
            }
            .width(56)
            TableColumn("Ascent") { route in
                Text(verbatim: route.ascent.map { "\($0.formatted()) m" } ?? "–").monospacedDigit()
            }
            .width(52)
            TableColumn("Source") { route in
                Text(verbatim: PlannedTourText.source(route.source))
            }
            .width(52)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first, ids.count == 1, let route = routes.first(where: { $0.id == id }) {
                Button("Rename…") { startRenaming(route) }
                if let file = PlannedTourFile(route: route) {
                    ShareLink(item: file, preview: SharePreview(file.fileName)) {
                        Label("Share GPX", systemImage: "square.and.arrow.up")
                    }
                }
                Divider()
                Button("Move to Trash", role: .destructive) { moveToTrash(route) }
            }
        }
        .onDeleteCommand {
            if let id = selection, let route = routes.first(where: { $0.id == id }) { moveToTrash(route) }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No Planned Tours", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
        } description: {
            Text("Plan a tour in komoot, export it as GPX and drag the file here.")
        } actions: {
            Button("Import GPX…") { showingImporter = true }
        }
        .frame(maxHeight: .infinity)
    }

    @Environment(\.colorScheme) private var scheme

    /// The dashed field of the design: shows where a file can go.
    private var dropZone: some View {
        Text("Drag GPX files from komoot here")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
            .padding(12)
    }

    // MARK: - Actions

    private func importFiles(_ urls: [URL]) {
        routesBeforeImport = Set(routes.map(\.id))
        flow.start(urls, library: library, record: importLog.record)
    }

    /// After an import the new tour is selected, as a new ride is in the ride list.
    private func selectImported(_ ids: [UUID]) {
        guard let before = routesBeforeImport, let new = ids.first(where: { !before.contains($0) }) else { return }
        routesBeforeImport = nil
        selection = new
    }

    private func startRenaming(_ route: PlannedRoute) {
        newName = route.name
        renaming = route
    }

    /// One tour goes to the trash right away; ⌘Z brings it back.
    private func moveToTrash(_ route: PlannedRoute) {
        if selection == route.id { selection = nil }
        library.moveToTrash([route])
    }

    private func loadShapes() {
        var result: [UUID: [CGPoint]] = [:]
        for route in routes {
            result[route.id] = shapes[route.id] ?? TourShape.outline(route.points)
        }
        shapes = result
    }
}

// MARK: - Shared pieces of the list and the detail

/// The words for a tour's source.
enum PlannedTourText {
    static func source(_ source: PlannedTour.Source) -> String {
        switch source {
        case .komoot: "komoot"
        case .gpx: "GPX"
        }
    }

    /// “komoot · 34.0 km · ↑ 630 m · ↓ 630 m”
    static func figures(of route: PlannedRoute) -> String {
        var parts = [source(route.source), ValueFormat.distance(route.distance)]
        if let ascent = route.ascent { parts.append("↑ \(ascent.formatted()) m") }
        if let descent = route.descent { parts.append("↓ \(descent.formatted()) m") }
        return parts.joined(separator: " · ")
    }
}

/// The line of a tour in a small square, for the rows (design: the route beside the name).
struct TourShape: Shape {
    /// Points from 0 to 1, from `outline(_:)`.
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        func spot(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height) }
        path.move(to: spot(first))
        for point in points.dropFirst() { path.addLine(to: spot(point)) }
        return path
    }

    /// At most 60 points of the line, fitted into 0…1 with the same scale both ways, north up.
    static func outline(_ points: [PlannedTour.Point]) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        let step = max(1, points.count / 60)
        var sample = stride(from: 0, to: points.count, by: step).map { points[$0] }
        if let last = points.last, sample.last != last { sample.append(last) }
        // Longitude shrinks towards the poles; the middle latitude is close enough for a symbol.
        let middle = (sample.map(\.latitude).min()! + sample.map(\.latitude).max()!) / 2
        let scaleX = cos(middle * .pi / 180)
        let xs = sample.map { $0.longitude * scaleX }
        let ys = sample.map { -$0.latitude }
        let minX = xs.min()!, minY = ys.min()!
        let size = max(xs.max()! - minX, ys.max()! - minY, .ulpOfOne)
        let padX = (size - (xs.max()! - minX)) / 2, padY = (size - (ys.max()! - minY)) / 2
        return zip(xs, ys).map { CGPoint(x: ($0 - minX + padX) / size, y: ($1 - minY + padY) / size) }
    }
}

/// The original GPX file of a tour, for “Share GPX” (B-385).
struct PlannedTourFile: Transferable {
    let data: Data
    let fileName: String

    init?(route: PlannedRoute) {
        guard let data = route.sourceData, !data.isEmpty else { return nil }
        self.data = data
        let name = route.sourceFileName.isEmpty ? GPXWriter.fileName(route.name) : route.sourceFileName
        fileName = name.lowercased().hasSuffix(".gpx") ? name : name + ".gpx"
    }

    nonisolated static let gpx = UTType(filenameExtension: "gpx") ?? .xml

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: gpx) { $0.data }
            .suggestedFileName { $0.fileName }
    }
}
