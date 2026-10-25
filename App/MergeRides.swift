import SwiftData
import SwiftUI
import WattspurKit

/// Confirms merging the selected rides: timeline, name and the resulting totals (B-095, LIST-09).
struct MergeRidesSheet: View {
    let rideIDs: Set<UUID>
    /// The main window's undo manager; the sheet is a window of its own with its own.
    let undoManager: UndoManager?
    /// Called with the new ride, so the list can select it.
    let onMerged: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var rides: [Ride]
    @State private var name = ""

    init(rideIDs: Set<UUID>, undoManager: UndoManager?, onMerged: @escaping (UUID) -> Void) {
        self.rideIDs = rideIDs
        self.undoManager = undoManager
        self.onMerged = onMerged
        let ids = Array(rideIDs)
        _rides = Query(filter: #Predicate<Ride> { ids.contains($0.id) })
    }

    private var library: RideLibrary { RideLibrary(context: modelContext, undoManager: undoManager) }
    private var parts: [Ride] { library.mergeParts(of: rides) }

    var body: some View {
        let preview = Swift.Result { () throws(RideMerge.MergeError) in try library.mergePreview(rides) }
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Merge \(rides.count) Rides").font(.headline)
                Text("The rides become one. The originals are kept inside it, so you can split them again at any time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch preview {
            case .success(let result):
                MergeTimeline(parts: parts)
                TextField("Name", text: $name)
                MergePreviewGrid(result: result)
                Text("Time, distance, ascent and work are added up, maximums carried over. Average power and cadence are weighted by moving time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .failure(let problem):
                Label(problem.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge") { merge() }
                    .keyboardShortcut(.defaultAction)
                    .disabled((try? preview.get()) == nil)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { if name.isEmpty { name = parts.first?.name ?? "" } }
    }

    private func merge() {
        guard let ride = try? library.merge(rides, name: name) else { return }
        dismiss()
        onMerged(ride.id)
    }
}

extension RideMerge.MergeError {
    var message: LocalizedStringKey {
        switch self {
        case .tooFewRides: "Select at least two rides to merge."
        case .overlapping: "These rides overlap in time and cannot be merged."
        case .containsSample: "The sample ride cannot be merged."
        }
    }
}

/// The parts on a time bar; a pause on the same day is drawn to scale,
/// a gap across days as a short break.
private struct MergeTimeline: View {
    let parts: [Ride]

    private enum Segment: Identifiable {
        case ride(Ride)
        case pause(id: Int, seconds: TimeInterval)
        case nextDay(id: Int)

        var id: String {
            switch self {
            case .ride(let ride): ride.id.uuidString
            case .pause(let id, _), .nextDay(let id): "gap-\(id)"
            }
        }
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var calendar = Calendar.current
        calendar.timeZone = parts.first?.timeZone ?? .current
        for (index, part) in parts.enumerated() {
            if index > 0 {
                let previous = parts[index - 1]
                if calendar.isDate(previous.startDate, inSameDayAs: part.startDate) {
                    let end = previous.startDate.addingTimeInterval(previous.elapsedTime)
                    result.append(.pause(id: index, seconds: max(0, part.startDate.timeIntervalSince(end))))
                } else {
                    result.append(.nextDay(id: index))
                }
            }
            result.append(.ride(part))
        }
        return result
    }

    var body: some View {
        let segments = segments
        let dayBreak = 24.0
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                let breaks = Double(segments.count { if case .nextDay = $0 { true } else { false } })
                let total = segments.reduce(0) { $0 + seconds($1) }
                let scale = total > 0 ? max(0, proxy.size.width - breaks * dayBreak) / total : 0
                HStack(spacing: 2) {
                    ForEach(segments) { segment in
                        switch segment {
                        case .ride(let ride):
                            Text(ride.name)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .frame(width: max(2, seconds(segment) * scale), height: 24, alignment: .leading)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.white)
                        case .pause(_, let gap):
                            Text("\(Int((gap / 60).rounded())) min pause")
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(width: max(2, seconds(segment) * scale), height: 24)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.secondary)
                        case .nextDay:
                            Image(systemName: "ellipsis")
                                .font(.caption2)
                                .frame(width: dayBreak - 4, height: 24)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .clipped()
            }
            .frame(height: 24)
            HStack {
                if let first = parts.first { Text(verbatim: time(first.startDate, of: first)) }
                Spacer()
                if let last = parts.last { Text(verbatim: time(last.startDate.addingTimeInterval(last.elapsedTime), of: last)) }
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private func seconds(_ segment: Segment) -> Double {
        switch segment {
        case .ride(let ride): ride.elapsedTime
        case .pause(_, let gap): gap
        case .nextDay: 0
        }
    }

    private func time(_ date: Date, of ride: Ride) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: ride.timeZone))
    }

    private var accessibilityText: String {
        parts.map { "\($0.name), \(RideFormat.longDate($0.startDate, timeZone: $0.timeZone))" }
            .formatted(.list(type: .and))
    }
}

/// The totals the merged ride will have.
private struct MergePreviewGrid: View {
    let result: RideMerge.Result

    var body: some View {
        let s = result.summary
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                row("Ride time", RideFormat.duration(s.timerTime))
                row("Total time", RideFormat.duration(s.elapsedTime))
            }
            GridRow {
                row("Distance", RideFormat.distance(s.distance))
                row("Avg speed", RideFormat.speed(s.averageSpeed))
            }
            GridRow {
                row("Ascent", s.totalAscent.map { "\($0) m" } ?? "–")
                row("Work", s.averagePower == nil ? "–" : "\(Int(result.workKilojoules.rounded())) kJ")
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(verbatim: value).monospacedDigit().fontWeight(.semibold)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The "2 parts" tag in the ride list.
struct MergedBadge: View {
    let count: Int

    var body: some View {
        Label("\(count) parts", systemImage: "arrow.triangle.merge")
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary, lineWidth: 1))
            .foregroundStyle(.secondary)
    }
}

/// Above the detail of a merged ride: where it came from, and a way back.
struct MergedRideBanner: View {
    let ride: Ride
    let onSplit: ([UUID]) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let parts = ride.sortedParts
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.merge")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Merged from \(parts.count) rides").font(.callout.weight(.semibold))
                Text(verbatim: parts.map { "\($0.name) \(RideFormat.relativeDate($0.startDate, timeZone: $0.timeZone))" }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button("Split") { onSplit(RideLibrary(context: modelContext, undoManager: undoManager).split(ride).map(\.id)) }
                .help(Text("Split into the original rides"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}
