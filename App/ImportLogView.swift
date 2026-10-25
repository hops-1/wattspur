import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// Import window (B-041, IMP-06): drop zone, the watched folder and the
/// persistent import log. Files of an unsupported type are grouped into one
/// row, so hundreds of other files never flood the list.
struct ImportLogView: View {
    @Environment(FolderWatcher.self) private var watcher
    @Environment(\.modelContext) private var modelContext
    @Environment(ImportLog.self) private var importLog
    @Environment(MergeSuggestionCenter.self) private var suggestions
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @Query(sort: \ImportRecord.date, order: .reverse) private var records: [ImportRecord]

    @State private var onlyAttention = false
    /// Which kind of file the log shows (B-144).
    @State private var sourceFilter: LogSource = .all
    @State private var flow = ImportFlow()
    @State private var showUnsupported = false
    @State private var showingImporter = false
    @State private var isDropTargeted = false

    private var unsupported: [ImportRecord] { records.filter { $0.outcome == .unsupported } }
    private var attentionCount: Int { records.filter { $0.outcome.needsAttention }.count }

    /// Log rows: every entry except unsupported files, which share one group row.
    private var rows: [LogRow] {
        var rows: [LogRow] = []
        var groupAdded = false
        for record in records {
            if onlyAttention && !record.outcome.needsAttention { continue }
            if !sourceFilter.includes(record.fileName) { continue }
            if record.outcome == .unsupported {
                if !groupAdded {
                    rows.append(.unsupportedGroup(latest: record.date))
                    groupAdded = true
                }
            } else {
                rows.append(.entry(record))
            }
        }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                dropZone
                folderCard
            }
            .padding([.horizontal, .top], 24)

            HStack(spacing: 12) {
                Text("Import log").font(.headline)
                Spacer()
                Picker("Source", selection: $sourceFilter) {
                    Text("All").tag(LogSource.all)
                    Text(verbatim: "FIT").tag(LogSource.fit)
                    Text(verbatim: "GPX").tag(LogSource.gpx)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(Text("Source"))
                Picker("Filter", selection: $onlyAttention) {
                    Text("All").tag(false)
                    Text("Needs attention (\(attentionCount))").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 8)

            List {
                ForEach(rows) { row in
                    switch row {
                    case .entry(let record):
                        LogEntryRow(record: record)
                    case .unsupportedGroup(let latest):
                        unsupportedGroupRow(latest: latest)
                    }
                }
            }
            .listStyle(.bordered)
            .alternatingRowBackgrounds()
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(onlyAttention ? "Nothing to Check" : "No Imports Yet",
                                           systemImage: "tray",
                                           description: Text(onlyAttention ? "All files were processed." : "Imported files will be listed here."))
                }
            }
            .padding(.horizontal, 24)

