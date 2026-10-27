import SwiftUI

/// The "Customize Map" button on a map and its window (B-061, after komoot): the map type as
/// pictures, and on the map of all rides also lines or heat map. Replaces the segmented pickers
/// that had no room for six map types.
struct MapCustomizeButton: View {
    @Binding var mapType: RideMapType
    /// Lines or heat map; only on the map of all rides.
    var mode: Binding<RidesMapStyle.Mode>?
    /// Whether lines or heat map are shown at all; a second click on the chosen one hides them.
    var showsRides: Binding<Bool>?
    /// Grey while a ride is highlighted or the map is empty, as the picker was before.
    var modeDisabled = false
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: "square.3.layers.3d")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(Text("Customize Map"))
        .accessibilityLabel(Text("Customize Map"))
        .accessibilityValue(Text(mapType.label))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            MapCustomizePanel(mapType: $mapType, mode: mode, showsRides: showsRides, modeDisabled: modeDisabled)
        }
    }
}

/// The content of the window, also used for the default in the settings.
struct MapCustomizePanel: View {
    @Binding var mapType: RideMapType
    var mode: Binding<RidesMapStyle.Mode>?
    var showsRides: Binding<Bool>?
    var modeDisabled = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customize Map").font(.title3.bold())
            section("Map Type") {
                MapTypeGrid(mapType: $mapType)
            }
            if let mode {
                section("Display") {
                    let shown = showsRides?.wrappedValue ?? true
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(RidesMapStyle.Mode.allCases) { option in
                            MapStyleTile(kind: .display(option), label: option == .lines ? "Lines" : "Heat Map",
                                         isSelected: shown && mode.wrappedValue == option) {
                                // A second click on the chosen display hides the rides; any click shows them again.
                                if shown && mode.wrappedValue == option, let showsRides {
                                    showsRides.wrappedValue = false
                                } else {
                                    mode.wrappedValue = option
                                    showsRides?.wrappedValue = true
                                }
                            }
                        }
                    }
                    .disabled(modeDisabled)
                    if showsRides != nil {
                        Text(shown ? "Click the chosen display again to hide the rides." : "Rides hidden. Click a display to show them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                openURL(HelpLinks.url(.views))
            } label: {
                Label("Map data and licences", systemImage: "questionmark.circle")
            }
            .buttonStyle(.link)
        }
        .padding(20)
        .frame(width: 330)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}

/// The six map types in two rows: Apple's maps, then the OpenStreetMap styles.
struct MapTypeGrid: View {
    @Binding var mapType: RideMapType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([RideMapType.apple, RideMapType.openStreetMapStyles], id: \.self) { row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(row) { type in
                        MapStyleTile(kind: .map(type), label: type.label, isSelected: mapType == type) { mapType = type }
                    }
                }
            }
        }
    }
}

/// A picture with its name below; the chosen one has a frame in the accent colour.
private struct MapStyleTile: View {
    let kind: MapStyleThumbnail.Kind
    let label: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MapStyleThumbnail(kind: kind)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                    }
                Text(label)
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 86)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
