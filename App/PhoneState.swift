import Foundation
import Observation
import SwiftData
import WattspurKit

/// Keeps the state for the iPhone up to date (B-208): when switched on in the settings, Wattspur
/// writes the rides into the subfolder `iPhone` of the import folder after every change to the
/// library (import, trash, merge, bike, name). Changes are bundled: the first write comes a few
/// seconds after a change, then at most one a minute, because iCloud uploads every write.
@MainActor
@Observable
final class PhoneState {
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: SettingsKey.phoneStateEnabled)
            if isEnabled { scheduleWrite() } else { pending?.cancel(); pending = nil }
        }
    }
    private(set) var lastWritten: Date?
    private(set) var lastRides = 0
    /// Why the last write failed, e.g. no import folder.
    private(set) var problem: String?

    /// Seconds between a change and the write.
    static let delay: Duration = .seconds(5)
    /// Seconds between two writes at least.
    static let minimumInterval: TimeInterval = 60

    private let context: ModelContext
    private let watcher: FolderWatcher
    private var pending: Task<Void, Never>?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init(context: ModelContext, watcher: FolderWatcher) {
        self.context = context
        self.watcher = watcher
        isEnabled = UserDefaults.standard.bool(forKey: SettingsKey.phoneStateEnabled)
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleWrite() }
        }
        // The library may have changed while Wattspur was closed (or in an older version).
        if isEnabled { scheduleWrite() }
    }

    /// Writes soon, or once the minute since the last write is over.
    func scheduleWrite() {
        guard isEnabled, pending == nil else { return }
        let sinceLast = lastWritten.map { Date.now.timeIntervalSince($0) } ?? .infinity
        let wait = max(Self.delay, .seconds(Self.minimumInterval - sinceLast))
        pending = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.pending = nil
            self?.writeNow()
        }
    }

    func writeNow() {
        guard isEnabled else { return }
        guard let folder = watcher.folderURL else {
            problem = String(localized: "Choose an import folder and switch watching on.")
            return
        }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        do {
            let result = try PhoneStateWriter(context: context).write(to: folder, generator: Self.generator)
            lastWritten = .now
            lastRides = result.rides
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }

    /// “Wattspur 1.9 (Mac)”, stored in the state so the iPhone can tell where it came from.
    static var generator: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return "Wattspur \(version) (Mac)"
    }
}
