import SwiftData
import SwiftUI
import WattspurKit

// Menus around the bikes: "Import for" (B-135), "Assign Bike" and the bike of a ride.

/// The note after assigning rides, with "Undo" (B-135). One for the whole window.
@MainActor
@Observable
final class BikeAssignmentNotice {
    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let count: Int
        let bikeName: String

        var text: String {
            count == 1
                ? String(localized: "1 ride was assigned to “\(bikeName)”.")
                : String(localized: "\(count) rides were assigned to “\(bikeName)”.")
        }
    }

    private(set) var current: Notice?

    func show(count: Int, bikeName: String) { current = Notice(count: count, bikeName: bikeName) }
    func hide() { current = nil }
}

/// A bike's round symbol as an image for menu items, which cannot hold a view.
@MainActor
enum BikeMenuImage {
    static func image(_ bike: Bike) -> Image {
        let renderer = ImageRenderer(content: BikeChip(kind: bike.kind, color: bike.color, size: 18))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return Image(systemName: "bicycle") }
        image.isTemplate = false
        return Image(nsImage: image)
    }

    /// A menu item's label: the bike's symbol and name.
    @ViewBuilder
    static func label(_ bike: Bike) -> some View {
        Label { Text(verbatim: bike.name) } icon: { image(bike) }
    }
}

extension RideLibrary {
    /// Assigns rides to a bike, names the undo step and shows the note (B-135).
    func assign(_ rides: [Ride], to bike: Bike, undoManager: UndoManager?, notice: BikeAssignmentNotice) {
        let changed = assign(rides, to: bike)
        guard changed > 0 else { return }
        undoManager?.setActionName(String(localized: "Assign Bike"))
        notice.show(count: changed, bikeName: bike.name)
        AccessibilityNotification.Announcement(notice.current?.text ?? "").post()
    }
}

/// "Assign Bike ▸": a submenu with the open bikes, for the context menu of the list
/// and the selection of several rides. Not shown while there is only one bike.
struct BikeAssignMenu<Title: View>: View {
    let rides: [Ride]
    @ViewBuilder let label: Title
    @Query private var bikes: [Bike]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(BikeAssignmentNotice.self) private var notice

    var body: some View {
        let open = Bike.sorted(bikes.filter { !$0.isArchived })
        if open.count >= 2 {
            Menu {
                ForEach(open) { bike in
                    Button {
                        RideLibrary(context: modelContext, undoManager: undoManager)
                            .assign(rides, to: bike, undoManager: undoManager, notice: notice)
                    } label: {
                        BikeMenuImage.label(bike)
                    }
                    // Already all on this bike: nothing to do.
                    .disabled(rides.allSatisfy { $0.bike === bike })
                }
                Divider()
                Button("Manage Bikes…") { NotificationCenter.default.post(name: .showProfile, object: nil) }
            } label: {
                label
            }
        }
    }
}

