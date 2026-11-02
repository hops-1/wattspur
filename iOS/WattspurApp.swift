import SwiftUI

/// The iPhone app (iOS 0.x, B-204 ff.), design C: the overview with the totals and the last ride,
/// the rides from the Mac, and “More” with the folder shared with the Mac (docs/BACKLOG.md).
@main
struct WattspurApp: App {
    enum Tab: Hashable { case overview, rides, more }

    @Environment(\.scenePhase) private var scenePhase
    @State private var folder: ImportFolder
    @State private var library: PhoneLibrary
    // Lives as long as the app, so a test keeps running when the tab changes (spike V-14).
    @State private var gpsTest = GPSTest()
    @State private var tab = Tab.overview

    init() {
        let folder = ImportFolder()
        _folder = State(initialValue: folder)
        _library = State(initialValue: PhoneLibrary(folder: folder))
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                SwiftUI.Tab("Overview", systemImage: "square.grid.2x2", value: Tab.overview) {
                    NavigationStack {
                        OverviewView { tab = .rides }
                    }
                }
                SwiftUI.Tab("Rides", systemImage: "list.bullet", value: Tab.rides) {
                    NavigationStack {
                        RidesView()
                    }
                }
                SwiftUI.Tab("More", systemImage: "ellipsis", value: Tab.more) {
                    NavigationStack {
                        MoreView()
                    }
                }
            }
            .tint(.track)
            .environment(folder)
            .environment(library)
            .environment(gpsTest)
            // The Mac may have written a new state while the app was in the background.
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { Task { await library.refresh() } }
            }
        }
    }
}
