import Foundation

extension CurvyRoads {
    /// Reads the roads from a KMZ (a ZIP with the KML inside) or a KML file of roadcurvature.com.
    /// The KML is unpacked into a temporary file and parsed from there as a stream, so even a
    /// state of 250 MB and more never sits in memory as a whole.
    public static func read(from url: URL, limits: Limits = Limits()) throws -> [CurvyRoad] {
        let isKML = url.pathExtension.lowercased() == "kml"
        if isKML { return try parse(kmlAt: url, limits: limits) }
        let archive: ZipArchive
        do { archive = try ZipArchive(url: url) } catch { throw Failure.notCurvatureData }
        guard let entry = archive.entry(withSuffix: ".kml") else { throw Failure.notCurvatureData }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("wattspur-\(UUID().uuidString).kml")
        defer { try? FileManager.default.removeItem(at: temporary) }
        do {
            try archive.extract(entry, to: temporary, limit: limits.uncompressedBytes)
        } catch ZipArchive.Failure.tooLarge {
            throw Failure.tooLarge
        } catch {
            throw Failure.damaged
        }
        return try parse(kmlAt: temporary, limits: limits)
    }

    /// The roads in a KML file; `notCurvatureData` if there is none with a curvature.
    static func parse(kmlAt url: URL, limits: Limits) throws -> [CurvyRoad] {
        guard let stream = InputStream(url: url) else { throw Failure.damaged }
        let parser = XMLParser(stream: stream)
        let reader = Reader(limits: limits)
        parser.delegate = reader
        // KML files of roadcurvature carry no DTD; never load one from outside.
        parser.shouldResolveExternalEntities = false
        let finished = parser.parse()
        if let failure = reader.failure { throw failure }
        guard finished else { throw Failure.notCurvatureData }
        guard !reader.roads.isEmpty || reader.sawRoad else { throw Failure.notCurvatureData }
        return reader.roads
    }

    private final class Reader: NSObject, XMLParserDelegate {
        let limits: Limits
        var roads: [CurvyRoad] = []
        var points = 0
        /// A placemark with a curvature was there, even if it was left out (a motorway).
        var sawRoad = false
        var failure: Failure?

        private var inPlacemark = false
        private var current: String?
        private var name = ""
        private var details = ""
        private var coordinates = ""

        init(limits: Limits) { self.limits = limits }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "Placemark":
                inPlacemark = true
                name = ""; details = ""; coordinates = ""
            case "name", "description", "coordinates":
                if inPlacemark { current = elementName }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { append(string) }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { append(String(decoding: CDATABlock, as: UTF8.self)) }

        private func append(_ text: String) {
            switch current {
            case "name": name += text
            case "description": details += text
            case "coordinates": coordinates += text
            default: break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "name", "description", "coordinates":
                current = nil
            case "Placemark":
                inPlacemark = false
                finishRoad(parser)
            default:
                break
            }
        }

        private func finishRoad(_ parser: XMLParser) {
            guard let curvature = Self.number(after: "Curvature:", in: details) else { return }
            sawRoad = true
            if let type = Self.word(after: "Type:", in: details), CurvyRoads.excludedTypes.contains(type) { return }
            var values: [Float] = []
            for pair in coordinates.split(whereSeparator: \.isWhitespace) {
                // "longitude,latitude", the order of KML.
                let parts = pair.split(separator: ",")
                guard parts.count >= 2, let longitude = Double(parts[0]), let latitude = Double(parts[1]),
                      abs(latitude) <= 90, abs(longitude) <= 180 else { continue }
                values.append(Float(latitude))
                values.append(Float(longitude))
            }
            guard values.count >= 4 else { return }
            points += values.count / 2
            guard roads.count < limits.roads, points <= limits.points else {
                failure = .tooLarge
                parser.abortParsing()
                return
            }
            let length = (Self.number(after: "Distance:", in: details) ?? 0) * 1000
            roads.append(CurvyRoad(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                   curvature: curvature, length: length, coordinates: values))
        }

        /// The number after a label in the description ("Curvature: 8878.77<br/>").
        private static func number(after label: String, in text: String) -> Double? {
            guard let range = text.range(of: label) else { return nil }
            let digits = text[range.upperBound...].drop { $0 == " " }.prefix { $0.isNumber || $0 == "." }
            return Double(digits)
        }

        private static func word(after label: String, in text: String) -> String? {
            guard let range = text.range(of: label) else { return nil }
            let word = text[range.upperBound...].drop { $0 == " " }.prefix { $0.isLetter || $0 == "_" }
            return word.isEmpty ? nil : String(word)
        }
    }
}
