import SwiftData
import SwiftUI
import WattspurKit

/// The manual import from the drop to the last question (IMP-04, B-144): which bike a GPX file
/// belongs to, what to do with a ride that is already there, and the notice that a GPX was
/// attached. Used by the ride list and the import window; the watched folder asks nobody.
@MainActor
@Observable
final class ImportFlow {
    /// GPX files carry no bike, so they are asked for it from two bikes on.
    struct BikeQuestion: Identifiable {
        let id = UUID()
        let urls: [URL]
        var gpxURLs: [URL] { urls.filter(ImportFlow.isGPX) }
    }

    /// A file that looks like a ride in the library and needs a decision (mockup "Duplikate FIT/GPX").
    struct Comparison: Identifiable {
        enum Kind {
            /// A Bosch FIT for a ride that is there as GPX only.
            case fitForGPX
            /// Another GPX file of a ride that is already a GPX ride.
            case gpxForGPX
            /// A GPX for a Bosch ride that has one attached already.
            case gpxForFIT
        }

        let id = UUID()
        let entry: ImportReport.Entry
        let rideID: UUID
        let rideName: String
        let bikeID: UUID?
        let kind: Kind
        let existing: DuplicateFacts
        let incoming: DuplicateFacts?
    }

    /// The notice after GPX files were attached to rides (mockup "attached").
    struct Attached: Equatable {
        var rideIDs: [UUID]
        var rideName: String
        /// `true` if heart rate or temperature came with the file.
        var sensors: Bool
    }

    var bikeQuestion: BikeQuestion?
    var comparisons: [Comparison] = []
    /// The summary alert.
    var report: ImportReport?
    /// Duplicates of two FIT files: the old question for all of them at once (IMP-02).
    var plainDuplicates: ImportReport?
    var attached: Attached?
    /// Called with the rides a run added, e.g. to select the last one and look for merge suggestions.
    var onImported: ([UUID]) -> Void = { _ in }
    /// Called to show a ride; `nil` where the view cannot.
    var onSelect: ((UUID) -> Void)?

    private var bikeID: UUID?
    private var afterComparisons: (() -> Void)?
    private var failedUpdates: [String] = []

    nonisolated static func isGPX(_ url: URL) -> Bool { url.pathExtension.lowercased() == "gpx" }

    // MARK: - Start

    /// Imports the files, or asks for the bike first when GPX files are among them and there are
    /// two or more bikes.
    func start(_ urls: [URL], library: RideLibrary, importLog: ImportLog) {
        guard !urls.isEmpty else { return }
        if urls.contains(where: Self.isGPX), library.bikes(includingArchived: false).count >= 2 {
            bikeQuestion = BikeQuestion(urls: urls)
        } else {
            run(urls, gpxBike: nil, library: library, importLog: importLog)
        }
    }

    func confirm(_ question: BikeQuestion, bike: Bike, library: RideLibrary, importLog: ImportLog) {
        bikeQuestion = nil
        run(question.urls, gpxBike: bike, library: library, importLog: importLog)
    }

    private func run(_ urls: [URL], gpxBike: Bike?, library: RideLibrary, importLog: ImportLog) {
        bikeID = gpxBike?.id
        let entries = urls.map { url -> ImportReport.Entry in
            let result = Self.isGPX(url) ? library.importFile(at: url, bike: gpxBike) : library.importFile(at: url)
            importLog.record(result, url: url)
            library.record(result, source: .manual)
            return ImportReport.Entry(url: url, result: result)
        }
        finish(entries, library: library)
    }

    private func finish(_ entries: [ImportReport.Entry], library: RideLibrary) {
        let imported = entries.compactMap { entry -> UUID? in
            if case .imported(let id) = entry.result.outcome { id } else { nil }
        }
        if !imported.isEmpty { onImported(imported) }

        let attachedIDs = entries.compactMap { entry -> UUID? in
            if case .attached(let id) = entry.result.outcome { id } else { nil }
        }
        if let first = attachedIDs.first, let ride = library.ride(withID: first) {
            let sensors = attachedIDs.compactMap { library.ride(withID: $0) }
                .contains { $0.samples.contains { $0.heartRate != nil || $0.temperature != nil } }
            attached = Attached(rideIDs: attachedIDs, rideName: ride.name, sensors: sensors)
        }

        var comparisons: [Comparison] = []
        var report = ImportReport(entries: entries)
        for entry in entries {
            guard let id = entry.result.outcome.existingRideID, let ride = library.ride(withID: id),
                  let kind = Self.kind(of: entry, existing: ride) else { continue }
            comparisons.append(Comparison(entry: entry, rideID: id, rideName: ride.name, bikeID: bikeID ?? ride.bike?.id,
                                          kind: kind, existing: DuplicateFacts(ride: ride), incoming: library.facts(ofFileAt: entry.url)))
            report.excluded.insert(entry.result.id)
        }

        let conclude = { [self] in
            if !report.duplicates.isEmpty {
                plainDuplicates = report
            } else if report.hasNews {
                self.report = report
            }
        }
        if comparisons.isEmpty {
            conclude()
        } else {
            afterComparisons = conclude
            self.comparisons = comparisons
        }
    }

    /// Which question a duplicate asks; `nil` for two FIT files, which keep the old one.
    private static func kind(of entry: ImportReport.Entry, existing: Ride) -> Comparison.Kind? {
        switch (isGPX(entry.url), existing.source) {
        case (false, .gpx?): .fitForGPX
        case (true, .gpx?): .gpxForGPX
        case (true, .fit?): .gpxForFIT
        default: nil
        }
    }

