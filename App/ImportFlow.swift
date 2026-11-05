import SwiftData
import SwiftUI
import WattspurKit

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
                    flow.confirm(question, bike: bike, library: library, record: importLog.record)
                }
            }
            // Only the buttons close it, so a decision is never skipped by accident; Esc is "Skip".
            .sheet(item: Binding(get: { flow.comparisons.first }, set: { _ in })) { comparison in
                DuplicateSheet(comparison: comparison, onSkip: { flow.skip() },
                               onNew: { flow.importAsNew(comparison, library: library, record: importLog.record) },
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
