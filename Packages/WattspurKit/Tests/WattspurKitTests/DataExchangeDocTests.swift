import Foundation
import SQLite3
import SwiftData
import Testing
import TestFixtures
@testable import WattspurKit

/// docs/reference/data-exchange.md describes the tables and columns of a backup (B-177). The schema
/// comes from SwiftData and changes with the models, so this makes a backup and compares both ways:
/// every column of a Wattspur table is documented, and nothing documented is gone.
@MainActor
@Suite("Data exchange documentation")
struct DataExchangeDocTests {
    /// Columns every table has; documented once under "Conventions".
    private static let common: Set<String> = ["Z_PK", "Z_ENT", "Z_OPT"]

    private static var documentURL: URL {
        // Tests/WattspurKitTests/<file> → the repository root.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "docs/reference/data-exchange.md")
    }

    /// The column names in the first cell of each table row, under each heading "### `ZNAME`".
    static func documentedColumns(_ text: String) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        var table: String?
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("#") {
                table = line.hasPrefix("### `Z") ? line.split(separator: "`").dropFirst().first.map(String.init) : nil
                if let table { result[table] = [] }
            } else if let current = table, line.hasPrefix("| `") {
                let firstCell = line.split(separator: "|").first ?? ""
                let names = firstCell.split(separator: "`").map(String.init).filter { $0.hasPrefix("Z") && !$0.contains(" ") }
                result[current, default: []].formUnion(names)
            }
        }
        return result
    }

    private func schema(of storeURL: URL) throws -> [String: Set<String>] {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        #expect(sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        func rows(_ sql: String, column: Int32) -> [String] {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
            var values: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW { values.append(String(cString: sqlite3_column_text(statement, column))) }
            return values
        }
        // Wattspur's tables: Z + model name, not SwiftData's own (Z_…) or its history (A…).
        let tables = rows("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'Z%' AND name NOT LIKE 'Z\\_%' ESCAPE '\\'", column: 0)
        return Dictionary(uniqueKeysWithValues: tables.map { ($0, Set(rows("PRAGMA table_info(\"\($0)\")", column: 1))) })
    }

    @Test("Every table and column of a backup is on the page, and nothing more")
    func tablesAndColumns() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "wattspur-doc-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let library = root.appending(path: "Library")
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        let storeURL = library.appending(path: "default.store")
        do {
            let container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(url: storeURL))
            // Saved by hand: an autosave timer that fires after the container is released stops the whole test run.
            container.mainContext.autosaveEnabled = false
            let rides = RideLibrary(context: container.mainContext)
            _ = rides.importFile(data: try Fixture.data("reinheim-rundfahrt"), fileName: "ride.fit", detectDuplicates: false)
            rides.save()
        }
        let backup = try LibraryBackup.create(storeURL: storeURL, in: root, appVersion: "test", build: "0", rideCount: 1)

        let actual = try schema(of: backup.appending(path: "default.store"))
        let documented = Self.documentedColumns(try String(contentsOf: Self.documentURL, encoding: .utf8))
        #expect(Set(actual.keys) == Set(documented.keys), "tables on the page differ from the backup")
        for (table, columns) in actual {
            let expected = columns.subtracting(Self.common)
            let onPage = documented[table] ?? []
            #expect(expected.subtracting(onPage).isEmpty, "\(table): not documented: \(expected.subtracting(onPage).sorted())")
            #expect(onPage.subtracting(expected).isEmpty, "\(table): documented but gone: \(onPage.subtracting(expected).sorted())")
        }
    }

    @Test("The manifest's keys are on the page")
    func manifest() throws {
        let text = try String(contentsOf: Self.documentURL, encoding: .utf8)
        let manifest = LibraryBackup.Manifest(createdAt: .now, appVersion: "1", build: "1", rideCount: 1)
        let keys = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any] ?? [:]
        for key in keys.keys { #expect(text.contains("`\(key)`"), "manifest key \(key) not documented") }
        #expect(LibraryBackup.Manifest.currentFormat == 1, "a new backup format needs the page updated")
    }

    @Test("The parser finds the tables and the names in combined cells")
    func parser() {
        let text = """
        ### `ZRIDE`
        | Column | Type | Meaning |
        |---|---|---|
        | `ZID` | UUID | Id |
        | `ZAVERAGESPEED`, `ZMAXSPEED` | m/s | Speeds |
        ### Time series
        | `time` | s | Not a column |
        """
        #expect(Self.documentedColumns(text) == ["ZRIDE": ["ZID", "ZAVERAGESPEED", "ZMAXSPEED"]])
    }
}
