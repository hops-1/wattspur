import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurSymbols
import WattspurKit
import WattspurMap

// MARK: - Maps

struct MapsPage: View {
    /// The style of every map (B-226), the same choice as on the detail map.
    @AppStorage(PhoneSettingsKey.mapType) private var mapType: RideMapType = .standard

    var body: some View {
        Form {
            Section {
                Picker("Map Style", selection: $mapType) {
                    Section("Apple") {
                        ForEach(RideMapType.apple) { Text($0.label).tag($0) }
                    }
                    Section("OpenStreetMap") {
                        ForEach(RideMapType.openStreetMapStyles) { Text($0.label).tag($0) }
                    }
                }
            } footer: {
                Text("The OpenStreetMap styles come from volunteer servers; Wattspur loads only the tiles on screen and keeps them for a while. Without a connection the route shows on a plain ground.")
            }
        }
    }
}

// MARK: - View

/// How the iPad shows the charts of a ride (wish of Nils, B-292): stacked to swipe through, as on
/// the iPhone, or one below the other, as on the Mac.
struct ViewPage: View {
    @AppStorage(PhoneSettingsKey.padChartLayout) private var chartLayout: ChartLayout = .column

    var body: some View {
        Form {
            Section {
                Picker("Charts", selection: $chartLayout) {
                    ForEach(ChartLayout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Charts")
            } footer: {
                Text("Stacked: one chart at a time, swipe to the next, as on the iPhone. One below the other: all charts at once, as on the Mac. The map stays at the top either way.")
            }
        }
    }
}
