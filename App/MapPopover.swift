import SwiftUI
import WattspurKit

/// The rides at a clicked spot on the map of all rides (B-109, MAP-05).
struct MapPopover {
    static let width: CGFloat = 300
    static let height: CGFloat = 330

    /// Where the click was, in the map's coordinates (origin top left).
    var point: CGPoint
    /// Newest first.
    var rides: [MapRide]
    /// The ride picked in the list: it stands out on the map and the card shows it.
    var focus: UUID?

    /// Beside the clicked spot, kept inside the map.
    func offset(in size: CGSize) -> CGSize {
        let right = point.x + 20 + Self.width < size.width - 12
        let x = right ? point.x + 20 : point.x - 20 - Self.width
        let y = min(max(12, point.y - 60), max(12, size.height - Self.height - 12))
        return CGSize(width: max(12, x), height: y)
    }
}

/// "N rides pass here" with the rides, or the info card of one of them.
struct MapPopoverView: View {
    let popover: MapPopover
    let onFocus: (UUID?) -> Void
    let onClose: () -> Void
    let onSelectAll: () -> Void
    let onOpen: (UUID) -> Void
    /// Kilometres on new paths of a ride (B-115).
    var newPathsDistance: (MapRide) -> Double? = { _ in nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let id = popover.focus, let ride = popover.rides.first(where: { $0.id == id }) {
                infoCard(ride)
            } else {
                list
            }
        }
        .frame(width: MapPopover.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var title: Text {
        Text("\(popover.rides.count) rides pass here")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                title.font(.headline)
                Spacer()
                closeButton
            }
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 6)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(popover.rides) { ride in
                        Button { onFocus(ride.id) } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(verbatim: ride.name).font(.callout.weight(.semibold)).lineLimit(1)
                                    Text(verbatim: ride.figures.startDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Text(verbatim: RideFormat.distance(ride.figures.distance)).font(.callout).monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .help(Text("Show the ride on the map"))
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 230)
            Divider().padding(.top, 6)
            HStack(spacing: 8) {
                Button(action: onSelectAll) { Text("Select all \(popover.rides.count) in the list") }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Text("Click a ride to show it on the map.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
    }

    private func infoCard(_ ride: MapRide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { onFocus(nil) } label: {
                    Label { title } icon: { Image(systemName: "chevron.left") }
                }
                .buttonStyle(.link)
                Spacer()
                closeButton
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ride.name).font(.title3.bold()).lineLimit(2)
                Text(verbatim: ride.figures.startDate.formatted(date: .complete, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    figure("Distance", RideFormat.distance(ride.figures.distance))
                    figure("Ride time", RideFormat.duration(ride.figures.timerTime))
                }
                GridRow {
                    figure("Avg speed", RideFormat.speed(ride.figures.averageSpeed))
                    figure("Ascent", ride.figures.totalAscent.map { "\($0.formatted()) m" } ?? "–")
                }
                if let new = newPathsDistance(ride), ride.figures.distance > 0 {
                    GridRow {
                        let share = (new / ride.figures.distance).formatted(.percent.precision(.fractionLength(0)))
                        figure("New paths", "\(share) · \(RideFormat.distance(new))")
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                Button("Open in Ride Detail", systemImage: "arrow.up.right") { onOpen(ride.id) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Text("The other rides fade into the background.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
    }

    private func figure(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.callout.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            .buttonStyle(.plain)
            .help(Text("Close"))
            .accessibilityLabel(Text("Close"))
            .keyboardShortcut(.cancelAction)
    }
}
