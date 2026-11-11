import Foundation

extension LibraryBackup {
    /// The optional automatic backup of the iPhone (B-302): when the app opens and the last backup is older
    /// than a week, a backup goes into the folder the rider chose last; only the newest three automatic
    /// backups stay there. Backups made by hand, on the Mac or by another app are never deleted.
    public enum Automatic {
        public static let interval: TimeInterval = 7 * 24 * 60 * 60
        public static let kept = 3

        /// Whether an automatic backup is due: never backed up, or the last backup is older than `interval`.
        public static func isDue(lastBackup: Date?, now: Date = .now) -> Bool {
            guard let lastBackup else { return true }
            return now.timeIntervalSince(lastBackup) >= interval
        }

        /// Deletes the automatic backups in `folder` beyond the newest `keep` and returns what it deleted.
        /// Only folders whose manifest says `automatic` count; everything else stays.
        @discardableResult
        public static func prune(in folder: URL, keep: Int = kept) -> [URL] {
            let fm = FileManager.default
            guard let items = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }
            let automatic: [(url: URL, date: Date)] = items.compactMap { url in
                guard url.lastPathComponent.hasPrefix("Wattspur Backup"),
                      let data = try? Data(contentsOf: url.appending(path: manifestName)),
                      let manifest = try? decoder.decode(Manifest.self, from: data),
                      manifest.automatic == true
                else { return nil }
                return (url, manifest.createdAt)
            }
            let old = automatic.sorted { $0.date > $1.date }.dropFirst(max(keep, 0))
            var deleted: [URL] = []
            for item in old where (try? fm.removeItem(at: item.url)) != nil {
                deleted.append(item.url)
            }
            return deleted
        }
    }
}
