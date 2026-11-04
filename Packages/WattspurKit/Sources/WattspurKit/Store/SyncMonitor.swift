import CloudKit
import CoreData
import Foundation
import Network
import Observation
import SwiftData

/// What keeps the sync from working, as the user can act on it (B-220). The apps word it.
public enum SyncProblem: Equatable, Sendable {
    /// Not signed in to iCloud, or iCloud is off for Wattspur: changes stay on this device.
    case noAccount
    /// iCloud is restricted on this device (parental controls, a managed device).
    case restricted
    /// The iCloud storage is full: changes stay on this device until there is room.
    case quotaExceeded
    /// No connection for a while.
    case offline
    /// Anything else that lasts; the text is the system's.
    case other(String)
}

/// The account as CloudKit reports it.
public enum SyncAccount: Equatable, Sendable {
    case unknown, available, noAccount, restricted, temporarilyUnavailable

    public init(_ status: CKAccountStatus) {
        switch status {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        case .couldNotDetermine: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

/// The state of the sync for the settings on the Mac and the tab “More” on the iPhone (B-220):
/// when it last worked, whether something waits for the upload, and what keeps it from working.
///
/// It follows the events of the CloudKit mirror (`NSPersistentCloudKitContainer.eventChangedNotification`).
/// Short delays are normal (V-15: 30 s to 1 min), so a missing network or another passing failure
/// only counts once it has lasted `patience`. A full storage and a missing account count at once.
@MainActor @Observable
public final class SyncMonitor {
    /// A finished or started event of the mirror, without the notification (which is not `Sendable`).
    struct Event: Sendable {
        enum Kind: Sendable { case setup, `import`, export }
        var id: UUID
        var kind: Kind
        var startDate: Date
        var endDate: Date?
        var succeeded: Bool
        var failure: Failure?
    }

    /// A failure as far as it matters here.
    enum Failure: Equatable, Sendable {
        case notAuthenticated, quotaExceeded, offline, transient, other(String)
    }

    /// The last import or export that worked, also from an earlier start.
    public private(set) var lastSync: Date?
    /// An import or export is running. Without a network the mirror keeps an export open until the
    /// connection is back (V-15, flight mode), so it does not count then.
    public var isSyncing: Bool { !running.isEmpty && offlineSince == nil }
    /// Something was saved on this device after the last export started, so it is not in iCloud yet.
    public var hasPendingChanges: Bool {
        guard let lastLocalSave else { return false }
        return lastExportStart.map { $0 < lastLocalSave } ?? true
    }
    public private(set) var account: SyncAccount = .unknown

    private var running = Set<UUID>()
    private var failure: (kind: Failure, since: Date)?
    private var lastLocalSave: Date?
    private var lastExportStart: Date?
    /// Since when the device has no network; `nil` while it has one.
    private var offlineSince: Date?
    private var pathMonitor: NWPathMonitor?
    private let patience: TimeInterval
    private let defaults: UserDefaults
    private let accountStatus: (@Sendable () async -> SyncAccount)?
    private var watching: [Task<Void, Never>] = []

    static let lastSyncKey = "syncLastSuccess"

    /// `accountStatus` asks CloudKit for the account, `nil` in tests. Create it only with the iCloud
    /// entitlement: `CKContainer` traps without it.
    public init(defaults: UserDefaults = .standard, patience: TimeInterval = 120,
                accountStatus: (@Sendable () async -> SyncAccount)?) {
        self.defaults = defaults
        self.patience = patience
        self.accountStatus = accountStatus
        lastSync = defaults.object(forKey: Self.lastSyncKey) as? Date
    }

    /// The monitor for Wattspur's container.
    public static func forLibrary(defaults: UserDefaults = .standard) -> SyncMonitor {
        SyncMonitor(defaults: defaults) {
            let status = try? await CKContainer(identifier: LibrarySync.containerIdentifier).accountStatus()
            return status.map(SyncAccount.init) ?? .unknown
        }
    }

    /// What keeps the sync from working now; `nil` while it works or the delay is short.
    public func problem(now: Date = .now) -> SyncProblem? {
        switch account {
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        default: break
        }
        if let offlineSince, now.timeIntervalSince(offlineSince) >= patience { return .offline }
        guard let failure else { return nil }
        switch failure.kind {
        case .notAuthenticated: return .noAccount
        case .quotaExceeded: return .quotaExceeded
        case .offline: return now.timeIntervalSince(failure.since) >= patience ? .offline : nil
        case .transient: return nil
        case .other(let text): return now.timeIntervalSince(failure.since) >= patience ? .other(text) : nil
        }
    }

    // MARK: - Watching

    public func start() {
        guard watching.isEmpty else { return }
        refreshAccount()
        watching.append(Task { [weak self] in
            let events = NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification)
                .compactMap { note -> Event? in
                    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { return nil }
                    return Event(event)
                }
            for await event in events { self?.handle(event) }
        })
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.setOnline(online) }
        }
        pathMonitor.start(queue: .global(qos: .utility))
        self.pathMonitor = pathMonitor
        watching.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged).map({ _ in () }) {
                self?.refreshAccount()
            }
        })
        watching.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave).map({ _ in () }) {
                self?.noteLocalSave()
            }
        })
    }

    public func stop() {
        watching.forEach { $0.cancel() }
        watching = []
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    /// Asks for the account again, e.g. when the app comes back to the front.
    public func refreshAccount() {
        guard let accountStatus else { return }
        Task { [weak self] in
            let account = await accountStatus()
            self?.account = account
        }
    }

    // MARK: - State

    func handle(_ event: Event) {
        if event.kind == .export, event.endDate == nil {
            lastExportStart = max(lastExportStart ?? event.startDate, event.startDate)
        }
        guard let end = event.endDate else {
            if event.kind != .setup { running.insert(event.id) }
            return
        }
        running.remove(event.id)
        if event.succeeded {
            failure = nil
            // Offline the mirror may end events as done that reached nothing (V-15, flight mode).
            if event.kind != .setup, offlineSince == nil {
                lastSync = max(lastSync ?? end, end)
                defaults.set(lastSync, forKey: Self.lastSyncKey)
            }
        } else if let kind = event.failure {
            // The failure keeps the time it began while it lasts.
            let since = failure.flatMap { $0.kind == kind ? $0.since : nil } ?? end
            failure = (kind, since)
        }
    }

    func noteLocalSave(at date: Date = .now) {
        lastLocalSave = date
    }

    func setOnline(_ online: Bool, at date: Date = .now) {
        if online { offlineSince = nil } else if offlineSince == nil { offlineSince = date }
    }

    func setAccount(_ account: SyncAccount) {
        self.account = account
    }

    // MARK: - Errors

    /// Sorts a CloudKit error, looking into partial failures and underlying errors.
    nonisolated static func failure(of error: Error?) -> Failure? {
        guard let error else { return nil }
        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain, let code = CKError.Code(rawValue: nsError.code) {
            switch code {
            case .notAuthenticated, .managedAccountRestricted, .accountTemporarilyUnavailable: return .notAuthenticated
            case .quotaExceeded: return .quotaExceeded
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy: return .offline
            // The mirror handles these itself (V-15: after a reset it uploads again).
            case .zoneNotFound, .userDeletedZone, .changeTokenExpired, .serverRecordChanged, .operationCancelled: return .transient
            case .partialFailure:
                let inner = (nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error]).map { Array($0.values) } ?? []
                let kinds = inner.compactMap { failure(of: $0) }
                return kinds.first { $0 == .quotaExceeded } ?? kinds.first { $0 == .notAuthenticated } ?? kinds.first ?? .transient
            default: break
            }
        }
        if nsError.domain == NSURLErrorDomain { return .offline }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error, let kind = failure(of: underlying) { return kind }
        return .other(nsError.localizedDescription)
    }
}

extension SyncMonitor.Event {
    init(_ event: NSPersistentCloudKitContainer.Event) {
        let kind: Kind
        switch event.type {
        case .import: kind = .import
        case .export: kind = .export
        default: kind = .setup
        }
        self.init(id: event.identifier, kind: kind, startDate: event.startDate, endDate: event.endDate,
                  succeeded: event.succeeded, failure: event.succeeded ? nil : SyncMonitor.failure(of: event.error))
    }
}
