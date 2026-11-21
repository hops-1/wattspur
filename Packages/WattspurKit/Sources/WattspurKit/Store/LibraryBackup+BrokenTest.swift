import Foundation
import SwiftData

extension LibraryBackup {
    /// For `-WattspurBrokenLibraryTest YES` in the apps' debug builds (B-264): a library at `url`, in a
    /// temporary folder, that starts out damaged. Writes the damaged file only the first time (nothing
    /// there and nothing set aside yet) and returns the configuration for it, without iCloud.
    public static func prepareBrokenLibraryTest(at url: URL) -> ModelConfiguration {
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: url.path), keptFolders(storeURL: url).isEmpty {
            try? Data(repeating: 7, count: 8192).write(to: url)
        }
        return LibrarySync.configuration(requested: false, available: false, url: url)
    }
}
