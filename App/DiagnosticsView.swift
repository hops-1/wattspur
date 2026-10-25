import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WattspurKit

/// "Create Diagnostics…" (SUP-01): shows the report, saves it as a file
/// (optionally with the files that failed to import). Nothing is sent.
struct DiagnosticsView: View {
    @Environment(ImportLog.self) private var importLog
    @Query private var rides: [Ride]
    @Query(sort: \ImportRecord.date, order: .reverse) private var records: [ImportRecord]
    @State private var includeFailedFiles = true
    @State private var exporting = false
    @State private var copied = false

    private var report: DiagnosticReport {
        var byParser: [Int: Int] = [:]
        var gpxByParser: [Int: Int] = [:]
        for ride in rides {
            if ride.source == .gpx { gpxByParser[ride.parserVersion, default: 0] += 1 }
            else { byParser[ride.parserVersion, default: 0] += 1 }
        }
        return DiagnosticReport(
            appVersion: AppInfo.version, build: AppInfo.build, commit: AppInfo.commit,
            rideCount: rides.filter { !$0.isInTrash }.count,
            trashedRideCount: rides.filter(\.isInTrash).count,
            ridesByParserVersion: byParser,
            gpxRidesByParserVersion: gpxByParser,
            importLog: records.prefix(200).reversed().map(\.logEntry)
        )
    }

    private var attachFiles: Bool { includeFailedFiles && !importLog.failedFiles.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Diagnostics").font(.title2.bold())
            Text("This report helps to find import problems. It contains versions, counts and the import log – no positions, ride names or other ride data. Nothing is sent automatically: save it and send it yourself if you like.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(verbatim: report.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 220)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            if !importLog.failedFiles.isEmpty {
                Toggle(isOn: $includeFailedFiles) {
                    Text("Include the files that could not be imported (\(importLog.failedFiles.count))")
                }
                Text("These files may contain your routes (GPS positions).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(copied ? "Copied" : "Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report.text, forType: .string)
                    copied = true
                }
                Spacer()
                Button("Save…") { exporting = true }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
        .fileExporter(
            isPresented: $exporting,
            document: DiagnosticsDocument(text: report.text, files: attachFiles ? importLog.failedFiles : [:]),
            contentType: attachFiles ? .folder : .plainText,
            defaultFilename: "Wattspur-Diagnostics-\(Date.now.formatted(.iso8601.year().month().day()))"
        ) { _ in }
    }
}

/// The saved report: a text file, or a folder with the report and the failed files.
struct DiagnosticsDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText, .folder]

    var text: String
    var files: [String: Data]

    init(text: String, files: [String: Data]) {
        self.text = text
        self.files = files
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let report = FileWrapper(regularFileWithContents: Data(text.utf8))
        guard configuration.contentType == .folder else { return report }
        report.preferredFilename = "report.txt"
        var children = ["report.txt": report]
        for (name, data) in files {
            let file = FileWrapper(regularFileWithContents: data)
            file.preferredFilename = name
            children[name] = file
        }
        return FileWrapper(directoryWithFileWrappers: children)
    }
}
