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
    private var pending: Task<Void, Never>?
    private var watching: [Task<Void, Never>] = []
    /// Imports of the mirror that have started and not yet ended.
    private(set) var runningImports = Set<UUID>()
    /// Called after a merge that removed something, e.g. to reload a list.
    public var onMerge: ((SyncMergeReport) -> Void)?

    public init(library: RideLibrary, quietTime: Duration = .seconds(3)) {
        self.library = library
        self.quietTime = quietTime
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
            if event.isFinished { runningImports.remove(event.id) } else { runningImports.insert(event.id) }
        }
        changed()
    }

    /// Waits for quiet, then merges; a new change starts the wait again.
    func changed() {
        pending?.cancel()
        pending = Task { [weak self, quietTime] in
            try? await Task.sleep(for: quietTime)
            guard !Task.isCancelled, let self, self.runningImports.isEmpty else { return }
            self.mergeNow()
        }
    }

    @discardableResult
    func mergeNow() -> SyncMergeReport {
        let report = library.mergeSyncDuplicates()
        if !report.isEmpty { onMerge?(report) }
        return report
    }
}
