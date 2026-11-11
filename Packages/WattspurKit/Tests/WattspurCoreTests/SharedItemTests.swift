import Foundation
import Testing
@testable import WattspurCore

/// What the share extension makes of shared data and links (B-301). Invented content only.
@Suite("Shared items")
struct SharedItemTests {
    /// The 14-byte header of a FIT file, then a little data.
    private let fit = Data([14, 0x10, 0, 0, 0, 0, 0, 0] + Array(".FIT".utf8) + [0, 0, 1, 2, 3])
    private let gpx = Data("<?xml version=\"1.0\"?>\n<!-- exported -->\n<gpx version=\"1.1\" creator=\"Test\"><trk/></gpx>".utf8)

    @Test("The type comes from the content first, then from the name")
    func fileType() {
        #expect(SharedItem.fileExtension(of: fit, suggestedName: nil) == "fit")
        #expect(SharedItem.fileExtension(of: fit, suggestedName: "Fahrt.dat") == "fit")
        #expect(SharedItem.fileExtension(of: gpx, suggestedName: nil) == "gpx")
        #expect(SharedItem.fileExtension(of: gpx, suggestedName: "track.xml") == "gpx")
        #expect(SharedItem.fileExtension(of: Data("<gpxdata:x xmlns:gpxdata=\"u\"/>".utf8), suggestedName: nil) == nil)
        #expect(SharedItem.fileExtension(of: Data("hallo".utf8), suggestedName: "Notiz.txt") == nil)
        #expect(SharedItem.fileExtension(of: Data("broken".utf8), suggestedName: "Tour.GPX") == "gpx")
        #expect(SharedItem.fileExtension(of: Data(), suggestedName: nil) == nil)
    }

    @Test("File names keep the suggested name, get the right extension and never become a path")
    func fileNames() {
        let date = Date(timeIntervalSince1970: 1_798_761_600) // 2027-01-01 00:00 UTC
        #expect(SharedItem.fileName(suggestedName: "Morgenrunde.xml", fileExtension: "gpx") == "Morgenrunde.gpx")
        #expect(SharedItem.fileName(suggestedName: "../../Fahrt.fit", fileExtension: "fit") == "Fahrt.fit")
        #expect(SharedItem.fileName(suggestedName: "a:b", fileExtension: "gpx") == "a-b.gpx")
        #expect(SharedItem.fileName(suggestedName: ".hidden", fileExtension: "gpx") == "hidden.gpx")
        let unnamed = SharedItem.fileName(suggestedName: nil, fileExtension: "fit", date: date)
        #expect(unnamed.hasPrefix("Shared 20"))
        #expect(unnamed.hasSuffix(".fit"))
        #expect(!unnamed.contains("/") && !unnamed.contains(":"))
    }

    @Test("Links: komoot, Strava and Garmin are told apart; files and other schemes are no links")
    func links() throws {
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://www.komoot.com/de-de/tour/123456"))) == .komoot)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://komoot.de/tour/1"))) == .komoot)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://www.strava.com/activities/42"))) == .strava)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://strava.app.link/abc"))) == .strava)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://connect.garmin.com/modern/activity/7"))) == .garmin)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://example.org/x"))) == .other)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "https://notkomoot.com/tour/1"))) == .other)
        #expect(SharedItem.linkSource(of: URL(filePath: "/tmp/Tour.gpx")) == nil)
        #expect(SharedItem.linkSource(of: try #require(URL(string: "mailto:a@example.org"))) == nil)
    }

    @Test("A link is found in shared text")
    func linkInText() {
        let url = SharedItem.link(in: "Schau dir meine Tour auf komoot an: https://www.komoot.com/tour/99 Viel Spaß!")
        #expect(url?.absoluteString == "https://www.komoot.com/tour/99")
        #expect(SharedItem.link(in: "Keine Adresse hier") == nil)
    }
}
