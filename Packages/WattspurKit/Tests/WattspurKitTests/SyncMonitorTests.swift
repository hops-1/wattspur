import CloudKit
import Foundation
import Testing
@testable import WattspurKit

/// The sync status for the settings and the tab "More" (B-220).
@MainActor
@Suite("Sync status")
struct SyncMonitorTests {
    let defaults: UserDefaults
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        defaults = UserDefaults(suiteName: "SyncMonitorTests-\(UUID().uuidString)")!
    }

    private func monitor() -> SyncMonitor { SyncMonitor(defaults: defaults, patience: 120, accountStatus: nil) }

    private func event(_ kind: SyncMonitor.Event.Kind, at offset: TimeInterval, ended: Bool = true,
                       succeeded: Bool = true, failure: SyncMonitor.Failure? = nil, id: UUID = UUID()) -> SyncMonitor.Event {
        SyncMonitor.Event(id: id, kind: kind, startDate: start.addingTimeInterval(offset - 5),
                          endDate: ended ? start.addingTimeInterval(offset) : nil, succeeded: succeeded, failure: failure)
    }

    @Test("A finished import or export is the last sync, and it is kept for the next start")
    func lastSync() {
        let monitor = monitor()
        #expect(monitor.lastSync == nil)
        monitor.handle(event(.setup, at: 0))
        #expect(monitor.lastSync == nil)
        monitor.handle(event(.export, at: 10))
        #expect(monitor.lastSync == start.addingTimeInterval(10))
        #expect(self.monitor().lastSync == start.addingTimeInterval(10))
    }

    @Test("A running event counts as syncing until it ends")
    func syncing() {
        let monitor = monitor()
        let id = UUID()
        monitor.handle(event(.import, at: 0, ended: false, id: id))
        #expect(monitor.isSyncing)
        monitor.handle(event(.import, at: 3, id: id))
        #expect(!monitor.isSyncing)
    }

    @Test("No network is only a problem once it has lasted two minutes")
    func offlineWaits() {
        let monitor = monitor()
        monitor.handle(event(.export, at: 0, succeeded: false, failure: .offline))
        #expect(monitor.problem(now: start.addingTimeInterval(60)) == nil)
        monitor.handle(event(.export, at: 90, succeeded: false, failure: .offline))
        #expect(monitor.problem(now: start.addingTimeInterval(121)) == .offline)
        monitor.handle(event(.export, at: 130))
        #expect(monitor.problem(now: start.addingTimeInterval(400)) == nil)
    }

    @Test("Flight mode: no spinner for the open export, the hint after two minutes, gone with the network")
    func flightMode() {
        let monitor = monitor()
        monitor.handle(event(.export, at: 0, ended: false))
        #expect(monitor.isSyncing)
        monitor.setOnline(false, at: start)
        #expect(!monitor.isSyncing)
        #expect(monitor.problem(now: start.addingTimeInterval(60)) == nil)
        #expect(monitor.problem(now: start.addingTimeInterval(120)) == .offline)
        monitor.handle(event(.import, at: 150))
        #expect(monitor.lastSync == nil)
        monitor.setOnline(true)
        #expect(monitor.problem(now: start.addingTimeInterval(300)) == nil)
        #expect(monitor.isSyncing)
    }

    @Test("A full iCloud and a missing account show at once")
    func immediate() {
        let monitor = monitor()
        monitor.handle(event(.export, at: 0, succeeded: false, failure: .quotaExceeded))
        #expect(monitor.problem(now: start) == .quotaExceeded)
        monitor.handle(event(.export, at: 5, succeeded: false, failure: .notAuthenticated))
        #expect(monitor.problem(now: start) == .noAccount)
        monitor.handle(event(.export, at: 10))
        monitor.setAccount(.noAccount)
        #expect(monitor.problem(now: start) == .noAccount)
        monitor.setAccount(.available)
        #expect(monitor.problem(now: start) == nil)
    }

    @Test("A zone the mirror rebuilds itself is no problem")
    func transient() {
        let monitor = monitor()
        monitor.handle(event(.import, at: 0, succeeded: false, failure: .transient))
        #expect(monitor.problem(now: start.addingTimeInterval(3600)) == nil)
    }

    @Test("A save waits for the upload until an export starts after it")
    func pending() {
        let monitor = monitor()
        #expect(!monitor.hasPendingChanges)
        monitor.noteLocalSave(at: start)
        #expect(monitor.hasPendingChanges)
        monitor.handle(event(.export, at: 1, ended: false))  // started before the save
        #expect(monitor.hasPendingChanges)
        monitor.handle(event(.export, at: 10, ended: false))  // started after it
        #expect(!monitor.hasPendingChanges)
    }

    @Test("CloudKit errors are sorted, also inside partial failures and underlying errors")
    func errors() {
        func ck(_ code: CKError.Code, _ info: [String: Any] = [:]) -> NSError {
            NSError(domain: CKError.errorDomain, code: code.rawValue, userInfo: info)
        }
        #expect(SyncMonitor.failure(of: ck(.quotaExceeded)) == .quotaExceeded)
        #expect(SyncMonitor.failure(of: ck(.networkUnavailable)) == .offline)
        #expect(SyncMonitor.failure(of: ck(.notAuthenticated)) == .notAuthenticated)
        #expect(SyncMonitor.failure(of: ck(.zoneNotFound)) == .transient)
        let partial = ck(.partialFailure, [CKPartialErrorsByItemIDKey: ["a": ck(.zoneBusy), "b": ck(.quotaExceeded)]])
        #expect(SyncMonitor.failure(of: partial) == .quotaExceeded)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_400, userInfo: [NSUnderlyingErrorKey: ck(.networkFailure)])
        #expect(SyncMonitor.failure(of: wrapped) == .offline)
        #expect(SyncMonitor.failure(of: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) == .offline)
        #expect(SyncMonitor.failure(of: nil) == nil)
    }
}
