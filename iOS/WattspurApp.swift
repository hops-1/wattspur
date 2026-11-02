import SwiftUI

/// The iPhone app (iOS 0.1, B-204/B-205). For now it shows only the overview with the sample ride;
/// the tabs "Rides" and "More" follow with 0.2 (docs/BACKLOG.md, design C).
@main
struct WattspurApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Overview", systemImage: "square.grid.2x2") {
                    NavigationStack {
                        OverviewView()
                    }
                }
            }
            .tint(.track)
        }
    }
}
