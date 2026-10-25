import Foundation

/// A version like "1.6.1" or "v1.6.1", compared by numbers (1.10.0 is newer than 1.9.0).
/// Anything after the numbers ("-beta", build numbers) is ignored.
public struct AppVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let parts: [Int]

    /// `nil` unless the text starts with one to four numbers separated by dots.
    public init?(_ text: String) {
        var text = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if text.first == "v" || text.first == "V" { text = text.dropFirst() }
        let numbers = text.prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
        let parts = numbers.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (1...4).contains(parts.count), !parts.contains(nil) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    public static func < (a: Self, b: Self) -> Bool {
        let count = max(a.parts.count, b.parts.count)
        for i in 0..<count {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    /// 1.6 and 1.6.0 are the same version.
    public static func == (a: Self, b: Self) -> Bool { !(a < b) && !(b < a) }

    public func hash(into hasher: inout Hasher) {
        var parts = parts
        while parts.count > 1, parts.last == 0 { parts.removeLast() }
        hasher.combine(parts)
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }
}

/// The newest release on GitHub, as far as the app needs it for the update notice.
public struct ReleaseInfo: Sendable, Equatable {
    public let version: AppVersion
    /// The release page, always on github.com/hops-1/wattspur.
    public let url: URL

    public init(version: AppVersion, url: URL) {
        self.version = version
        self.url = url
    }

    /// Where the releases live; the notice only ever opens a page below this.
    public static let releasesPrefix = "https://github.com/hops-1/wattspur/"

    /// A release from its tag ("v1.6.2") and page; `nil` unless the tag is a version and the page
    /// is an https link below `releasesPrefix`. Also used for a release kept from the last check.
    public init?(tag: String, link: String) {
        guard let version = AppVersion(tag), link.hasPrefix(Self.releasesPrefix),
              let url = URL(string: link), url.scheme == "https"
        else { return nil }
        self.init(version: version, url: url)
    }

    private struct Response: Decodable {
        let tag_name: String?
        let html_url: String?
        let draft: Bool?
        let prerelease: Bool?
    }

    /// Reads the answer of `GET /repos/hops-1/wattspur/releases/latest`. `nil` for anything
    /// that is not a published release with a version and a link on this project's page.
    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.draft != true, response.prerelease != true,
              let tag = response.tag_name, let link = response.html_url
        else { return nil }
        return ReleaseInfo(tag: tag, link: link)
    }

    /// Whether this release is newer than the running app and has not been dismissed.
    public func isNotice(for current: AppVersion, dismissed: AppVersion?) -> Bool {
        version > current && (dismissed.map { version > $0 } ?? true)
    }
}
