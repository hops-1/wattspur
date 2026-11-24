import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WattspurCore
import WattspurSymbols
import WattspurKit
import WattspurMap

/// One page of “More” (B-298). `embedded` is the page beside the list in landscape, where the
/// navigation bar is hidden: buttons from the bar then sit in the page itself.
struct MorePageView: View {
    let page: MorePage
    var embedded = false

    var body: some View {
        switch page {
        case .profile: ProfilePage()
        case .view: ViewPage()
        case .maps: MapsPage()
        case .library: LibraryPage()
        case .trash: TrashView(embedded: embedded)
        case .help: HelpPage()
        case .about: AboutPage()
        case .testTools: TestToolsPage()
        case .recording: AutoStartPage()
        }
    }
}
