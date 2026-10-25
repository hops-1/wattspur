import Foundation

public enum FITDecodingError: Error, Equatable, Sendable {
    case fileTooShort
    case invalidHeader
    case notAFITFile
    case truncated(offset: Int)
    case undefinedLocalMessage(localType: UInt8, offset: Int)
    case checksumMismatch(expected: UInt16, actual: UInt16)
}

/// Decodes the binary FIT container format into raw messages.
///
/// The decoder knows nothing about the meaning of messages; it only handles
/// the container: file header, definition and data messages, compressed
/// timestamp headers, developer fields (skipped) and the CRC.
public struct FITDecoder: Sendable {
    /// When `true` (default), a wrong file checksum is an error.
    public var verifyChecksum: Bool

    public init(verifyChecksum: Bool = true) {
        self.verifyChecksum = verifyChecksum
    }

    public func decode(_ data: Data) throws(FITDecodingError) -> FITFile {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { throw .fileTooShort }

        let headerSize = Int(bytes[0])
        guard headerSize == 12 || headerSize == 14, bytes.count >= headerSize else { throw .invalidHeader }
        guard bytes[8] == 0x2E, bytes[9] == 0x46, bytes[10] == 0x49, bytes[11] == 0x54 else { throw .notAFITFile }

        let protocolVersion = bytes[1]
        let profileVersion = UInt16(bytes[2]) | UInt16(bytes[3]) << 8
        let dataSize = Int(UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24)
        let dataEnd = headerSize + dataSize
        guard dataEnd + 2 <= bytes.count else { throw .truncated(offset: bytes.count) }

        if verifyChecksum {
            let stored = UInt16(bytes[dataEnd]) | UInt16(bytes[dataEnd + 1]) << 8
            // A stored CRC of 0 means "not computed" according to the FIT spec.
            if stored != 0 {
                let actual = FITCRC.compute(bytes[0..<dataEnd])
                guard actual == stored else { throw .checksumMismatch(expected: stored, actual: actual) }
            }
        }

        var reader = ByteReader(bytes: bytes, offset: headerSize, end: dataEnd)
        var definitions: [UInt8: Definition] = [:]
        var messages: [FITMessage] = []
        var lastTimestamp: UInt32 = 0

        while reader.offset < dataEnd {
            let recordStart = reader.offset
            let header = try reader.readByte()

            if header & 0x80 != 0 {
                // Compressed timestamp header: local type in bits 5–6, time offset in bits 0–4.
                let localType = (header >> 5) & 0x03
                guard let definition = definitions[localType] else {
                    throw .undefinedLocalMessage(localType: localType, offset: recordStart)
                }
                var message = try readData(definition, from: &reader)
                let offset = UInt32(header & 0x1F)
                // Wrapping: a hostile file may start near the end of the 32-bit range.
                var timestamp = (lastTimestamp & ~0x1F) &+ offset
                if offset < (lastTimestamp & 0x1F) { timestamp = timestamp &+ 0x20 }
                lastTimestamp = timestamp
                message.fields[FITProfile.timestampField] = .unsigned(UInt64(timestamp))
                messages.append(message)
                continue
            }

            let localType = header & 0x0F
            if header & 0x40 != 0 {
                definitions[localType] = try readDefinition(from: &reader, hasDeveloperFields: header & 0x20 != 0)
            } else {
                guard let definition = definitions[localType] else {
                    throw .undefinedLocalMessage(localType: localType, offset: recordStart)
                }
                let message = try readData(definition, from: &reader)
                if case .unsigned(let t)? = message[FITProfile.timestampField] {
                    lastTimestamp = UInt32(truncatingIfNeeded: t)
                }
                messages.append(message)
            }
        }

        return FITFile(protocolVersion: protocolVersion, profileVersion: profileVersion, messages: messages)
    }

    // MARK: - Definitions

    private struct FieldDefinition {
        let number: UInt8
        let size: Int
        let baseType: UInt8
    }

    private struct Definition {
        let bigEndian: Bool
        let globalNumber: UInt16
        let fields: [FieldDefinition]
        /// Developer fields are skipped; only their total size matters.
        let developerDataSize: Int
    }

    private func readDefinition(from reader: inout ByteReader, hasDeveloperFields: Bool) throws(FITDecodingError) -> Definition {
        _ = try reader.readByte() // reserved
        let bigEndian = try reader.readByte() == 1
        let globalNumber = try reader.readUInt16(bigEndian: bigEndian)
        let fieldCount = Int(try reader.readByte())
        var fields: [FieldDefinition] = []
        fields.reserveCapacity(fieldCount)
        for _ in 0..<fieldCount {
            let number = try reader.readByte()
            let size = Int(try reader.readByte())
            let baseType = try reader.readByte() & 0x1F
            fields.append(FieldDefinition(number: number, size: size, baseType: baseType))
        }
        var developerDataSize = 0
        if hasDeveloperFields {
            let count = Int(try reader.readByte())
            for _ in 0..<count {
                _ = try reader.readByte()            // field number
                developerDataSize += Int(try reader.readByte())
                _ = try reader.readByte()            // developer data index
            }
        }
        return Definition(bigEndian: bigEndian, globalNumber: globalNumber, fields: fields, developerDataSize: developerDataSize)
    }

    // MARK: - Data messages

    private func readData(_ definition: Definition, from reader: inout ByteReader) throws(FITDecodingError) -> FITMessage {
        var fields: [UInt8: FITValue] = [:]
        for field in definition.fields {
            let raw = try reader.readBytes(field.size)
            if let value = FITBaseType.decode(raw, baseType: field.baseType, bigEndian: definition.bigEndian) {
                fields[field.number] = value
            }
        }
        try reader.skip(definition.developerDataSize)
        return FITMessage(globalNumber: definition.globalNumber, fields: fields)
    }
}

// MARK: - Byte reader

struct ByteReader {
    let bytes: [UInt8]
    var offset: Int
    let end: Int

    init(bytes: [UInt8], offset: Int, end: Int) {
        self.bytes = bytes
        self.offset = offset
        self.end = end
    }

    mutating func readByte() throws(FITDecodingError) -> UInt8 {
        guard offset < end else { throw .truncated(offset: offset) }
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func readBytes(_ count: Int) throws(FITDecodingError) -> ArraySlice<UInt8> {
        guard count >= 0, offset + count <= end else { throw .truncated(offset: offset) }
        defer { offset += count }
        return bytes[offset..<offset + count]
    }

    mutating func readUInt16(bigEndian: Bool) throws(FITDecodingError) -> UInt16 {
        let b = try readBytes(2)
        let lo = UInt16(b[b.startIndex]), hi = UInt16(b[b.startIndex + 1])
        return bigEndian ? (lo << 8 | hi) : (hi << 8 | lo)
    }

    mutating func skip(_ count: Int) throws(FITDecodingError) {
        _ = try readBytes(count)
    }
}
