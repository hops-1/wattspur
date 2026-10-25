import SwiftData
import SwiftUI
import WattspurKit

/// "Which bike?": asked when GPX files are imported by hand and there are two or more bikes,
/// because a GPX file does not say which bike it was ridden on (IMP-04, mockup "GPX importieren").
/// The watched folder does not ask; its files go to the active bike.
struct GPXBikeSheet: View {
    let question: ImportFlow.BikeQuestion
    let onConfirm: (Bike) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var bikes: [Bike]
    @Query private var riders: [Rider]
    @State private var chosen: UUID?
    @State private var facts: [URL: String] = [:]

    /// At most this many files are read for the list; the rest is counted.
    private static let listedFiles = 3

    private var open: [Bike] { Bike.sorted(bikes.filter { !$0.isArchived }) }
    private var activeID: UUID? { riders.first?.activeBikeID }
    private var selected: Bike? {
        open.first { $0.id == chosen } ?? open.first { $0.id == activeID } ?? open.first
    }
    private var gpx: [URL] { question.gpxURLs }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Which bike?").font(.title3.bold())
                    Text(gpx.count == 1
                         ? "GPX files do not say which bike they belong to. Wattspur assigns the ride to the bike you choose."
                         : "GPX files do not say which bike they belong to. Wattspur assigns the rides to the bike you choose.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(gpx.prefix(Self.listedFiles).enumerated()), id: \.offset) { index, url in
                    if index > 0 { Divider() }
                    HStack(spacing: 10) {
                        Image(systemName: "doc").foregroundStyle(.secondary).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: url.lastPathComponent).font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                            if let meta = facts[url] { Text(verbatim: meta).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                if gpx.count > Self.listedFiles {
                    Divider()
                    Text("… and \(gpx.count - Self.listedFiles) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 2) {
                ForEach(open) { bike in
                    BikeChoiceRow(bike: bike, isActive: bike.id == activeID, isSelected: bike.id == selected?.id) { chosen = bike.id }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Which bike?"))

            HStack(spacing: 12) {
                Text("In the watched folder the active bike is used. You can change a ride’s bike later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(gpx.count == 1 ? "Import 1 ride" : "Import \(gpx.count) rides") {
                    if let bike = selected { onConfirm(bike) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
            }
        }
        .padding(24)
        .frame(width: 540)
        .task { await readFacts() }
    }

    /// Distance, date and number of parts of the first files, read off the main thread.
    private func readFacts() async {
        let urls = Array(gpx.prefix(Self.listedFiles))
        let result = await Task.detached(priority: .userInitiated) { () -> [URL: String] in
            var out: [URL: String] = [:]
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url), let track = try? GPXRideImporter().parseTrack(data) else { continue }
                let km = (track.parts.reduce(0) { $0 + $1.distance } / 1000).formatted(.number.precision(.fractionLength(1)))
                let date = track.startDate.formatted(date: .abbreviated, time: .omitted)
                out[url] = track.parts.count > 1
                    ? String(localized: "\(km) km · \(date) · \(track.parts.count) parts")
                    : "\(km) km · \(date)"
            }
            return out
        }.value
        facts = result
    }
}

private struct BikeChoiceRow: View {
    let bike: Bike
    let isActive: Bool
    let isSelected: Bool
    let onPick: () -> Void

    var body: some View {
        let statistics = bike.statistics
        Button(action: onPick) {
            HStack(spacing: 10) {
                BikeChip(kind: bike.kind, color: bike.color, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: isActive ? "\(bike.name) ★" : bike.name).font(.callout.weight(.semibold))
                    Text("\(RideFormat.distance(statistics.totalDistance)) · \(statistics.rideCount) rides")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
