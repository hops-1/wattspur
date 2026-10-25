import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

@Suite("GPX description")
struct GPXDescriptionTests {
    let start = Date(timeIntervalSince1970: 1_792_325_533)
    var segments: [GPXWriter.Segment] { [.init(startDate: start, samples: [RideSample(time: 0, latitude: 49.1, longitude: 8.2)])] }

    private func text(_ description: String?) throws -> String {
        let data = GPXWriter.document(name: "Reinheim", segments: segments, description: description)
        let parser = XMLParser(data: data)
        #expect(parser.parse(), "the document stays well-formed XML")
        return try #require(String(data: data, encoding: .utf8))
    }

    @Test("The description is written into the metadata and the track, in the order GPX 1.1 requires")
    func writesDescription() throws {
        let xml = try text("Bike: Mein eBike")
        #expect(xml.contains("<desc>Bike: Mein eBike</desc>"))
        #expect(xml.components(separatedBy: "<desc>").count == 3)
        let metadataName = try #require(xml.range(of: "<name>Reinheim</name>"))
        let firstDesc = try #require(xml.range(of: "<desc>"))
        let time = try #require(xml.range(of: "<time>"))
        #expect(metadataName.upperBound <= firstDesc.lowerBound && firstDesc.upperBound <= time.lowerBound)
        // In the track the description comes after the name and before the type.
        let trk = try #require(xml.range(of: "<trk>"))
        let tail = String(xml[trk.upperBound...])
        let order = ["<name>", "<desc>", "<type>"].compactMap { tail.range(of: $0)?.lowerBound }
        #expect(order.count == 3 && order == order.sorted())
    }

    @Test("Special characters in the description are escaped")
    func escapes() throws {
        let xml = try text("Bike: Tom & Jerry <E-MTB>")
        #expect(xml.contains("<desc>Bike: Tom &amp; Jerry &lt;E-MTB&gt;</desc>"))
    }

    @Test("Without a description, or with an empty one, the file has none", arguments: [nil, ""] as [String?])
    func noDescription(description: String?) throws {
        #expect(!(try text(description)).contains("<desc>"))
    }

    @Test("A file without a description is the same as before")
    func unchanged() throws {
        let plain = GPXWriter.document(name: "Reinheim", segments: segments)
        let withNil = GPXWriter.document(name: "Reinheim", segments: segments, description: nil)
        #expect(plain == withNil)
    }
}
