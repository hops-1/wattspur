import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The widget extension of the iPhone app: the Live Activity of a recording (B-223) and the widget
/// “This Week” on the Home Screen (B-224).
@main
struct WattspurWidgets: WidgetBundle {
    var body: some Widget {
        WeekWidget()
        RecordingLiveActivity()
    }
}

/// Time, distance and speed while recording, on the Lock Screen and in the Dynamic Island.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                // Beside the camera only one short line fits on each side; the rest goes below.
                DynamicIslandExpandedRegion(.leading) {
                    Label { Text(verbatim: ActivityFormat.distance(context.state.distance)) } icon: {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                    .accessibilityLabel(Text("Distance"))
                    .accessibilityValue(Text(verbatim: ActivityFormat.distance(context.state.distance)))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label { Text(verbatim: ActivityFormat.speed(context.state.speed)) } icon: {
                        Image(systemName: "speedometer")
                    }
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                    .accessibilityLabel(Text("Speed"))
                    .accessibilityValue(Text(verbatim: ActivityFormat.speed(context.state.speed)))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        ElapsedTime(start: context.attributes.startDate)
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        PauseButton(isPaused: context.state.isPaused)
                            .frame(maxWidth: 160)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.symbol ?? "bicycle")
                    .foregroundStyle(Color.track)
            } compactTrailing: {
                // Little room beside the island: the number large, the unit small.
                let parts = ActivityFormat.distanceParts(context.state.distance)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(verbatim: parts.number)
                        .font(.caption.weight(.semibold))
                    Text(verbatim: parts.unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.symbol ?? "bicycle")
                    .foregroundStyle(Color.track)
            }
            .keylineTint(Color.track)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<RecordingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Wattspur", systemImage: context.attributes.symbol ?? "bicycle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.track)
                Spacer()
                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.orange, in: .capsule)
                        .foregroundStyle(.white)
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ElapsedTime(start: context.attributes.startDate)
                        .font(.title2.weight(.bold))
                }
                Spacer()
                Figure(title: "Distance", value: ActivityFormat.distance(context.state.distance))
                Spacer()
                Figure(title: "Speed", value: ActivityFormat.speed(context.state.speed))
            }
            if let kind = context.attributes.side {
                SideRow(kind: kind, lean: context.state.lean)
            }
            PauseButton(isPaused: context.state.isPaused)
        }
        .padding()
    }
}

/// A car's lateral acceleration as a bar from 0.5 g left to 0.5 g right, as in the app, or a
/// motorcycle's lean angle (B-289). A dash before the first value and while paused.
private struct SideRow: View {
    let kind: String
    let lean: Double?
    private static let reach = 0.5

    var body: some View {
        HStack(spacing: 10) {
            Text(kind == "lateral" ? "Lateral Acceleration" : "Lean Angle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            if kind == "lateral" {
                GeometryReader { proxy in
                    let half = proxy.size.width / 2
                    let value = lean.map(ActivitySide.lateral) ?? 0
                    let share = min(abs(value) / Self.reach, 1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(Color.indigo)
                            .frame(width: half * share)
                            .offset(x: value > 0 ? half - half * share : half)
                        Rectangle().fill(.secondary).frame(width: 1.5).offset(x: half - 0.75)
                    }
                }
                .frame(height: 8)
                .clipShape(.capsule)
            } else {
                Spacer(minLength: 0)
            }
            Text(verbatim: lean.map { ActivitySide.text(lean: $0, kind: kind) } ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Counts up from the start by itself, without updates from the app.
private struct ElapsedTime: View {
    let start: Date

    var body: some View {
        Text(timerInterval: start...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .lineLimit(1)
    }
}

private struct Figure: View {
    let title: LocalizedStringKey
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Pause and Resume run in the app (`ToggleRecordingPauseIntent`); Stop stays in the app, where
/// the ride is named and saved.
private struct PauseButton: View {
    let isPaused: Bool

    var body: some View {
        Button(intent: ToggleRecordingPauseIntent()) {
            Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .tint(isPaused ? .green : .orange)
        .buttonStyle(.borderedProminent)
    }
}

extension Color {
    /// The track colour of the app (magenta, lighter in dark mode).
    static let track = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF / 255, green: 0x4F / 255, blue: 0xAE / 255, alpha: 1)
            : UIColor(red: 0xC2 / 255, green: 0x18 / 255, blue: 0x7A / 255, alpha: 1)
    })
}
