import Foundation

/// Version information shown in the About window, in diagnostics and at the bottom of the
/// iPhone overview. Read from the app's Info.plist; the commit is written there at build time
/// by the pre-build script in `project.yml` (via `Config/Info.plist`).
public enum AppInfo {
    public static var version: String { info("CFBundleShortVersionString") ?? "–" }
    public static var build: String { info("CFBundleVersion") ?? "–" }
    /// Short git commit of the build; "-dirty" means there were uncommitted changes.
    public static var commit: String { info("WattspurGitCommit") ?? "–" }
    public static var copyright: String { info("NSHumanReadableCopyright") ?? "" }

    /// "0.1.0 (1, 4fd5f9b)"
    public static var fullVersion: String { "\(version) (\(build), \(commit))" }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
