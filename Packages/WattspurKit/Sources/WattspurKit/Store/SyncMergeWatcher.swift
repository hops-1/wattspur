import CoreData
import Foundation

/// Runs `RideLibrary.mergeSyncDuplicates()` when the library syncs with iCloud (B-216, V-15): once at
/// the start, then after changes from iCloud, on the Mac and on the iPhone alike.
///
/// CloudKit imports in batches, and a bike can arrive a moment before the rides that point to it. A
/// bike without rides may look like an untouched default bike and be merged away. So the merge waits
/// until the changes have been quiet for a while and no import is running.
@MainActor
public final class SyncMergeWatcher {
    /// What an event of the CloudKit mirror says, without the notification (which is not `Sendable`).
    struct Event: Sendable, Equatable {
        var id: UUID
        var isImport: Bool
        var isFinished: Bool
    }

    private let library: RideLibrary
    private let quietTime: Duration
    private let importTimeout: Duration
    private var pending: Task<Void, Never>?
    private var watching: [Task<Void, Never>] = []
    /// Imports of the mirror that have started and not yet ended, with when they started.
    private var importStarts: [UUID: ContinuousClock.Instant] = [:]
    /// Imports of the mirror that have started and not yet ended.
    var runningImports: Set<UUID> { Set(importStarts.keys) }
    /// Called after a merge that removed something, e.g. to reload a list.
    public var onMerge: ((SyncMergeReport) -> Void)?

    /// - Parameter importTimeout: after this an import counts as ended even without its end: an app
    ///   suspended in the background may never get it, and the merge would wait until the next launch
    ///   (R-37).
    public init(library: RideLibrary, quietTime: Duration = .seconds(3), importTimeout: Duration = .seconds(120)) {
        self.library = library
        self.quietTime = quietTime
        self.importTimeout = importTimeout
    }

    /// Merges now and then after each change from iCloud.
    public func start() {
        guard watching.isEmpty else { return }
        mergeNow()
        watching.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange).map({ _ in () }) {
                self?.changed()
            }
        })
        watching.append(Task { [weak self] in
            let events = NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification)
                .compactMap { note -> Event? in
                    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return nil }
                    return Event(id: event.identifier, isImport: event.type == .import, isFinished: event.endDate != nil)
                }
            for await event in events {
                self?.handle(event)
            }
        })
    }

    public func stop() {
        watching.forEach { $0.cancel() }
        watching = []
        pending?.cancel()
        pending = nil
    }

    func handle(_ event: Event) {
        if event.isImport {
            if event.isFinished {
                importStarts[event.id] = nil
            } else if importStarts[event.id] == nil {
                importStarts[event.id] = .now
            }
        }
        changed()
    }

    /// Waits for quiet, then merges; a new change starts the wait again. While an import runs it
    /// looks again when the oldest one times out.
    func changed() {
        pending?.cancel()
        pending = Task { [weak self, quietTime] in
            try? await Task.sleep(for: quietTime)
            guard !Task.isCancelled, let self else { return }
            self.forgetStaleImports()
            if let oldest = self.importStarts.values.min() {
                try? await Task.sleep(until: oldest + self.importTimeout, clock: .continuous)
                guard !Task.isCancelled else { return }
                self.changed()
                return
            }
            self.mergeNow()
        }
    }

    private func forgetStaleImports() {
        let now = ContinuousClock.now
        importStarts = importStarts.filter { now - $0.value < importTimeout }
    }

    @discardableResult
    func mergeNow() -> SyncMergeReport {
        let report = library.mergeSyncDuplicates()
        if !report.isEmpty { onMerge?(report) }
        return report
    }
}
