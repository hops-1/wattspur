import Foundation
import Testing
@testable import WattspurKit

/// The damaged test library of the debug builds (B-264, S-25): Mac and iPhone make it the same way.
@Suite("Broken library test")
struct BrokenLibraryTestTests {
    @Test("The first time writes a damaged file; the configuration has no iCloud")
    func firstTime() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-broken-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")
        let configuration = LibraryBackup.prepareBrokenLibraryTest(at: url)
        #expect(configuration.url == url)
        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(try Data(contentsOf: url) == Data(repeating: 7, count: 8192))
    }

    @Test("A library already there stays as it is")
    func keepsExisting() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "wattspur-broken-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "default.store")
        try Data("empty library".utf8).write(to: url)
        _ = LibraryBackup.prepareBrokenLibraryTest(at: url)
        #expect(try Data(contentsOf: url) == Data("empty library".utf8))
    }
}
