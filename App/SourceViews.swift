import SwiftUI
import WattspurKit

// The source of a ride on screen (B-145, IMP-04): the symbol in a row, the filter, and the
// line in the ride detail that says where the figures come from.

extension Color {
    /// "≈ estimated": a dark orange on light, a light one on dark, readable as text (NFR-16).
    static let estimate = Color.adaptive(light: 0xA45800, dark: 0xFFB340)
}

/// "GPX" next to a file name or a ride; "+GPX" for a Bosch ride that has a GPX attached.
struct SourcePill: View {
    var badge: RideSourceBadge = .gpx
    /// The background of a selected row is the accent colour: the pill turns light there.
    @Environment(\.backgroundProminence) private var prominence

    private var text: String { badge == .attachedGPX ? "+GPX" : "GPX" }

    private var label: Text {
        badge == .attachedGPX ? Text("Source: Bosch FIT, GPX attached") : Text("Source: GPX file")
    }

    var body: some View {
        let onAccent = prominence == .increased
        HStack(spacing: 3) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").font(.system(size: 8, weight: .bold))
            Text(verbatim: text).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(onAccent ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .background(onAccent ? AnyShapeStyle(.white.opacity(0.24)) : AnyShapeStyle(.quaternary.opacity(0.7)), in: Capsule())
        .help(label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

extension SourceFilter {
    /// What the filter shows, in the menu and in the chip of the list.
    var title: LocalizedStringKey {
        switch self {
        case .all: "All sources"
        case .fit: "Bosch FIT"
        case .gpx: "GPX"
        }
    }
}

/// The choices of the source filter. Only if there is a ride from a GPX file: before that
/// there is nothing to tell apart.
struct SourceFilterPicker: View {
    @Binding var filter: SourceFilter
    let hasGPXRides: Bool

    var body: some View {
        if hasGPXRides {
            Picker("Source", selection: Binding(get: { filter.resolved(hasGPXRides: true) }, set: { filter = $0 })) {
                Text("All sources").tag(SourceFilter.all)
                Text("Bosch FIT (also with an attached GPX)").tag(SourceFilter.fit)
                Text(verbatim: "GPX").tag(SourceFilter.gpx)
            }
        }
    }
}

/// "Source: All sources ▾": the filter of an area with its own choice, remembered per area like the
/// bike filter. Outlined in the accent colour while it filters.
struct SourceFilterMenu: View {
    @Binding var filter: SourceFilter
    let hasGPXRides: Bool

    var body: some View {
        if hasGPXRides {
            let effective = filter.resolved(hasGPXRides: true)
            Menu {
                SourceFilterPicker(filter: $filter, hasGPXRides: true)
                    .pickerStyle(.inline)
                    .labelsHidden()
            } label: {
                HStack(spacing: 6) {
                    Text("Source:").foregroundStyle(.secondary)
                    Text(effective.title).fontWeight(.semibold)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.leading, 12)
                .padding(.trailing, 9)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.6), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: effective.isActive ? 1.5 : 0))
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Text("Show only the rides from one kind of file"))
            .accessibilityLabel(Text("Filter by source"))
            .accessibilityValue(Text(effective.title))
        }
    }
}

// MARK: - Ride detail

/// The line below the title of a ride from a GPX file or with a GPX attached: where it comes from, and
/// "≈ Totals estimated" with the reason (mockup "GPX-Fahrten anzeigen").
struct RideSourceLine: View {
    let ride: Ride
    @State private var showingInfo = false

    var body: some View {
        if let badge = ride.sourceBadge {
            HStack(spacing: 10) {
                sourcePill(badge)
                if ride.summaryEstimatedFromGPS {
                    Button { showingInfo.toggle() } label: {
                        HStack(spacing: 6) {
                            Text(verbatim: "≈").font(.system(size: 15, weight: .bold))
                            Text("Totals estimated").fontWeight(.semibold)
                            Image(systemName: "info.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(Color.estimate)
                        .padding(.leading, 8)
                        .padding(.trailing, 12)
                        .frame(height: 28)
                        .background(Color.estimate.opacity(0.14), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Totals estimated"))
                    .accessibilityHint(Text("Shows why the totals are estimated"))
                    .popover(isPresented: $showingInfo, arrowEdge: .bottom) { EstimatedTotalsInfo() }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func sourcePill(_ badge: RideSourceBadge) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").font(.system(size: 11, weight: .semibold))
            sourceText(badge)
        }
        .font(.caption)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: 28)
        .background(.quaternary.opacity(0.6), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    /// "Source: GPX · komoot-odenwald-tour.gpx" or "Source: Bosch FIT · GPX attached: tour.gpx".
    private func sourceText(_ badge: RideSourceBadge) -> some View {
        let file = badge == .gpx ? ride.sourceFile?.fileName : ride.attachedSourceName
        let head = badge == .gpx ? Text("Source: GPX") : Text("Source: Bosch FIT · GPX attached")
        return HStack(spacing: 4) {
            head.fontWeight(.semibold)
            if let file, !file.isEmpty {
                Text(verbatim: "· \(file)").lineLimit(1).truncationMode(.middle)
            }
        }
    }
}

/// Why the totals of a GPX ride are "estimated".
private struct EstimatedTotalsInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why “estimated”?").font(.headline)
            Text("This ride comes from a GPX file. Wattspur computes ride time, distance, speed and ascent from the file’s GPS points; the bike does not report them itself.")
            VStack(alignment: .leading, spacing: 4) {
                bullet("Gaps of 30 s or more between two points do not count as ride time.")
                bullet("Standing still (below 0.8 m/s) does not count as ride time.")
                bullet("Elevation is smoothed; ascent and descent count from 3 m.")
            }
            Text("If you have the same ride as a Bosch FIT, import it: Wattspur adds the Bosch values.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 400, alignment: .leading)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: "•")
            Text(text)
        }
    }
}

// MARK: - Rides that lack a value (B-146)

/// "9 of 12 rides": under a figure that only some of the rides have, like the power or the ascent of GPX
/// files. Nothing where every ride has it.
struct CoverageNote: View {
    let coverage: ValueCoverage

    var body: some View {
        if coverage.isPartial || coverage.isNone {
            Text("\(coverage.have) of \(coverage.total) rides")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
