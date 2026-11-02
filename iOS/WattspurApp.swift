import SwiftUI

/// The iPhone app (iOS 0.x, B-204 ff.): the overview with the sample ride and the tab “More” with
/// the folder shared with the Mac; the tab “Rides” follows with 0.2 (docs/BACKLOG.md, design C).
@main
struct WattspurApp: App {
    @State private var folder = ImportFolder()
    // Lives as long as the app, so a test keeps running when the tab changes (spike V-14).
    @State private var gpsTest = GPSTest()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Overview", systemImage: "square.grid.2x2") {
                    NavigationStack {
                        OverviewView()
                    }
                }
                Tab("More", systemImage: "ellipsis") {
                    NavigationStack {
                        MoreView()
                    }
                }
            }
            .tint(.track)
            .environment(folder)
            .environment(gpsTest)
        }
    }
}