/// "Import for ● Bike ▾": the bike new rides are assigned to, from the manual import
/// and the watched folder (B-135). Shown from two bikes on; the choice is the
/// active bike of the profile, so the star there and this menu always agree.
struct ImportBikeMenu: View {
    @Query private var bikes: [Bike]
    @Query private var riders: [Rider]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let open = Bike.sorted(bikes.filter { !$0.isArchived })
        if open.count >= 2 {
            let activeID = riders.first?.activeBikeID
            let active = open.first { $0.id == activeID } ?? open[0]
            HStack(spacing: 6) {
                Text("Import for").font(.caption).foregroundStyle(.secondary)
                Menu {
                    Picker("Import for", selection: Binding(get: { active.id }, set: { id in
                        if let bike = open.first(where: { $0.id == id }) { RideLibrary(context: modelContext).setActiveBike(bike) }
                    })) {
                        ForEach(open) { bike in
                            BikeMenuImage.label(bike).tag(bike.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Divider()
                    Button("Manage Bikes…") { NotificationCenter.default.post(name: .showProfile, object: nil) }
                } label: {
                    HStack(spacing: 6) {
                        BikeChip(kind: active.kind, color: active.color, size: 20)
                        Text(verbatim: active.name).lineLimit(1).frame(maxWidth: 150, alignment: .leading)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    }
                    .font(.callout.weight(.semibold))
                    .padding(.leading, 3)
                    .padding(.trailing, 9)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                    .contentShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(Text("New rides, also from the watched folder, go to this bike"))
                .accessibilityLabel(Text("Import for"))
                .accessibilityValue(Text(verbatim: active.name))
                Spacer(minLength: 0)
            }
        }
    }
}

/// The bike of the ride in the header of the ride detail, with a menu to move it (B-135).
/// Shown from two bikes on.
struct RideBikeMenu: View {
    let ride: Ride
    @Query private var bikes: [Bike]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(BikeAssignmentNotice.self) private var notice

    var body: some View {
        if bikes.count >= 2, let current = ride.bike {
            // Open bikes, and the ride's own bike even if it was archived since.
            let choices = Bike.sorted(bikes.filter { !$0.isArchived || $0 === current })
            Menu {
                Picker("Bike of this ride", selection: Binding(get: { current.id }, set: { id in
                    if let bike = choices.first(where: { $0.id == id }) {
                        RideLibrary(context: modelContext, undoManager: undoManager)
                            .assign([ride], to: bike, undoManager: undoManager, notice: notice)
                    }
                })) {
                    ForEach(choices) { bike in
                        BikeMenuImage.label(bike).tag(bike.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Divider()
                Button("Manage Bikes…") { NotificationCenter.default.post(name: .showProfile, object: nil) }
            } label: {
                HStack(spacing: 8) {
                    BikeChip(kind: current.kind, color: current.color, size: 22)
                    Text(verbatim: current.name).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                }
                .font(.callout.weight(.semibold))
                .padding(.leading, 4)
                .padding(.trailing, 11)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Text("Move this ride to another bike"))
            .accessibilityLabel(Text("Bike of this ride"))
            .accessibilityValue(Text(verbatim: current.name))
        }
    }
}

/// The note with "Undo" at the bottom of the window (B-135).
struct BikeAssignmentNoticeView: View {
    let notice: BikeAssignmentNotice.Notice
    let onUndo: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bicycle").foregroundStyle(.secondary)
            Text(verbatim: notice.text).font(.callout)
            Button(action: onUndo) {
                HStack(spacing: 4) { Text("Undo"); Text(verbatim: "⌘Z").foregroundStyle(.secondary) }
            }
                .buttonStyle(.glass)
                .controlSize(.small)
            Button(action: onClose) { Image(systemName: "xmark").font(.caption.weight(.bold)) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator.opacity(0.6)))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
    }
}

// MARK: - Filter (B-137)

/// The choices of the bike filter: all bikes, the open bikes, then the archived ones
/// (their rides stay in the filters). Only from two bikes on.
struct BikeFilterPicker: View {
    @Binding var filter: BikeFilter
    @Query private var bikes: [Bike]

    var body: some View {
        if bikes.count >= 2 {
            let sorted = Bike.sorted(bikes)
            let archived = sorted.filter(\.isArchived)
            Picker("Bike", selection: Binding(get: { filter.resolved(knownBikeIDs: Set(bikes.map(\.id))) }, set: { filter = $0 })) {
                Text("All bikes").tag(BikeFilter.all)
                ForEach(sorted.filter { !$0.isArchived }) { bike in
                    BikeMenuImage.label(bike).tag(BikeFilter.bike(bike.id))
                }
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { bike in
                            BikeMenuImage.label(bike).tag(BikeFilter.bike(bike.id))
                        }
                    }
                }
            }
        }
    }
}

/// "Bike: All bikes ▾": the filter of an area with its own choice, remembered per area
/// (B-137). Outlined in the accent color while it filters.
struct BikeFilterMenu: View {
    @Binding var filter: BikeFilter
    @Query private var bikes: [Bike]

    var body: some View {
        let known = Set(bikes.map(\.id))
        if known.count >= 2 {
            let effective = filter.resolved(knownBikeIDs: known)
            let selected = bikes.first { $0.id == effective.bikeID }
            Menu {
                BikeFilterPicker(filter: $filter)
                    .pickerStyle(.inline)
                    .labelsHidden()
            } label: {
                HStack(spacing: 6) {
                    Text("Bike:").foregroundStyle(.secondary)
                    if let selected {
                        BikeChip(kind: selected.kind, color: selected.color, size: 20)
                        Text(verbatim: selected.name).fontWeight(.semibold).lineLimit(1)
                    } else {
                        Text("All bikes").fontWeight(.semibold)
                    }
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
            .help(Text("Show only the rides of one bike"))
            .accessibilityLabel(Text("Filter by bike"))
            .accessibilityValue(selected.map { Text(verbatim: $0.name) } ?? Text("All bikes"))
        }
    }
}
