import Foundation

/// Hands shared files to the app (B-301, B-361): the share extension writes one share into its own
/// folder under a hidden name, then renames it, so the app never reads a share that is half written
/// (`ImportInbox.collectShared`). Files are copied, not read into memory: the extension has little
/// memory, and five large GPX files at once used to be too much for it (S-45). For the file type only
/// the first 2 KB are read.
public enum SharedDrop {
    /// One shared thing: a file the extension may read, or data an app shared without a file.
    public enum Item: Sendable {
        case file(URL, suggestedName: String?)
        case data(Data, suggestedName: String?)

        var suggestedName: String? {
            switch self {
            case .file(let url, let name): name ?? url.lastPathComponent
            case .data(_, let name): name
            }
        }
    }

    /// How much of a file is read to tell FIT from GPX.
    public static let sniffLength = 2048

    /// The FIT or GPX type of an item, from its first bytes and then its name; nil for anything else
    /// or a file that cannot be read.
    public static func fileExtension(of item: Item) -> String? {
        switch item {
        case .file(let url, _):
            guard let head = head(of: url) else { return nil }
            return SharedItem.fileExtension(of: head, suggestedName: item.suggestedName)
        case .data(let data, _):
            return SharedItem.fileExtension(of: data.prefix(sniffLength), suggestedName: item.suggestedName)
        }
    }

    /// The first `sniffLength` bytes of a file, without reading the rest.
    static func head(of url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: sniffLength) ?? Data()
    }

    /// Writes the FIT and GPX items of one share as a folder in `base` and returns how many there
    /// were; other items are left out. Nothing is written when none is FIT or GPX.
    @discardableResult
    public static func write(_ items: [Item], into base: URL, id: String = UUID().uuidString) throws -> Int {
        let readable = items.compactMap { item -> (Item, String)? in
            guard let ext = fileExtension(of: item) else { return nil }
            return (item, SharedItem.fileName(suggestedName: item.suggestedName, fileExtension: ext))
        }
        guard !readable.isEmpty else { return 0 }
        let fileManager = FileManager.default
        let writing = base.appending(path: ".writing-\(id)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: writing, withIntermediateDirectories: true)
        do {
            var used: Set<String> = []
            for (item, name) in readable {
                var unique = name
                var number = 2
                while used.contains(unique.lowercased()) {
                    unique = "\((name as NSString).deletingPathExtension) \(number).\((name as NSString).pathExtension)"
                    number += 1
                }
                used.insert(unique.lowercased())
                let target = writing.appending(path: unique)
                switch item {
                case .file(let url, _): try fileManager.copyItem(at: url, to: target)
                case .data(let data, _): try data.write(to: target)
                }
            }
            try fileManager.moveItem(at: writing, to: base.appending(path: id, directoryHint: .isDirectory))
        } catch {
            try? fileManager.removeItem(at: writing)
            throw error
        }
        return readable.count
    }
}