    // MARK: - Decisions

    /// Leave the file out; the log keeps the line "duplicate".
    func skip() {
        advance()
    }

    /// Take the new file's values; name, notes, bike and flags stay (IMP-02).
    func update(_ comparison: Comparison, library: RideLibrary) {
        if let ride = library.ride(withID: comparison.rideID) {
            do {
                try library.update(ride, withFileAt: comparison.entry.url)
                library.recordUpdate(of: ride.id, fileName: comparison.entry.result.fileName, source: .manual)
            } catch {
                failedUpdates.append(comparison.entry.result.fileName)
            }
        }
        advance()
    }

    /// Keep both: the file becomes a ride of its own.
    func importAsNew(_ comparison: Comparison, library: RideLibrary, importLog: ImportLog) {
        let bike = comparison.bikeID.flatMap { id in library.bikes(includingArchived: false).first { $0.id == id } }
        let result = library.importFile(at: comparison.entry.url, bike: bike, detectDuplicates: false)
        importLog.record(result, url: comparison.entry.url)
        library.record(result, source: .manual)
        if case .imported(let id) = result.outcome { onImported([id]) }
        advance()
    }

    private func advance() {
        if !comparisons.isEmpty { comparisons.removeFirst() }
        guard comparisons.isEmpty else { return }
        let next = afterComparisons
        afterComparisons = nil
        next?()
        if !failedUpdates.isEmpty {
            report = ImportReport(entries: [], extraLines: ImportReport.unreadableLines(failedUpdates))
            failedUpdates = []
        }
    }

    /// The plain duplicates: update all of them from the new files.
    func updatePlainDuplicates(_ report: ImportReport, library: RideLibrary) {
        var failed: [String] = []
        for entry in report.duplicates {
            guard let id = entry.result.outcome.existingRideID, let ride = library.ride(withID: id) else { continue }
            do {
                try library.update(ride, withFileAt: entry.url)
                library.recordUpdate(of: id, fileName: entry.result.fileName, source: .manual)
            } catch {
                failed.append(entry.result.fileName)
            }
        }
        plainDuplicates = nil
        if !failed.isEmpty {
            self.report = ImportReport(entries: [], extraLines: ImportReport.unreadableLines(failed))
        }
    }
}

extension View {
    /// The sheets, alerts and the notice of the manual import.
    func importFlow(_ flow: ImportFlow) -> some View {
        modifier(ImportFlowModifier(flow: flow))
    }
}

private struct ImportFlowModifier: ViewModifier {
    @Bindable var flow: ImportFlow
    @Environment(\.undoManager) private var undoManager
    @Environment(ImportLog.self) private var importLog

    @Environment(RideLibrary.self) private var sharedLibrary
    private var library: RideLibrary { sharedLibrary.using(undoManager) }

    func body(content: Content) -> some View {
        content
            .sheet(item: $flow.bikeQuestion) { question in
                GPXBikeSheet(question: question) { bike in
                    flow.confirm(question, bike: bike, library: library, importLog: importLog)
                }
            }
            // Only the buttons close it, so a decision is never skipped by accident; Esc is "Skip".
            .sheet(item: Binding(get: { flow.comparisons.first }, set: { _ in })) { comparison in
                DuplicateSheet(comparison: comparison, onSkip: { flow.skip() },
                               onNew: { flow.importAsNew(comparison, library: library, importLog: importLog) },
                               onUpdate: { flow.update(comparison, library: library) })
            }
            .alert(item: $flow.report) { report in
                Alert(title: Text("Import finished"), message: Text(report.message))
            }
            .confirmationDialog(
                Text("Some rides are already in your library"),
                isPresented: Binding(get: { flow.plainDuplicates != nil }, set: { if !$0 { flow.plainDuplicates = nil } }),
                presenting: flow.plainDuplicates
            ) { report in
                Button("Update from New Files") { flow.updatePlainDuplicates(report, library: library) }
                Button("Skip", role: .cancel) { flow.plainDuplicates = nil }
            } message: { report in
                Text(report.duplicateQuestion)
            }
            .overlay(alignment: .bottom) {
                if let attached = flow.attached {
                    AttachedNotice(attached: attached, onShow: flow.onSelect.map { select in
                        { if let id = attached.rideIDs.first { select(id) }; flow.attached = nil }
                    }, onDismiss: { flow.attached = nil })
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: attached) {
                        try? await Task.sleep(for: .seconds(9))
                        flow.attached = nil
                    }
                }
            }
            .animation(.snappy, value: flow.attached)
    }
}

// MARK: - Notice

/// "GPX attached to …": the file was joined to a Bosch ride without asking (mockup, step "attached").
private struct AttachedNotice: View {
    let attached: ImportFlow.Attached
    let onShow: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.green, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if let onShow {
                Button("Show", action: onShow)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(Text("Hide"))
            .accessibilityLabel(Text("Hide"))
        }
        .padding(12)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        attached.rideIDs.count == 1
            ? String(localized: "GPX attached to “\(attached.rideName)”")
            : String(localized: "\(attached.rideIDs.count) GPX files attached to rides")
    }

    private var subtitle: String {
        attached.sensors
            ? String(localized: "Heart rate and temperature added · Bosch values unchanged")
            : String(localized: "Source noted · Bosch values unchanged")
    }
}
