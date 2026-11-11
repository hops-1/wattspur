import Foundation

/// Where the share extension leaves shared files for the app (B-301): a folder in the App Group,
/// which both can reach. The app moves them into “On My iPhone › Wattspur › Import” when it opens
/// (`ImportInbox.collectShared`), and the import goes on from there as for any waiting file.
enum SharedImports {
    /// Opened by the extension after a share, so the app reads the files right away.
    static let openURL = URL(string: "wattspur://import")!

    static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetShare.appGroup)?
            .appending(path: "Shared Imports", directoryHint: .isDirectory)
    }

    static func isOpenURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == openURL.scheme && url.host() == openURL.host()
    }
}
