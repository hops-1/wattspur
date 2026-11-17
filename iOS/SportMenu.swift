import SwiftUI
import WattspurCore

/// The capsule “Cycling ▾” (B-289, `DESIGN-SPORTARTEN.md`): a menu, not a segmented control, so it
/// fits narrow iPhones too. It stands in Overview, Rides and Map, and the choice holds for all three.
/// Each iPhone keeps its own choice; it is not synced. Only from the second sport on.
struct SportMenu: View {
    @Environment(PhoneLibrary.self) private var library
    @AppStorage(PhoneSettingsKey.shownSport) private var stored: Sport = .cycling
    /// The glass button of the map, with the symbol only, instead of the chip of the list.
    var glass = false

    var body: some View {
        let sports = library.state?.availableSports ?? [.cycling]
        if SportChoice.showsSwitch(available: sports) {
            let shown = SportChoice.resolved(stored, available: sports)
            Menu {
                Picker("Sport", selection: Binding(get: { shown }, set: { stored = $0 })) {
                    ForEach(sports) { sport in
                        Label(sport.totalsTitle, systemImage: sport.symbol).tag(sport)
                    }
                }
            } label: {
                label(shown)
            }
            .accessibilityLabel(Text("Sport"))
            .accessibilityValue(Text(shown.totalsTitle))
            .modifier(SportMenuStyle(glass: glass))
        }
    }

    private func label(_ sport: Sport) -> some View {
        HStack(spacing: 5) {
            Image(systemName: sport.symbol)
            // On the map only the symbol: there the period and the device need the room.
            if !glass { Text(sport.totalsTitle).lineLimit(1).fixedSize() }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .frame(height: glass ? 36 : 32)
        .foregroundStyle(glass ? Color.primary : Color.track)
        .background(glass ? Color.clear : Color.track.opacity(0.15), in: .capsule)
        .contentShape(.capsule)
    }
}

private struct SportMenuStyle: ViewModifier {
    let glass: Bool

    func body(content: Content) -> some View {
        if glass { content.buttonStyle(.glass) } else { content.buttonStyle(.plain) }
    }
}

/// The sport the tabs show, for views that need it as a value.
@propertyWrapper
struct ShownSport: DynamicProperty {
    @Environment(PhoneLibrary.self) private var library
    @AppStorage(PhoneSettingsKey.shownSport) private var stored: Sport = .cycling

    @MainActor var wrappedValue: Sport { library.state?.shownSport(stored) ?? .cycling }
}

extension Sport {
    /// The device filter's first choice: “All Bikes”, “All Vehicles”, “All Shoes”.
    var allDevicesTitle: LocalizedStringKey {
        switch self {
        case .cycling: "All Bikes"
        case .vehicle: "All Vehicles"
        case .running: "All Shoes"
        }
    }

    /// The device filter's chip while it shows all.
    var deviceFilterTitle: LocalizedStringKey {
        switch self {
        case .cycling: "Bike"
        case .vehicle: "Vehicle"
        case .running: "Shoes"
        }
    }
}
