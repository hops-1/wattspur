import SwiftUI
import WattspurKit

/// "This ride already exists": the new file and the ride in the library side by side, for a Bosch FIT
/// over a GPX ride and for a second GPX file (IMP-02, IMP-04; mockup "Duplikate FIT/GPX").
struct DuplicateSheet: View {
    let comparison: ImportFlow.Comparison
    let onSkip: () -> Void
    let onNew: () -> Void
    let onUpdate: () -> Void

    private var existing: DuplicateFacts { comparison.existing }
    private var incoming: DuplicateFacts? { comparison.incoming }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("This ride already exists").font(.title3.bold())
                    Text(verbatim: intro).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                GridRow {
                    Color.clear.frame(width: 90, height: 1)
                    Text(verbatim: existingTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(verbatim: incomingTitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                Divider().gridCellColumns(3)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        Text(row.label).font(.caption).foregroundStyle(.secondary)
                        Text(verbatim: row.existing).foregroundStyle(row.existing == "–" ? .secondary : .primary)
                        Text(verbatim: row.incoming).fontWeight(.semibold)
                    }
                    .monospacedDigit()
                    .padding(.vertical, 6)
                    Divider().gridCellColumns(3)
                }
            }
            .padding(.horizontal, 12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(keepNote).font(.callout)
                Text("In the watched folder, a Bosch file for a GPX ride updates it automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Spacer()
                Button("Skip", action: onSkip).keyboardShortcut(.cancelAction)
                Button("As new ride", action: onNew)
                Button("Update", action: onUpdate).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
        .interactiveDismissDisabled()
    }

    // MARK: - Words

    private var intro: String {
        let name = comparison.entry.result.fileName
        guard let incoming else { return String(localized: "“\(name)” matches “\(comparison.rideName)”.") }
        let seconds = Int(abs(incoming.startDate.timeIntervalSince(existing.startDate)).rounded())
        let longer = max(incoming.distance, existing.distance)
        let share = longer > 0 ? abs(incoming.distance - existing.distance) / longer : 0
        let percent = share.formatted(.percent.precision(.fractionLength(1)))
        return String(localized: "“\(name)” matches “\(comparison.rideName)”: start \(seconds) s apart, distance \(percent) different, same route.")
    }

    private var existingTitle: String {
        switch comparison.kind {
        case .fitForGPX: String(localized: "In Wattspur · GPX, estimated")
        case .gpxForGPX: String(localized: "In Wattspur · GPX")
        case .gpxForFIT: String(localized: "In Wattspur · Bosch FIT with GPX")
        }
    }

    private var incomingTitle: String {
        switch comparison.kind {
        case .fitForGPX: String(localized: "New file · Bosch FIT")
        case .gpxForGPX, .gpxForFIT: String(localized: "New file · GPX")
        }
    }

    private var keepNote: String {
        switch comparison.kind {
        case .fitForGPX: String(localized: "Update takes the Bosch values. Name, notes, bike and flags are kept.")
        case .gpxForGPX: String(localized: "Update replaces the values with the new file. Name, notes, bike and flags are kept.")
        case .gpxForFIT: String(localized: "Update replaces the attached GPX. The Bosch values stay.")
        }
    }

    private struct Row {
        let label: LocalizedStringKey
        let existing: String
        let incoming: String
    }

    private var rows: [Row] {
        guard let incoming else { return [] }
        func time(_ date: Date) -> String { date.formatted(date: .abbreviated, time: .standard) }
        func ascent(_ value: Int?) -> String { value.map { "\($0) m" } ?? "–" }
        func power(_ value: Int?) -> String { value.map { "\($0) W" } ?? "–" }
        var rows = [
            Row(label: "Start", existing: time(existing.startDate), incoming: time(incoming.startDate)),
            Row(label: "Distance", existing: RideFormat.distance(existing.distance), incoming: RideFormat.distance(incoming.distance)),
            Row(label: "Ride time", existing: RideFormat.duration(existing.rideTime), incoming: RideFormat.duration(incoming.rideTime)),
            Row(label: "Ascent", existing: ascent(existing.ascent), incoming: ascent(incoming.ascent)),
            Row(label: "Avg power", existing: power(existing.averagePower), incoming: power(incoming.averagePower)),
        ]
        if comparison.kind == .gpxForGPX {
            rows.append(Row(label: "Points", existing: existing.pointCount.formatted(), incoming: incoming.pointCount.formatted()))
        }
        return rows
    }
}
