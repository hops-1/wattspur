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

    /// Waits until `condition` holds, up to `limit`; a fixed wait is too short on a busy machine (R-08).
    private func eventually(within limit: Duration = .seconds(3), _ condition: () throws -> Bool) async rethrows -> Bool {
        let end = ContinuousClock.now + limit
        while ContinuousClock.now < end {
            if try condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return try condition()
    }

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
        #expect(try await eventually { try riders() == 1 })
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
        #expect(try await eventually { try riders() == 1 })
        #expect(watcher.runningImports.isEmpty)
    }

    @Test("An import whose end never comes is forgotten after the timeout, then it merges (R-37)")
    func forgetsLostImport() async throws {
        let watcher = SyncMergeWatcher(library: library, quietTime: .milliseconds(20), importTimeout: .milliseconds(600))
        try makeTwoRiders()
        watcher.handle(.init(id: UUID(), isImport: true, isFinished: false))
        try await Task.sleep(for: .milliseconds(100))
        #expect(try riders() == 2)
        #expect(try await eventually { try riders() == 1 })
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
