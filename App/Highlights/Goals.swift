import Charts
import SwiftData
import SwiftUI
import WattspurKit

struct GoalsContent: View {
    let goals: [Goal]
    let rides: [HighlightRide]
    let calendar: Calendar
    var isPrinting = false
    /// `nil` when every combination already has a goal.
    var onAdd: (() -> Void)?
    var onEdit: (Goal) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goals").font(.largeTitle.bold())
                    Text("For a week, month or year · kilometres, rides or ascent").foregroundStyle(.secondary)
                }
                Spacer()
                if !isPrinting {
                    Button("Add Goal…", systemImage: "plus") { onAdd?() }
                        .buttonStyle(.glass)
                        .disabled(onAdd == nil)
                        .help(onAdd == nil ? Text("Every period already has a goal for each metric.") : Text("Add Goal…"))
                }
            }
            if goals.isEmpty {
                ContentUnavailableView {
                    Label("No Goals Yet", systemImage: "target")
                } description: {
                    Text("Set a goal for kilometres, rides or ascent per week, month or year.")
                } actions: {
                    if !isPrinting { Button("Add Goal…") { onAdd?() } }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .top), count: 3),
                          alignment: .leading, spacing: 20) {
                    ForEach(goals) { goal in
                        GoalCard(progress: GoalProgress(metric: goal.metric, period: goal.period, target: goal.target,
                                                        rides: rides, calendar: calendar),
                                 calendar: calendar, isPrinting: isPrinting) { onEdit(goal) }
                    }
                }
            }
            Text("Goals are optional and stay in your library. The small bars show the last periods; a full bar means reached. The sample ride does not count.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

private struct GoalCard: View {
    let progress: GoalProgress
    let calendar: Calendar
    var isPrinting = false
    let onEdit: () -> Void

    private var metric: GoalMetric { progress.metric }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: HighlightsFormat.currentPeriod(progress.period, progress.current.interval, calendar: calendar))
                    .fontWeight(.semibold)
                Text(verbatim: HighlightsFormat.title(metric)).foregroundStyle(.secondary)
                Spacer()
                if !isPrinting {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(.borderless)
                        .help(Text("Edit Goal…"))
                        .accessibilityLabel(Text("Edit Goal…"))
                }
            }
            .font(.callout)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: HighlightsFormat.number(metric, progress.current.value))
                    .font(.system(size: 30, weight: .semibold))
                Text(verbatim: ofTarget).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            ProgressView(value: min(1, progress.current.fraction))
                .tint(Color.accentColor)
                .accessibilityLabel(Text(verbatim: "\(HighlightsFormat.title(progress.period)), \(HighlightsFormat.title(metric))"))
                .accessibilityValue(Text(verbatim: "\(HighlightsFormat.number(metric, progress.current.value)) \(ofTarget)"))
            HStack(spacing: 6) {
                if progress.current.isReached {
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
                Text(verbatim: note).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            // Rides without elevation add nothing to an ascent goal (B-146).
            if metric == .ascent { CoverageNote(coverage: progress.ascentCoverage) }
            history
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ofTarget: String {
        let unit = HighlightsFormat.unit(metric)
        let target = HighlightsFormat.number(metric, progress.current.target)
        return String(localized: "of \(unit.isEmpty ? target : "\(target) \(unit)")")
    }

    private var note: String {
        if let reached = progress.reachedAt {
            return String(localized: "Reached on \(HighlightsFormat.shortDate(reached, timeZone: calendar.timeZone))")
        }
        let remaining = "\(HighlightsFormat.number(metric, progress.remaining)) \(HighlightsFormat.unit(metric))"
            .trimmingCharacters(in: .whitespaces)
        let left = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: progress.current.interval.end).day ?? 0
        let track = progress.isOnTrack ? String(localized: "on track") : String(localized: "behind")
        return String(localized: "\(remaining) to go · \(left) days left · \(track)")
    }

    private var history: some View {
        let results = progress.history
        let reached = results.filter(\.isReached).count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(results) { result in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(result.isReached ? Color.accentColor : Color.accentColor.opacity(0.4))
                        .frame(height: max(3, min(1, result.fraction) * 28))
                        .frame(maxWidth: .infinity)
                        .help(Text(verbatim: result.fraction.formatted(.percent.precision(.fractionLength(0)))))
                }
            }
            .frame(height: 28, alignment: .bottom)
            .padding(.top, 6)
            .overlay(alignment: .top) { Divider() }
            Text("Last \(results.count) periods · \(reached) reached")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Last \(results.count) periods · \(reached) reached"))
    }
}

