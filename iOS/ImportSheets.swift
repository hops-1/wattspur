import SwiftUI
import WattspurCore
import WattspurKit

extension View {
    /// The questions and messages of the import (B-071, B-300): the iPhone's own sheets for the
    /// decisions of the shared import (`ImportFlow`, B-188), the file picker, the progress of many
    /// files and the summary at the end.
    func phoneImport(_ phoneImport: PhoneImport) -> some View {
        modifier(ImportSheets(phoneImport: phoneImport))
    }
}

private struct ImportSheets: ViewModifier {
    @Bindable var phoneImport: PhoneImport
    @Environment(PhoneLibrary.self) private var library

    private var flow: ImportFlow { phoneImport.flow }
    private var store: RideLibrary? { library.database?.library }

    func body(content: Content) -> some View {
        @Bindable var flow = flow
        content
            .sheet(item: $flow.bikeQuestion) { question in
                BikeQuestionSheet(question: question, bikes: store?.bikes(includingArchived: false) ?? []) { bike in
                    if let store { flow.confirm(question, bike: bike, library: store) { _, _ in } }
                    phoneImport.decided(library: library)
                }
            }
            .confirmationDialog(comparisonTitle, isPresented: Binding(get: { flow.comparisons.first != nil },
                                                                      set: { _ in }),
                                titleVisibility: .visible, presenting: flow.comparisons.first) { comparison in
                Button(updateLabel(comparison.kind)) {
                    if let store { flow.update(comparison, library: store) }
                    phoneImport.decided(library: library)
                }
                Button("Keep Both") {
                    if let store { flow.importAsNew(comparison, library: store) { _, _ in } }
                    phoneImport.decided(library: library)
                }
                Button("Skip", role: .cancel) {
                    flow.skip()
                    phoneImport.decided(library: library)
                }
            } message: { comparison in
                Text(Self.message(comparison))
            }
            .confirmationDialog("This ride is already in your library",
                                isPresented: Binding(get: { flow.plainDuplicates != nil },
                                                     set: { if !$0 { flow.plainDuplicates = nil } }),
                                titleVisibility: .visible, presenting: flow.plainDuplicates) { report in
                Button("Update from the New File") {
                    if let store { flow.updatePlainDuplicates(report, library: store) }
                    phoneImport.decided(library: library)
                }
                Button("Skip", role: .cancel) {
                    flow.plainDuplicates = nil
                    phoneImport.decided(library: library)
                }
            } message: { report in
                Text(report.duplicateQuestion)
            }
            // One summary once every file is read and every question answered (B-300); it takes
            // the place of the flow's own report and notice.
            .alert("Import Finished", isPresented: Binding(get: { phoneImport.summary != nil && !flow.isBusy },
                                                           set: { if !$0 { phoneImport.summary = nil } }),
                   presenting: phoneImport.summary) { _ in
                Button("OK") {}
            } message: { summary in
                Text(summary.message)
            }
            .onChange(of: flow.isBusy) { _, busy in
                if !busy { phoneImport.finishIfDone(library: library) }
            }
            .fileImporter(isPresented: $phoneImport.choosingFiles, allowedContentTypes: PhoneImport.contentTypes,
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): phoneImport.importFiles(urls, library: library)
                case .failure(let error):
                    phoneImport.notice = .init(title: String(localized: "Import Failed"), message: error.localizedDescription)
                }
            }
            .overlay(alignment: .top) {
                if let progress = flow.progress, progress.total > 1 {
                    ImportProgressBadge(progress: progress)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.default, value: flow.progress == nil)
            .alert(phoneImport.notice?.title ?? "", isPresented: Binding(get: { phoneImport.notice != nil },
                                                                         set: { if !$0 { phoneImport.notice = nil } }),
                   presenting: phoneImport.notice) { _ in
                Button("OK") {}
            } message: { notice in
                Text(notice.message)
            }
    }

    private var comparisonTitle: LocalizedStringKey {
        switch flow.comparisons.first?.kind {
        case .fitForGPX?: "The Bosch file of a recorded ride"
        case .gpxForGPX?, .gpxForFIT?, nil: "This ride is already in your library"
        }
    }

    private func updateLabel(_ kind: ImportFlow.Comparison.Kind) -> LocalizedStringKey {
        switch kind {
        case .fitForGPX: "Use the Bosch Values"
        case .gpxForGPX, .gpxForFIT: "Update from the New File"
        }
    }

    /// The ride in the library against the new file: start, distance and ride time.
    private static func message(_ comparison: ImportFlow.Comparison) -> String {
        let existing = facts(comparison.existing)
        let incoming = comparison.incoming.map(facts) ?? "–"
        return String(localized: "In the library: \(comparison.rideName), \(existing)\nNew file: \(incoming)")
    }

    private static func facts(_ facts: DuplicateFacts) -> String {
        "\(facts.startDate.formatted(date: .abbreviated, time: .shortened)) · \(RideFormat.distance(facts.distance)) · \(RideFormat.duration(facts.rideTime))"
    }
}

/// Which bike a GPX file belongs to, once there are two or more (B-144).
private struct BikeQuestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var question: ImportFlow.BikeQuestion
    var bikes: [Bike]
    var choose: (Bike) -> Void

    var body: some View {
        NavigationStack {
            List(bikes) { bike in
                Button(bike.name) {
                    dismiss()
                    choose(bike)
                }
            }
            .navigationTitle("Which Bike?")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Text("GPX files do not say which bike they belong to: \(question.gpxURLs.map(\.lastPathComponent).formatted(.list(type: .and)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .presentationDetents([.medium])
    }
}

/// “Importing 3 of 12 …” at the top while many files are read (B-300).
private struct ImportProgressBadge: View {
    let progress: ImportFlow.Progress

    var body: some View {
        HStack(spacing: 10) {
            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                .frame(width: 80)
            Text("Importing \(progress.done) of \(progress.total) …")
                .font(.subheadline)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}
