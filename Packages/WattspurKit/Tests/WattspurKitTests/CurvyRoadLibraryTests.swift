import Foundation
import Testing
@testable import WattspurCore
@testable import WattspurKit

@Suite("Imported curvy roads")
struct CurvyRoadLibraryTests {
    private func kml(roads: Int) -> Data {
        let placemarks = (0..<roads).map { i in
            """
            <Placemark><name>Straße \(i)</name>
            <description><![CDATA[Curvature: \(400 + i * 700)<br/>Distance: 3.2 km<br/>Type: tertiary<br/>]]></description>
            <LineString><coordinates>8.\(i)0,49.\(i)0 8.\(i)1,49.\(i)1 8.\(i)2,49.\(i)3</coordinates></LineString></Placemark>
            """
        }.joined()
        return Data("<?xml version=\"1.0\"?><kml><Document><Folder>\(placemarks)</Folder></Document></kml>".utf8)
    }

    /// A folder of its own with a file inside.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("curvy-lib-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("An import keeps the region; another with the same state replaces it")
    func installAndReplace() throws {
        let work = try folder()
        let library = CurvyRoadLibrary(directory: work.appendingPathComponent("store"))
        #expect(library.regions().isEmpty && library.roads().isEmpty)

        let first = work.appendingPathComponent("hessen.c_1000.kml")
        try kml(roads: 2).write(to: first)
        let info = try library.install(from: first, now: Date(timeIntervalSince1970: 1000))
        #expect(info.id == "hessen" && info.name == "Hessen" && info.roadCount == 2)
        #expect(library.regions() == [info])
        #expect(library.roads().count == 2)

        // The bigger file of the same state replaces it instead of adding to it.
        let second = work.appendingPathComponent("hessen.c_300.kml")
        try kml(roads: 5).write(to: second)
        try library.install(from: second)
        #expect(library.regions().map(\.roadCount) == [5])
        #expect(library.roads().count == 5)

        let other = work.appendingPathComponent("bayern.c_300.kml")
        try kml(roads: 1).write(to: other)
        try library.install(from: other)
        #expect(library.regions().map(\.name) == ["Bayern", "Hessen"])
        #expect(library.roads().count == 6)

        library.remove(id: "hessen")
        #expect(library.regions().map(\.id) == ["bayern"])
    }

    @Test("A file that is no curvature data leaves the library as it was")
    func refused() throws {
        let work = try folder()
        let library = CurvyRoadLibrary(directory: work.appendingPathComponent("store"))
        let url = work.appendingPathComponent("route.kml")
        try Data("<kml><Document/></kml>".utf8).write(to: url)
        #expect(throws: CurvyRoads.Failure.notCurvatureData) { try library.install(from: url) }
        #expect(library.regions().isEmpty)
    }

    @Test("A damaged region file is skipped, the others stay")
    func damagedFile() throws {
        let work = try folder()
        let library = CurvyRoadLibrary(directory: work.appendingPathComponent("store"))
        let url = work.appendingPathComponent("hessen.kml")
        try kml(roads: 2).write(to: url)
        try library.install(from: url)
        try Data("garbage".utf8).write(to: library.directory.appendingPathComponent("broken.curvyroads"))
        #expect(library.regions().map(\.id) == ["hessen"])
        #expect(library.roads().count == 2)
    }

    @Test("The region name comes from the file name")
    func names() {
        #expect(CurvyRoadLibrary.regionID(forFileNamed: "hessen.c_300.kmz") == "hessen")
        #expect(CurvyRoadLibrary.regionID(forFileNamed: "Nordrhein-Westfalen.c_1000.kmz") == "nordrhein-westfalen")
        #expect(CurvyRoadLibrary.regionID(forFileNamed: "Sachsen Anhalt.kmz") == "sachsen-anhalt")
        #expect(CurvyRoadLibrary.regionID(forFileNamed: "../x.kmz") == "x")
        #expect(CurvyRoadLibrary.regionID(forFileNamed: ".kmz") == "kmz")
        #expect(CurvyRoadLibrary.regionID(forFileNamed: "") == "region")
        #expect(CurvyRoadLibrary.regionName(forID: "nordrhein-westfalen") == "Nordrhein Westfalen")
    }
}
