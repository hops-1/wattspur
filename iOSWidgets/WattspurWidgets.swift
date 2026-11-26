import ActivityKit
import AppIntents
import SwiftUI
import WattspurCore
import WattspurSymbols
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
                        if context.state.isReady == true {
                            ReadyText()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            CancelReadyButton()
                                .frame(maxWidth: 160)
                        } else {
                            ElapsedTime(start: context.attributes.start(context.state))
                                .font(.title2.weight(.bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            PauseButton(isPaused: context.state.isPaused)
                                .frame(maxWidth: 160)
                        }
                    }
                }
            } compactLeading: {
                ActivitySymbol(context: context)
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
                ActivitySymbol(context: context)
                    .foregroundStyle(Color.track)
            }
            .keylineTint(Color.track)
        }
        // CarPlay and the Smart Stack of the Apple Watch draw the small family (B-387); without it
        // CarPlay fell back to the compact views, symbol and distance only. A tap on the CarPlay tile
        // opens nothing: Apple keeps Live Activities in CarPlay non-interactive (WWDC25 “Turbocharge
        // your app for CarPlay”), and a `widgetURL` did not change that in the car (B-379, B-384).
        // Wattspur in CarPlay opens from its icon or the widget “This Week”.
        .supplementalActivityFamilies([.small])
    }

    /// Pause, an hourglass while ready (B-311), else the device's symbol.
    static func symbol(_ context: ActivityViewContext<RecordingAttributes>) -> String {
        if context.state.isReady == true { return "hourglass" }
        return context.state.isPaused ? "pause.fill" : context.attributes.device(context.state).symbol ?? "bicycle"
    }
}

/// The device's drawn symbol, as in the app (B-342); Pause or the hourglass instead while
/// `showsState` and the recording is paused or ready.
private struct ActivitySymbol: View {
    let context: ActivityViewContext<RecordingAttributes>
    var showsState = true

    var body: some View {
        if showsState, context.state.isReady == true || context.state.isPaused {
            Image(systemName: RecordingLiveActivity.symbol(context))
        } else if let kind = BikeKind(rawValue: context.attributes.device(context.state).kind ?? "") {
            BikeKindIcon(kind: kind, size: 18)
        } else {
            // An activity started by a build before 1.6 (40), or a bicycle.
            Image(systemName: context.attributes.device(context.state).symbol ?? "bicycle")
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<RecordingAttributes>
    @Environment(\.activityFamily) private var family

    var body: some View {
        if family == .small {
            SmallTile(context: context)
        } else {
            medium
        }
    }

    /// The Lock Screen and the banner, with the buttons.
    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label { Text(verbatim: "Wattspur") } icon: { ActivitySymbol(context: context, showsState: false) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.track)
                Spacer()
                if context.state.isReady == true {
                    Text("Ready")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue, in: .capsule)
                        .foregroundStyle(.white)
                } else if context.state.isPaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.orange, in: .capsule)
                        .foregroundStyle(.white)
                }
            }
            if context.state.isReady == true {
                // Auto-start (B-311): no time and no figures until the vehicle moves.
                ReadyText()
                CancelReadyButton()
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ElapsedTime(start: context.attributes.start(context.state))
                            .font(.title2.weight(.bold))
                    }
                    Spacer()
                    Figure(title: "Distance", value: ActivityFormat.distance(context.state.distance))
                    Spacer()
                    Figure(title: "Speed", value: ActivityFormat.speed(context.state.speed))
                }
                if let kind = context.attributes.device(context.state).side {
                    SideRow(kind: kind, lean: context.state.lean)
                }
                PauseButton(isPaused: context.state.isPaused)
            }
        }
        .padding()
    }
}

/// The small tile in CarPlay and on the Apple Watch (B-387): time, distance and speed, no buttons,
/// because CarPlay keeps the tile non-interactive. While ready only the hourglass and the hint.
private struct SmallTile: View {
    let context: ActivityViewContext<RecordingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                ActivitySymbol(context: context)
                    .foregroundStyle(Color.track)
                Spacer(minLength: 4)
                if context.state.isReady == true {
                    Text("Ready")
                        .foregroundStyle(.blue)
                } else if context.state.isPaused {
                    Text("Paused")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            if context.state.isReady == true {
                ReadyText()
                    .font(.caption)
            } else {
                ElapsedTime(start: context.attributes.start(context.state))
                    .font(.title3.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(Text("Time"))
                HStack(spacing: 8) {
                    Text(verbatim: ActivityFormat.distance(context.state.distance))
                        .accessibilityLabel(Text("Distance"))
                        .accessibilityValue(Text(verbatim: ActivityFormat.distance(context.state.distance)))
                    Text(verbatim: ActivityFormat.speed(context.state.speed))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Speed"))
                        .accessibilityValue(Text(verbatim: ActivityFormat.speed(context.state.speed)))
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
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

/// What “Ready” means (B-311).
private struct ReadyText: View {
    var body: some View {
        Text("The ride begins when you drive off.")
            .font(.subheadline)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

/// Ends “Ready” in the app (`CancelReadyIntent`, B-311).
private struct CancelReadyButton: View {
    var body: some View {
        Button(intent: CancelReadyIntent()) {
            Label("Cancel", systemImage: "xmark")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .tint(.gray)
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
