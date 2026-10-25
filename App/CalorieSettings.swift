import SwiftData
import SwiftUI
import WattspurKit

// The calorie mode (SET-06, B-067): "from pedal power" (default) or "with profile".

extension CalorieMode {
    /// "With profile" is built (B-067) but not offered yet: the factor and the time share are
    /// still to be checked against the Flow app (V-01, analysis of 25.10.2026). Switching this
    /// on shows the setting in "Calculation" and lets the stored mode count.
    static let withProfileAvailable = false
}

extension CalorieModel {
    /// The stored mode counts only while "with profile" is offered; otherwise it is "from work".
    init(mode: CalorieMode, rider: Rider?) {
        self.init(mode: CalorieMode.withProfileAvailable ? mode : .fromWork, profile: rider?.bodyProfile)
    }

    /// The text of the info next to calories: what the number is made of.
    var note: String {
        if usesProfile {
            String(localized: "Estimated from your pedal power plus your basal metabolic rate over the ride time")
        } else if !fallbackFields.isEmpty {
            String(localized: "“With profile” needs weight, height and birth year in your profile. Until then calories are estimated from your pedal power.")
        } else {
            String(localized: "Estimated from your pedal power")
        }
    }
}

extension CalorieMode {
    var name: LocalizedStringKey {
        switch self {
        case .fromWork: "From your pedal power (default)"
        case .withProfile: "With profile"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .fromWork: "Like the Flow app: the work done (kJ) plus a fixed share per hour of riding."
        case .withProfile: "Also adds your basal metabolic rate over the ride time, from your weight, height, age and sex."
        }
    }
}

extension BodyProfile.Field {
    var name: String {
        switch self {
        case .weight: String(localized: "weight")
        case .height: String(localized: "height")
        case .birthYear: String(localized: "birth year")
        }
    }
}

/// The calorie settings in "Calculation".
struct CalorieSettingsView: View {
    @AppStorage(SettingsKey.calorieMode) private var mode: CalorieMode = .fromWork
    @Query private var riders: [Rider]

    private var model: CalorieModel { CalorieModel(mode: mode, rider: riders.first) }

    var body: some View {
        Form {
            Section {
                Picker("Calories", selection: $mode) {
                    ForEach(CalorieMode.allCases) { calorieMode in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calorieMode.name)
                            Text(calorieMode.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(calorieMode)
                    }
                }
                .pickerStyle(.radioGroup)
                if !model.fallbackFields.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text("Missing in your profile: \(model.fallbackFields.map(\.name).formatted(.list(type: .and))). Calories are estimated from your pedal power until then.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        .font(.callout)
                        Button("Edit Profile…") { NotificationCenter.default.post(name: .showProfile, object: nil) }
                    }
                }
            } header: {
                Text("Calories")
            } footer: {
                Text("Calories are an estimate. The factors for calories and CO₂ will be adjustable here in a later version.")
            }
        }
        .formStyle(.grouped)
    }
}
