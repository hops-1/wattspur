import SwiftUI
import WattspurKit

// The sport switch at the top of the sidebar (B-288, `DESIGN-SPORTARTEN.md`): Cycling · Vehicles ·
// Running. Rides, Analysis, Highlights and Map show only the chosen sport; the trash and the
// profile are for all of them.

extension EnvironmentValues {
    /// The sport the main window shows; cycling where no switch is (Settings, other windows).
    @Entry var shownSport: Sport = .cycling
}

extension Sport {
    /// The name in the switch.
    var title: LocalizedStringKey {
        switch self {
        case .cycling: "Cycling"
        case .vehicle: "Vehicles"
        case .running: "Running"
        }
    }

    var symbol: String {
        switch self {
        case .cycling: "bicycle"
        case .vehicle: "car"
        case .running: "figure.run"
        }
    }

    /// "All bikes", "All vehicles", "All shoes": the device filter's first choice.
    var allDevicesTitle: LocalizedStringKey {
        switch self {
        case .cycling: "All bikes"
        case .vehicle: "All vehicles"
        case .running: "All shoes"
        }
    }

    /// The device filter's label before the chosen device.
    var deviceFilterLabel: LocalizedStringKey {
        switch self {
        case .cycling: "Bike:"
        case .vehicle: "Vehicle:"
        case .running: "Shoes:"
        }
    }
}

/// The switch itself: a segmented control in the wide sidebar, the symbols one below the other in
/// the icon-only rail. Shown only from the second sport on (`SportChoice.showsSwitch`).
struct SportSwitch: View {
    let sports: [Sport]
    @Binding var selection: Sport
    let compact: Bool

    var body: some View {
        if compact {
            VStack(spacing: 2) {
                ForEach(sports) { sport in
                    let selected = sport == selection
                    Button { selection = sport } label: {
                        Image(systemName: sport.symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(selected ? Color.accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selected ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help(Text(sport.title))
                    .accessibilityLabel(Text(sport.title))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Divider() }
            .padding(.bottom, 6)
        } else {
            Picker("Sport", selection: $selection) {
                ForEach(sports) { sport in
                    Label(sport.title, systemImage: sport.symbol).tag(sport)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(Text("Show the rides of one sport"))
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }
}
