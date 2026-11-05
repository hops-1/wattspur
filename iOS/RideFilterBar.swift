import SwiftUI
import WattspurCore

/// Search and filters above the ride list (B-222): a search field for the name, then menus for
/// the period, the distance and the bike (only with two bikes or more), and how many rides are
/// left. The rule itself is `RideFilter` in the Kit, shared with the Mac (B-244).
struct RideFilterBar: View {
    @Binding var filter: RideFilter
    /// Tighter in landscape, where the screen is short (B-243).
    var compact = false
    var bikes: [RideExchange.Bike]
    var shown: Int
    var total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            searchField
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    periodMenu
                    distanceMenu
                    if bikes.count >= 2 { bikeMenu }
                    if filter.hasFilters {
                        // An ✕ rather than a word: it has to fit beside the menus in the narrow
                        // list of the landscape layout too.
                        Button {
                            filter.period = .all
                            filter.distance = .all
                            filter.bike = .all
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Reset"))
                    }
                }
            }
            .scrollIndicators(.hidden)
            if filter.isActive {
                Text("\(shown) of \(total) rides")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, compact ? 6 : 8)
        // Only behind the bar itself: reaching into the safe area, it would cover the large title.
        .background(.bar, ignoresSafeAreaEdges: [])
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search rides", text: $filter.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !filter.text.isEmpty {
                Button { filter.text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: compact ? 32 : 36)
        .background(Color.secondary.opacity(0.12), in: .capsule)
    }

    private var periodMenu: some View {
        Menu {
            Picker("Period", selection: $filter.period) {
                ForEach(RidePeriod.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            FilterChip(title: filter.period == .all ? "Period" : filter.period.label, active: filter.period != .all)
        }
    }

    private var distanceMenu: some View {
        Menu {
            Picker("Distance", selection: $filter.distance) {
                ForEach(RideDistanceBand.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            FilterChip(title: filter.distance == .all ? "Distance" : filter.distance.label, active: filter.distance != .all)
        }
    }

    private var bikeMenu: some View {
        let chosen = bikes.first { $0.id == filter.bike.bikeID }
        return Menu {
            Picker("Bike", selection: $filter.bike) {
                Text("All Bikes").tag(BikeFilter.all)
                ForEach(bikes) { bike in
                    Text(verbatim: bike.name).tag(BikeFilter.bike(bike.id))
                }
            }
        } label: {
            if let chosen {
                FilterChip(verbatim: chosen.name, active: true)
            } else {
                FilterChip(title: "Bike", active: false)
            }
        }
    }
}

/// A rounded button with a small arrow, filled in the track colour while its filter is set.
private struct FilterChip: View {
    private var text: Text
    var active: Bool

    init(title: LocalizedStringKey, active: Bool) {
        text = Text(title)
        self.active = active
    }

    init(verbatim: String, active: Bool) {
        text = Text(verbatim: verbatim)
        self.active = active
    }

    var body: some View {
        HStack(spacing: 4) {
            text.lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
        }
        .font(.subheadline.weight(active ? .semibold : .regular))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .foregroundStyle(active ? Color.track : Color.primary)
        .background(active ? Color.track.opacity(0.15) : Color.secondary.opacity(0.12), in: .capsule)
        .contentShape(.capsule)
    }
}

extension RidePeriod {
    var label: LocalizedStringKey {
        switch self {
        case .all: "All Time"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        case .thisYear: "This Year"
        case .last30Days: "Last 30 Days"
        case .last365Days: "Last 365 Days"
        }
    }
}

extension RideDistanceBand {
    /// Always in km, like the bands themselves.
    var label: LocalizedStringKey {
        switch self {
        case .all: "Any Distance"
        case .under10: "Under 10 km"
        case .from10To25: "10–25 km"
        case .from25To50: "25–50 km"
        case .over50: "Over 50 km"
        }
    }
}
