import Foundation
import Testing
@testable import WattspurCore

@Suite("Update notice: versions and the GitHub answer")
struct AppVersionTests {
    private func v(_ text: String) -> AppVersion { AppVersion(text)! }

    @Test("Versions are compared by numbers, not as text")
    func comparison() {
        #expect(v("1.6.1") < v("1.6.2"))
        #expect(v("1.9.0") < v("1.10.0"))
        #expect(v("1.6") == v("1.6.0"))
        #expect(v("2.0") > v("1.99.99"))
        #expect(!(v("1.6.1") < v("1.6.1")))
    }

    @Test("A v prefix, spaces and a suffix are tolerated")
    func tolerant() {
        #expect(v("v1.6.1") == v("1.6.1"))
        #expect(v(" V1.6.1\n") == v("1.6.1"))
        #expect(v("1.7.0-beta.1") == v("1.7.0"))
        #expect(v("1.6.1 (252)") == v("1.6.1"))
        #expect(v("1.6.1").description == "1.6.1")
        #expect(Set([v("1.6"), v("1.6.0")]).count == 1)
    }

    @Test("Anything that is not a version is rejected")
    func invalid() {
        for text in ["", "v", "latest", "1..2", "1.x", ".1", "1.2.3.4.5", "٣.١"] {
            #expect(AppVersion(text) == nil, "\(text)")
        }
    }

    private func json(tag: String? = "v1.6.2", url: String? = "https://github.com/hops-1/wattspur/releases/tag/v1.6.2",
                      draft: Bool? = false, prerelease: Bool? = false) -> Data {
        var object: [String: Any] = ["name": "Wattspur", "assets": []]
        if let tag { object["tag_name"] = tag }
        if let url { object["html_url"] = url }
        if let draft { object["draft"] = draft }
        if let prerelease { object["prerelease"] = prerelease }
        return try! JSONSerialization.data(withJSONObject: object)
    }

    @Test("A published release gives its version and page")
    func parsesRelease() throws {
        let info = try #require(ReleaseInfo.parse(json()))
        #expect(info.version == v("1.6.2"))
        #expect(info.url.absoluteString == "https://github.com/hops-1/wattspur/releases/tag/v1.6.2")
    }

    @Test("Drafts, pre-releases and incomplete answers give nothing")
    func rejectsOthers() {
        #expect(ReleaseInfo.parse(json(draft: true)) == nil)
        #expect(ReleaseInfo.parse(json(prerelease: true)) == nil)
        #expect(ReleaseInfo.parse(json(tag: nil)) == nil)
        #expect(ReleaseInfo.parse(json(tag: "nightly")) == nil)
        #expect(ReleaseInfo.parse(json(url: nil)) == nil)
        #expect(ReleaseInfo.parse(Data("not json".utf8)) == nil)
        #expect(ReleaseInfo.parse(Data("[]".utf8)) == nil)
    }

    @Test("Only links on this project's GitHub page are accepted")
    func rejectsForeignLinks() {
        #expect(ReleaseInfo.parse(json(url: "https://evil.example/hops-1/wattspur/")) == nil)
        #expect(ReleaseInfo.parse(json(url: "http://github.com/hops-1/wattspur/releases")) == nil)
        #expect(ReleaseInfo.parse(json(url: "https://github.com/hops-1/wattspur.evil.example/")) == nil)
        #expect(ReleaseInfo.parse(json(url: "https://github.com/someone-else/wattspur/releases")) == nil)
    }

    @Test("The notice shows for a newer version, unless that one was dismissed")
    func notice() throws {
        let release = try #require(ReleaseInfo.parse(json()))
        #expect(release.isNotice(for: v("1.6.1"), dismissed: nil))
        #expect(!release.isNotice(for: v("1.6.2"), dismissed: nil))
        #expect(!release.isNotice(for: v("1.7.0"), dismissed: nil))
        #expect(!release.isNotice(for: v("1.6.1"), dismissed: v("1.6.2")))
        #expect(release.isNotice(for: v("1.6.1"), dismissed: v("1.6.1")))
    }
}
