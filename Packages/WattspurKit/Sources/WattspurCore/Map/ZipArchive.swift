import Compression
import Foundation

/// A minimal reader for ZIP files, to open the KMZ files of roadcurvature.com (V-13, B-182)
/// without a third-party library and without starting `ditto`, which the sandbox does not
/// allow. It reads the central directory and extracts entries that are stored or deflated, one
/// entry at a time in a stream, so a large KML never has to fit into memory. No ZIP64, no
/// encryption; the checksum is not verified, a damaged stream fails while inflating.
public struct ZipArchive: Sendable {
    public enum Failure: Error, Equatable {
        case notAZipFile
        case unsupported
        case entryNotFound
        case damaged
        case tooLarge
    }

    public struct Entry: Sendable, Equatable {
        public var name: String
        public var compressedSize: Int
        public var uncompressedSize: Int
        var method: Int
        var localHeaderOffset: Int
    }

    public let entries: [Entry]
    private let data: Data

    /// Opens the archive at `url` (mapped, not copied).
    public init(url: URL) throws {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { throw Failure.notAZipFile }
        try self.init(data: data)
    }

    public init(data: Data) throws {
        self.data = data
        // The end-of-central-directory record is within the last 64 KB + 22 bytes.
        guard data.count >= 22 else { throw Failure.notAZipFile }
        let earliest = max(0, data.count - 22 - 65_535)
        var end: Int?
        var i = data.count - 22
        while i >= earliest {
            if Self.u32(data, i) == 0x0605_4b50 { end = i; break }
            i -= 1
        }
        guard let end else { throw Failure.notAZipFile }
        let count = Self.u16(data, end + 10)
        let size = Self.u32(data, end + 12)
        let offset = Self.u32(data, end + 16)
        guard count != 0xFFFF, size != 0xFFFF_FFFF, offset != 0xFFFF_FFFF else { throw Failure.unsupported }
        guard offset + size <= end else { throw Failure.damaged }

        var entries: [Entry] = []
        var position = offset
        for _ in 0..<count {
            guard position + 46 <= data.count, Self.u32(data, position) == 0x0201_4b50 else { throw Failure.damaged }
            let flags = Self.u16(data, position + 8)
            let method = Self.u16(data, position + 10)
            let compressed = Self.u32(data, position + 20)
            let uncompressed = Self.u32(data, position + 24)
            let nameLength = Self.u16(data, position + 28)
            let extraLength = Self.u16(data, position + 30)
            let commentLength = Self.u16(data, position + 32)
            let local = Self.u32(data, position + 42)
            guard position + 46 + nameLength <= data.count else { throw Failure.damaged }
            guard flags & 1 == 0 else { throw Failure.unsupported }
            let name = String(decoding: data[(position + 46)..<(position + 46 + nameLength)], as: UTF8.self)
            entries.append(Entry(name: name, compressedSize: compressed, uncompressedSize: uncompressed,
                                 method: method, localHeaderOffset: local))
            position += 46 + nameLength + extraLength + commentLength
        }
        self.entries = entries
    }

    /// The first entry whose name ends with `suffix` (compared in lower case).
    public func entry(withSuffix suffix: String) -> Entry? {
        entries.first { $0.name.lowercased().hasSuffix(suffix.lowercased()) }
    }

    /// Writes an entry into the file at `url` (created or replaced); stops with `tooLarge`
    /// when it would hold more than `limit` bytes, whatever the entry claims about itself.
    public func extract(_ entry: Entry, to url: URL, limit: Int) throws {
        guard entry.uncompressedSize <= limit else { throw Failure.tooLarge }
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count, Self.u32(data, header) == 0x0403_4b50 else { throw Failure.damaged }
        let start = header + 30 + Self.u16(data, header + 26) + Self.u16(data, header + 28)
        guard start + entry.compressedSize <= data.count else { throw Failure.damaged }
        let payload = data[start..<(start + entry.compressedSize)]

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        switch entry.method {
        case 0:
            guard payload.count <= limit else { throw Failure.tooLarge }
            try handle.write(contentsOf: payload)
        case 8:
            try Self.inflate(payload, into: handle, limit: limit)
        default:
            throw Failure.unsupported
        }
    }

    /// Raw deflate, which is what `COMPRESSION_ZLIB` reads.
    private static func inflate(_ input: Data, into handle: FileHandle, limit: Int) throws {
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw Failure.unsupported
        }
        defer { compression_stream_destroy(stream) }
        let capacity = 1 << 16
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        var written = 0
        try input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let bytes = raw.bindMemory(to: UInt8.self)
            stream.pointee.src_ptr = bytes.baseAddress ?? UnsafePointer(buffer)
            stream.pointee.src_size = bytes.count
            stream.pointee.dst_ptr = buffer
            stream.pointee.dst_size = capacity
            var status = COMPRESSION_STATUS_OK
            repeat {
                status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                guard status != COMPRESSION_STATUS_ERROR else { throw Failure.damaged }
                let produced = capacity - stream.pointee.dst_size
                if produced > 0 {
                    written += produced
                    guard written <= limit else { throw Failure.tooLarge }
                    try handle.write(contentsOf: Data(bytes: buffer, count: produced))
                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = capacity
                } else if status == COMPRESSION_STATUS_OK && stream.pointee.src_size == 0 {
                    // Input used up and nothing more to give: the stream is cut short.
                    throw Failure.damaged
                }
            } while status == COMPRESSION_STATUS_OK
        }
    }

    private static func u16(_ data: Data, _ offset: Int) -> Int {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return Int(data[base]) | Int(data[base + 1]) << 8
    }

    private static func u32(_ data: Data, _ offset: Int) -> Int {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return Int(data[base]) | Int(data[base + 1]) << 8 | Int(data[base + 2]) << 16 | Int(data[base + 3]) << 24
    }
}
