import Foundation

/// Version information shown in the About window and in diagnostics.
enum AppInfo {
    static var version: String { info("CFBundleShortVersionString") ?? "–" }
    static var build: String { info("CFBundleVersion") ?? "–" }
    /// Short git commit of the build; "-dirty" means there were uncommitted changes.
    static var commit: String { info("WattspurGitCommit") ?? "–" }
    static var copyright: String { info("NSHumanReadableCopyright") ?? "" }

    /// "0.1.0 (1, 4fd5f9b)"
    static var fullVersion: String { "\(version) (\(build), \(commit))" }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