            HStack {
                Text(verbatim: summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .frame(height: 56)
        }
        .frame(minWidth: 760, minHeight: 600)
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [UTType(filenameExtension: "fit") ?? .data, UTType(filenameExtension: "gpx") ?? .xml],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .importFlow(flow)
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
            Text("Drop FIT or GPX files here").font(.headline)
            Button("Choose Files…") { showingImporter = true }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(Color.accentColor.opacity(isDropTargeted ? 0.16 : 0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
        .dropDestination(for: URL.self) { urls, _ in
            importFiles(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private var folderCard: some View {
        @Bindable var watcher = watcher
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "folder").foregroundStyle(Color.accentColor)
                Text("Watched folder").font(.headline)
                Spacer()
                Toggle(isOn: $watcher.isEnabled) { Text("Watched folder") }
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!watcher.hasFolder)
            }
            if let path = watcher.displayPath {
                Text(verbatim: path).lineLimit(1).truncationMode(.middle)
            } else {
                Button("Choose Folder…") { watcher.chooseFolder(createImportFolder: true) }
            }
            FolderStatusText()
            Text("Imported files move to “\(String(localized: "folder.imported", defaultValue: "Imported"))”, failed ones to “\(String(localized: "folder.failed", defaultValue: "Failed"))”.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func unsupportedGroupRow(latest: Date) -> some View {
        let types = Set(unsupported.map { ".\(($0.fileName as NSString).pathExtension.lowercased())" }).sorted()
            .formatted(.list(type: .and))
        DisclosureGroup(isExpanded: $showUnsupported) {
            ForEach(unsupported.prefix(50)) { record in
                Text(verbatim: record.fileName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if unsupported.count > 50 {
                Text("… and \(unsupported.count - 50) more").font(.callout).foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 10) {
                StatusBadge(outcome: .unsupported)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unsupported.count) files skipped (\(types))").lineLimit(1)
                    Text("File type not supported yet · left in place").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(latest, format: .relative(presentation: .named)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        let imported = records.filter { $0.outcome == .imported }.count
        return String(localized: "\(records.count) entries · \(imported) imported · \(unsupported.count) skipped · \(attentionCount) need attention")
    }

    private func importFiles(_ urls: [URL]) {
        let library = RideLibrary(context: modelContext, undoManager: undoManager)
        flow.onImported = { ids in suggestions.suggest(involving: ids, library: library) }
        flow.start(urls, library: library, importLog: importLog)
    }
}

/// The kind of file the import log is limited to.
private enum LogSource: Hashable {
    case all, fit, gpx

    func includes(_ fileName: String) -> Bool {
        let isGPX = (fileName as NSString).pathExtension.lowercased() == "gpx"
        switch self {
        case .all: return true
        case .fit: return !isGPX
        case .gpx: return isGPX
        }
    }
}

private enum LogRow: Identifiable {
    case entry(ImportRecord)
    case unsupportedGroup(latest: Date)

    var id: String {
        switch self {
        case .entry(let record): record.id.uuidString
        case .unsupportedGroup: "unsupported"
        }
    }
}

private struct LogEntryRow: View {
    let record: ImportRecord
    @Environment(FolderWatcher.self) private var watcher
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query private var rides: [Ride]
    /// Rides this one probably belongs with, while the entry is recent (B-096).
    @State private var suggestion: RideMergeSuggestion.Group?
    @State private var merging: MergeCandidates?

    /// Newer entries only: finding the neighbours costs a look into the library.
    private static let suggestionDays = 7.0

    init(record: ImportRecord) {
        self.record = record
        let id = record.rideID ?? UUID()
        _rides = Query(filter: #Predicate<Ride> { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusBadge(outcome: record.outcome)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: record.fileName).lineLimit(1).truncationMode(.middle)
                    if (record.fileName as NSString).pathExtension.lowercased() == "gpx" { SourcePill() }
                }
                Text(verbatim: message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if let suggestion {
                    Label(suggestion.message, systemImage: "arrow.triangle.merge")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let suggestion {
                Button("Merge") { merging = MergeCandidates(ids: Set(suggestion.rideIDs), suggestion: suggestion) }
            }
            if record.outcome == .failed, record.source == .folder, let path = record.movedTo, watcher.folderURL != nil {
                Button("Show in Finder") { watcher.showInFinder(relativePath: path) }
            } else {
                Text(RideFormat.relativeDate(record.date)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .task(id: "\(rides.first?.id.uuidString ?? "")\(rides.first?.mergedInto?.id.uuidString ?? "")\(rides.first?.deletedAt != nil)") {
            findSuggestion()
        }
        .sheet(item: $merging) { candidates in
            MergeRidesSheet(rideIDs: candidates.ids, undoManager: undoManager) { _ in suggestion = nil }
        }
    }

    private func findSuggestion() {
        guard record.outcome == .imported, let ride = rides.first, ride.mergedInto == nil, ride.deletedAt == nil,
              record.date > .now.addingTimeInterval(-Self.suggestionDays * 86_400) else {
            suggestion = nil
            return
        }
        suggestion = RideLibrary(context: modelContext)
            .mergeSuggestions(involving: [ride.id], maxGapMinutes: MergeSuggestionCenter.gapMinutes).first
    }

    private var sourceText: String {
        record.source == .folder ? String(localized: "from the watched folder") : String(localized: "added by hand")
    }

    private var message: String {
        switch record.outcome {
        case .attached:
            let name = rides.first?.name ?? RideLibrary.parseFileName(record.fileName).title
            return String(localized: "Attached to “\(name)” · Bosch values unchanged")
        case .imported, .updated:
            if let ride = rides.first {
                let action = record.outcome == .updated
                    ? (record.source == .folder ? String(localized: "updated automatically") : String(localized: "updated"))
                    : sourceText
                let line = "\(ride.name) · \(RideFormat.distance(ride.distance)) · \(action)"
                let records = record.recordKinds.map(HighlightsFormat.title)
                guard !records.isEmpty else { return line }
                return "\(line)\n★ " + String(localized: "New record: \(records.formatted(.list(type: .and)))")
            }
            return sourceText
        case .duplicate:
            return String(localized: "Already in your library – not imported again.")
        case .unsupported:
            return String(localized: "File type not supported yet")
        case .failed:
            let ext = (record.fileName as NSString).pathExtension.lowercased()
            if ext.hasPrefix("fit ") {
                return String(localized: "Extension “\(ext)” – probably a Finder copy. Rename it to “.fit” and add it again.")
            }
            return record.source == .folder
                ? String(localized: "The file could not be read. Moved to “\(String(localized: "folder.failed", defaultValue: "Failed"))”.")
                : String(localized: "The file could not be read.")
        }
    }
}

private struct StatusBadge: View {
    let outcome: ImportRecordOutcome

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18))
            .foregroundStyle(color)
            .frame(width: 22)
            .help(Text(label))
            .accessibilityLabel(Text(label))
    }

    private var symbol: String {
        switch outcome {
        case .imported: "checkmark.circle.fill"
        case .updated: "arrow.triangle.2.circlepath.circle.fill"
        case .attached: "paperclip.circle.fill"
        case .duplicate, .unsupported: "minus.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch outcome {
        case .imported, .updated, .attached: .green
        case .duplicate, .unsupported: .secondary
        case .failed: .red
        }
    }

    private var label: LocalizedStringKey {
        switch outcome {
        case .imported: "Imported"
        case .updated: "Updated"
        case .attached: "Attached"
        case .duplicate, .unsupported: "Skipped"
        case .failed: "Failed"
        }
    }
}
