import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// When the apps merge the duplicates from the sync (B-216, V-15).
@MainActor
@Suite("Merge watcher")
struct SyncMergeWatcherTests {
    let container: ModelContainer
    let library: RideLibrary
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    /// Two riders, as after the first sync of a fresh iPhone.
    private func makeTwoRiders() throws {
        for seconds in [1_700_000_000.0, 1_800_000_000] {
            let rider = Rider()
            rider.createdAt = Date(timeIntervalSince1970: seconds)
            context.insert(rider)
        }
        try context.save()
    }

    private func riders() throws -> Int { try context.fetchCount(FetchDescriptor<Rider>()) }

    @Test("Start merges at once and reports it")
    func mergesAtStart() throws {
        try makeTwoRiders()
        let watcher = SyncMergeWatcher(library: library)
        var reports: [SyncMergeReport] = []
        watcher.onMerge = { reports.append($0) }
        watcher.start()
        defer { watcher.stop() }
        #expect(try riders() == 1)
        #expect(reports == [SyncMergeReport(riders: 1)])
    }

    @Test("A change merges once it has been quiet")
    func mergesAfterQuiet() async throws {
        let watcher = SyncMergeWatcher(library: library, quietTime: .milliseconds(50))
        try makeTwoRiders()
        watcher.changed()
        try await Task.sleep(for: .milliseconds(300))
        #expect(try riders() == 1)
    }

    @Test("No merge while an import is running, then after it ends")
    func waitsForImport() async throws {
        let watcher = SyncMergeWatcher(library: library, quietTime: .milliseconds(50))
        try makeTwoRiders()
        let id = UUID()
        watcher.handle(.init(id: id, isImport: true, isFinished: false))
        try await Task.sleep(for: .milliseconds(300))
        #expect(try riders() == 2)
        watcher.handle(.init(id: id, isImport: true, isFinished: true))
        try await Task.sleep(for: .milliseconds(300))
        #expect(try riders() == 1)
        #expect(watcher.runningImports.isEmpty)
    }

    @Test("Nothing to merge reports nothing")
    func nothingToMerge() {
        let watcher = SyncMergeWatcher(library: library)
        var called = false
        watcher.onMerge = { _ in called = true }
        #expect(watcher.mergeNow().isEmpty)
        #expect(!called)
    }
}