/// Add or change a goal. Each period and metric exists at most once (Requirements 10.10).
struct GoalEditor: View {
    enum Target: Identifiable {
        case new
        case edit(Goal)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let goal): goal.id.uuidString
            }
        }
    }

    let target: Target
    let goals: [Goal]
    @Environment(RideLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var period: GoalPeriod = .week
    @State private var metric: GoalMetric = .distance
    @State private var value: Double = 100

    private var editing: Goal? {
        if case .edit(let goal) = target { goal } else { nil }
    }

    /// Combinations still free, plus the one being edited.
    private func isFree(_ period: GoalPeriod, _ metric: GoalMetric) -> Bool {
        if let editing, editing.period == period, editing.metric == metric { return true }
        return Goal.freeCombinations(besides: goals).contains { $0.period == period && $0.metric == metric }
    }

    var body: some View {
        Form {
            Picker("Period", selection: $period) {
                ForEach(GoalPeriod.allCases) { Text(verbatim: HighlightsFormat.title($0)).tag($0) }
            }
            Picker("Metric", selection: $metric) {
                ForEach(GoalMetric.allCases) { m in
                    Text(verbatim: HighlightsFormat.title(m)).tag(m).selectionDisabled(!isFree(period, m))
                }
            }
            LabeledContent("Goal") {
                HStack {
                    TextField("Goal", value: $value, format: .number.precision(.fractionLength(0...1)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text(verbatim: HighlightsFormat.unit(metric).isEmpty ? HighlightsFormat.title(metric) : HighlightsFormat.unit(metric))
                        .foregroundStyle(.secondary)
                }
            }
            if !isFree(period, metric) {
                Text("There is already a goal for this period and metric.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .navigationTitle(editing == nil ? Text("Add Goal") : Text("Edit Goal"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(value <= 0 || !isFree(period, metric))
            }
            if let editing {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Goal", role: .destructive) {
                        library.delete(editing)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let editing {
                period = editing.period
                metric = editing.metric
                value = HighlightsFormat.display(editing.metric, editing.target)
            } else if let free = Goal.freeCombinations(besides: goals).first {
                period = free.period
                metric = free.metric
                value = Self.suggestion(free.period, free.metric)
            }
        }
        .onChange(of: metric) { if editing == nil { value = Self.suggestion(period, metric) } }
        .onChange(of: period) {
            if !isFree(period, metric), let free = GoalMetric.allCases.first(where: { isFree(period, $0) }) { metric = free }
            if editing == nil { value = Self.suggestion(period, metric) }
        }
    }

    /// A starting value in km, rides or m, so the field is never empty.
    private static func suggestion(_ period: GoalPeriod, _ metric: GoalMetric) -> Double {
        switch (period, metric) {
        case (.week, .distance): 100
        case (.week, .rides): 3
        case (.week, .ascent): 1_000
        case (.month, .distance): 400
        case (.month, .rides): 12
        case (.month, .ascent): 4_000
        case (.year, .distance): 4_000
        case (.year, .rides): 120
        case (.year, .ascent): 40_000
        }
    }

    private func save() {
        let target = metric == .distance ? value * 1000 : value.rounded()
        if let editing {
            library.update(editing, metric: metric, period: period, target: target)
        } else {
            library.addGoal(metric: metric, period: period, target: target)
        }
        dismiss()
    }
}
