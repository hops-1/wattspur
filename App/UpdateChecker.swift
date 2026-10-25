import AppKit
import Foundation
import Observation
import WattspurKit

/// Asks GitHub whether a newer Wattspur has been released (B-172).
///
/// It reads the public release list and sends nothing about the user or the library. At launch it
/// asks at most once a day, if the setting allows it; "Check for Updates…" asks right away. The
/// result is only a notice with a link to the release page; nothing is downloaded or installed.
@MainActor @Observable
final class UpdateChecker {
    /// The newer release the banner offers; `nil` if there is none or it was dismissed.
    private(set) var available: ReleaseInfo?
    private(set) var isChecking = false

    enum Outcome {
        case upToDate
        case newer(ReleaseInfo)
        case failed
    }

    static let endpoint = URL(string: "https://api.github.com/repos/hops-1/wattspur/releases/latest")!
    static let interval: TimeInterval = 24 * 3_600

    private let defaults: UserDefaults
    private let current: AppVersion?
    #if DEBUG
    /// `-WattspurFakeLatest 9.9.9`: pretends that this version is out, without asking GitHub, and
    /// remembers "Later" only until quit, so a test never hides a real notice.
    private var fakeDismissed: AppVersion?
    #endif

    init(defaults: UserDefaults = .standard, current: String = AppInfo.version) {
        self.defaults = defaults
        self.current = AppVersion(current)
    }

    /// On unless the user switched it off in Settings › General.
    var isEnabled: Bool { defaults.object(forKey: SettingsKey.updateCheckEnabled) as? Bool ?? true }

    private var dismissed: AppVersion? {
        defaults.string(forKey: SettingsKey.updateDismissedVersion).flatMap(AppVersion.init)
    }

    /// The release found by the last check, kept so the notice stays until it is updated or dismissed.
    private var remembered: ReleaseInfo? {
        guard let tag = defaults.string(forKey: SettingsKey.updateLatestTag),
              let link = defaults.string(forKey: SettingsKey.updateLatestLink) else { return nil }
        return ReleaseInfo(tag: tag, link: link)
    }

    private func notice(for release: ReleaseInfo?, ignoringDismissal: Bool = false) -> ReleaseInfo? {
        guard let release, let current else { return nil }
        return release.isNotice(for: current, dismissed: ignoringDismissal ? nil : dismissed) ? release : nil
    }

    /// At launch: shows what the last check found, and asks again after a day.
    func checkAtLaunch(now: Date = .now) async {
        #if DEBUG
        if let fake = fakeRelease {
            available = fake.isNotice(for: current ?? fake.version, dismissed: fakeDismissed) ? fake : nil
            return
        }
        // The demo library is for screenshots and must not talk to the network.
        if DemoMode.isOn { return }
        #endif
        guard isEnabled else { return }
        available = notice(for: remembered)
        if let last = defaults.object(forKey: SettingsKey.updateCheckedAt) as? Date,
           (0..<Self.interval).contains(now.timeIntervalSince(last)) { return }
        _ = await refresh(now: now)
    }

    /// "Check for Updates…": asks right away and tells the result in a dialog.
    func checkManually() async {
        guard !isChecking else { return }
        #if DEBUG
        if let fake = fakeRelease {
            show(.newer(fake))
            return
        }
        #endif
        show(await refresh(now: .now, ignoringDismissal: true))
    }

    /// "Later": the banner stays away until a version newer than this one comes out.
    func dismiss() {
        guard let release = available else { return }
        #if DEBUG
        if fakeRelease != nil { fakeDismissed = release.version }
        else { defaults.set(release.version.description, forKey: SettingsKey.updateDismissedVersion) }
        #else
        defaults.set(release.version.description, forKey: SettingsKey.updateDismissedVersion)
        #endif
        available = nil
    }

    func open(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(release.url)
    }

    // MARK: - Asking GitHub

    private func refresh(now: Date, ignoringDismissal: Bool = false) async -> Outcome {
        isChecking = true
        defer { isChecking = false }
        guard let release = await Self.latestRelease() else { return .failed }
        defaults.set(now, forKey: SettingsKey.updateCheckedAt)
        defaults.set(release.version.description, forKey: SettingsKey.updateLatestTag)
        defaults.set(release.url.absoluteString, forKey: SettingsKey.updateLatestLink)
        if ignoringDismissal { defaults.removeObject(forKey: SettingsKey.updateDismissedVersion) }
        available = notice(for: release, ignoringDismissal: ignoringDismissal)
        return available.map(Outcome.newer) ?? .upToDate
    }

    /// One short request; `nil` on no connection, a slow or odd answer, or a rate limit.
    private static func latestRelease() async -> ReleaseInfo? {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Wattspur/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count < 1_000_000
        else { return nil }
        return ReleaseInfo.parse(data)
    }

    // MARK: - The dialog of the manual check

    private func show(_ outcome: Outcome) {
        let alert = NSAlert()
        switch outcome {
        case .upToDate:
            alert.messageText = String(localized: "Wattspur is up to date")
            alert.informativeText = String(localized: "You have the newest version, \(AppInfo.version).")
        case .failed:
            alert.messageText = String(localized: "Could not check for updates")
            alert.informativeText = String(localized: "Wattspur could not reach GitHub. Check your internet connection and try again.")
        case .newer(let release):
            alert.messageText = String(localized: "Wattspur \(release.version.description) is available")
            alert.informativeText = String(localized: "You have version \(AppInfo.version). The new version is on GitHub; replace the app in Applications with it. Your rides stay as they are.")
            alert.addButton(withTitle: String(localized: "View on GitHub"))
            alert.addButton(withTitle: String(localized: "Not Now"))
            if alert.runModal() == .alertFirstButtonReturn { open(release) }
            return
        }
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    #if DEBUG
    private var fakeRelease: ReleaseInfo? {
        defaults.string(forKey: "WattspurFakeLatest").flatMap {
            ReleaseInfo(tag: $0, link: ReleaseInfo.releasesPrefix + "releases/latest")
        }
    }
    #endif
}
