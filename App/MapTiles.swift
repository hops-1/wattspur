import SwiftUI
import WattspurKit
import WattspurMap

// The tiles themselves are loaded and drawn in the package (WattspurMap, B-186); here only the
// credit the servers ask for (docs/RECHERCHE-KARTEN.md).

/// The credit a tile server asks for, at the bottom right of the map; always visible.
struct TileAttribution: View {
    let source: TileSource

    var body: some View {
        Link(destination: source.attributionURL) {
            Text(verbatim: source.attribution)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        .help(Text("Map data and style: open the licence"))
        .accessibilityLabel(Text(verbatim: source.attribution))
    }
}

extension View {
    /// Puts the credit of an OpenStreetMap style on the map.
    func tileAttribution(for mapType: RideMapType) -> some View {
        overlay(alignment: .bottomTrailing) {
            if let source = mapType.tileSource {
                TileAttribution(source: source)
                    .frame(maxWidth: 360, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
            }
        }
    }
}
