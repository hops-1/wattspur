import Foundation
import Testing
@testable import WattspurCore

/// How the share extension hands files to the app (B-361, S-45): copied, not loaded, and the type
/// from the first 2 KB only.
@Suite("Shared drop")
struct SharedDropTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "SharedDrop-\(UUID().uuidString)")

    private func cleanUp() { try? FileManager.default.removeItem(at: folder) }

    /// A GPX file of about `megabytes` MB: a header and many track points.
    private func bigGPX(_ name: String, megabytes: Int) throws -> URL {
        let url = folder.appending(path: "source/\(name)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: Data("<?xml version=\"1.0\"?>\n<gpx version=\"1.1\" creator=\"test\"><trk><trkseg>\n".utf8))
        let point = Data("<trkpt lat=\"49.80\" lon=\"8.60\"><time>2026-11-23T10:00:00Z</time></trkpt>\n".utf8)
        let chunk = Data(Array(repeating: point, count: 10_000).joined())
        for _ in 0..<(megabytes * 1_000_000 / chunk.count + 1) { try handle.write(contentsOf: chunk) }
        try handle.write(contentsOf: Data("</trkseg></trk></gpx>\n".utf8))
        return url
    }

    private func written(in base: URL) throws -> [URL] {
        let shares = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
        return try shares.flatMap { try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
    }

    @Test("Five large GPX files of one share are copied whole into one folder")
    func largeFiles() throws {
        defer { cleanUp() }
        let sources = try (1...5).map { try bigGPX("Tour \($0).gpx", megabytes: 5) }
        let base = folder.appending(path: "Shared Imports")
        let count = try SharedDrop.write(sources.map { .file($0, suggestedName: nil) }, into: base, id: "share")
        #expect(count == 5)
        let files = try written(in: base).sorted { $0.lastPathComponent < $1.lastPathComponent }
        #expect(files.map(\.lastPathComponent) == (1...5).map { "Tour \($0).gpx" })
        for (source, copy) in zip(sources, files) {
            let size = { (url: URL) in try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0 }
            #expect(try size(copy) == size(source))
            #expect(try size(copy) > 5_000_000)
            #expect(FileManager.default.contentsEqual(atPath: source.path(percentEncoded: false),
                                                     andPath: copy.path(percentEncoded: false)))
        }
        // The sources stay; the extension removes its own copies afterwards.
        #expect(sources.allSatisfy { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) })
        // No half-written folder is left.
        let entries = try FileManager.default.contentsOfDirectory(atPath: base.path(percentEncoded: false))
        #expect(entries == ["share"])
    }

    @Test("Only FIT and GPX go through, by content first; equal names get a number; data is written")
    func mixedShare() throws {
        defer { cleanUp() }
        let gpx = try bigGPX("ride.xml", megabytes: 1)
        let text = folder.appending(path: "source/notes.txt")
        try Data("just text".utf8).write(to: text)
        let fit = Data([14, 16, 0, 0, 0, 0, 0, 0] + Array(".FIT".utf8) + [0, 0])
        let items: [SharedDrop.Item] = [
            .file(gpx, suggestedName: "Abendrunde"),
            .file(text, suggestedName: nil),
            .data(fit, suggestedName: "Abendrunde"),
            .data(fit, suggestedName: "Abendrunde.fit"),
            .file(folder.appending(path: "source/missing.gpx"), suggestedName: nil),
        ]
        #expect(SharedDrop.fileExtension(of: items[0]) == "gpx")
        #expect(SharedDrop.fileExtension(of: items[1]) == nil)
        #expect(SharedDrop.fileExtension(of: items[4]) == nil)
        let base = folder.appending(path: "Shared Imports")
        #expect(try SharedDrop.write(items, into: base, id: "mixed") == 3)
        let names = try written(in: base).map(\.lastPathComponent).sorted()
        #expect(names == ["Abendrunde 2.fit", "Abendrunde.fit", "Abendrunde.gpx"])
    }

    @Test("A share without FIT or GPX writes nothing")
    func nothing() throws {
        defer { cleanUp() }
        let base = folder.appending(path: "Shared Imports")
        #expect(try SharedDrop.write([.data(Data("hello".utf8), suggestedName: "a.txt")], into: base) == 0)
        #expect(!FileManager.default.fileExists(atPath: base.path(percentEncoded: false)))
    }

    @Test("A failed copy leaves no half-written share behind")
    func failedCopy() throws {
        defer { cleanUp() }
        let gpx = try bigGPX("a.gpx", megabytes: 1)
        let base = folder.appending(path: "Shared Imports")
        // A share of the same id is already there: the final rename fails.
        try FileManager.default.createDirectory(at: base.appending(path: "taken"), withIntermediateDirectories: true)
        #expect(throws: (any Error).self) {
            try SharedDrop.write([.file(gpx, suggestedName: nil)], into: base, id: "taken")
        }
        let entries = try FileManager.default.contentsOfDirectory(atPath: base.path(percentEncoded: false))
        #expect(entries == ["taken"])
    }

    @Test("Only the start of a file is read for its type")
    func sniffing() throws {
        defer { cleanUp() }
        let gpx = try bigGPX("big.gpx", megabytes: 2)
        #expect(SharedDrop.head(of: gpx)?.count == SharedDrop.sniffLength)
        let small = folder.appending(path: "source/small.gpx")
        try Data("<gpx>".utf8).write(to: small)
        #expect(SharedDrop.head(of: small)?.count == 5)
        #expect(SharedDrop.head(of: folder.appending(path: "nothing")) == nil)
    }
}
