import Foundation

/// Makes a FIT export safe to share as the sample ride (V-05, NFR-12).
///
/// The file is patched in place, so its structure, the sensor data and the Bosch
/// totals stay exactly as they were; only these change:
/// - every position is moved by a fixed offset,
/// - positions within `trimDistance` of the start and the end are removed, so
///   neither the start nor the finish (often the front door) can be found,
/// - positions in summary messages (session, lap, bounding boxes) are removed,
/// - all times move by whole weeks (weekday and time of day stay),
/// - serial numbers and developer fields are cleared,
/// - the file checksum is recomputed.
///
/// Keep the offset you use to yourself: anyone who knows it can move the route back.
public struct FITAnonymizer: Sendable {
    /// Degrees added to every latitude and longitude.
    public var latitudeOffset: Double
    public var longitudeOffset: Double
    /// Metres of route without positions at the start and at the end.
    public var trimDistance: Double
    /// Whole weeks added to every time (negative = earlier).
    public var weeks: Int

    public init(latitudeOffset: Double, longitudeOffset: Double, trimDistance: Double = 500, weeks: Int = 0) {
        self.latitudeOffset = latitudeOffset
        self.longitudeOffset = longitudeOffset
        self.trimDistance = trimDistance
        self.weeks = weeks
    }

    public func anonymize(_ data: Data) throws(FITDecodingError) -> Data {
        // Validates the container (header, definitions, checksum) before touching it.
        _ = try FITDecoder().decode(data)

        var bytes = [UInt8](data)
        let messages = try Self.layout(of: bytes)

        let distances = messages.lazy
            .filter { $0.globalNumber == FITProfile.Message.record }
            .compactMap { $0.unsigned(FITProfile.Record.distance, in: bytes) }
        let totalDistance = Double(distances.max() ?? 0) / 100
        let latShift = Self.semicircles(fromDegrees: latitudeOffset)
        let longShift = Self.semicircles(fromDegrees: longitudeOffset)
        // A multiple of 32 s, so compressed timestamp headers stay valid.
        let timeShift = Int64(weeks) * 7 * 86_400

        // Bosch writes GPS and sensor values as separate records; a GPS record has
        // no distance of its own, so it takes the last one measured before it.
        var lastDistance: Double?
        for message in messages {
            if message.globalNumber == FITProfile.Message.record,
               let centimetres = message.unsigned(FITProfile.Record.distance, in: bytes) {
                lastDistance = Double(centimetres) / 100
            }
            for field in message.fields {
                switch (message.globalNumber, field.number, field.baseType) {
                case (FITProfile.Message.record, FITProfile.Record.positionLat, Self.sint32),
                     (FITProfile.Message.record, FITProfile.Record.positionLong, Self.sint32):
                    let shift = field.number == FITProfile.Record.positionLat ? latShift : longShift
                    let keep = lastDistance.map { $0 >= trimDistance && $0 <= totalDistance - trimDistance } ?? false
                    let value = field.signed(in: bytes)
                    if keep, value != Self.invalidSint32, let moved = Self.clampedSemicircles(Int64(value) + shift) {
                        field.write(UInt32(bitPattern: moved), to: &bytes)
                    } else {
                        field.write(UInt32(bitPattern: Self.invalidSint32), to: &bytes)
                    }

                case (let global, _, Self.sint32) where Self.summaryMessages.contains(global):
                    // Start/end positions and bounding boxes.
                    field.write(UInt32(bitPattern: Self.invalidSint32), to: &bytes)

                case (_, FITProfile.timestampField, Self.uint32),
                     (FITProfile.Message.fileID, FITProfile.FileID.timeCreated, Self.uint32),
                     (FITProfile.Message.session, FITProfile.Session.startTime, Self.uint32),
                     (FITProfile.Message.lap, Self.lapStartTime, Self.uint32),
                     (FITProfile.Message.activity, Self.activityLocalTimestamp, Self.uint32):
                    let value = field.unsigned(in: bytes)
                    if value != UInt32.max {
                        field.write(UInt32(truncatingIfNeeded: Int64(value) + timeShift), to: &bytes)
                    }

                case (FITProfile.Message.fileID, FITProfile.FileID.serialNumber, _),
                     (FITProfile.Message.deviceInfo, Self.deviceInfoSerialNumber, _):
                    // uint32z: 0 is "invalid"; other integer types use all bits set.
                    field.write(field.baseType == Self.uint32z ? 0 : UInt32.max, to: &bytes)

                default:
                    break
                }
            }
            for i in message.developerData { bytes[i] = 0xFF }
        }

        let headerSize = Int(bytes[0])
        let dataEnd = headerSize + Int(UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24)
        let crc = FITCRC.compute(bytes[0..<dataEnd])
        bytes[dataEnd] = UInt8(crc & 0xFF)
        bytes[dataEnd + 1] = UInt8(crc >> 8)
        return Data(bytes)
    }

    // MARK: - Profile details only the anonymizer needs

    private static let sint32: UInt8 = 0x05
    private static let uint32: UInt8 = 0x06
    private static let uint32z: UInt8 = 0x0C
    private static let invalidSint32 = Int32.max
    private static let lapStartTime: UInt8 = 2
    private static let activityLocalTimestamp: UInt8 = 5
    private static let deviceInfoSerialNumber: UInt8 = 3
    /// session, lap, location, course point, segment point, segment lap, GPS metadata
    private static let summaryMessages: Set<UInt16> = [18, 19, 29, 32, 150, 142, 160]

    static func semicircles(fromDegrees degrees: Double) -> Int64 {
        Int64((degrees * 2_147_483_648.0 / 180.0).rounded())
    }

    /// `nil` when the moved position leaves the valid range.
    private static func clampedSemicircles(_ value: Int64) -> Int32? {
        value > Int64(Int32.min) && value < Int64(Int32.max) ? Int32(value) : nil
    }

    // MARK: - Where each field lives

    private struct Field {
        let number: UInt8
        let offset: Int
        let size: Int
        let baseType: UInt8
        let bigEndian: Bool

        func unsigned(in bytes: [UInt8]) -> UInt32 {
            guard size == 4 else { return UInt32.max }
            let b = bytes[offset..<offset + 4].map(UInt32.init)
            return bigEndian ? b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3] : b[3] << 24 | b[2] << 16 | b[1] << 8 | b[0]
        }

        func signed(in bytes: [UInt8]) -> Int32 { Int32(bitPattern: unsigned(in: bytes)) }

        func write(_ value: UInt32, to bytes: inout [UInt8]) {
            guard size == 4 else { return }
            let b = [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
            for i in 0..<4 { bytes[offset + i] = bigEndian ? b[i] : b[3 - i] }
        }
    }

    private struct Message {
        let globalNumber: UInt16
        let fields: [Field]
        let developerData: Range<Int>

        func unsigned(_ number: UInt8, in bytes: [UInt8]) -> UInt32? {
            guard let field = fields.first(where: { $0.number == number }) else { return nil }
            let value = field.unsigned(in: bytes)
            return value == UInt32.max ? nil : value
        }
    }

    private struct Definition {
        let bigEndian: Bool
        let globalNumber: UInt16
        let fields: [(number: UInt8, size: Int, baseType: UInt8)]
        let developerDataSize: Int
    }

    /// Walks the container like `FITDecoder`, but records the byte offset of every field.
    private static func layout(of bytes: [UInt8]) throws(FITDecodingError) -> [Message] {
        let headerSize = Int(bytes[0])
        let dataEnd = headerSize + Int(UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24)
        var reader = ByteReader(bytes: bytes, offset: headerSize, end: dataEnd)
        var definitions: [UInt8: Definition] = [:]
        var messages: [Message] = []

        while reader.offset < dataEnd {
            let recordStart = reader.offset
            let header = try reader.readByte()
            let isCompressed = header & 0x80 != 0
            let localType = isCompressed ? (header >> 5) & 0x03 : header & 0x0F

            if !isCompressed, header & 0x40 != 0 {
                _ = try reader.readByte()
                let bigEndian = try reader.readByte() == 1
                let globalNumber = try reader.readUInt16(bigEndian: bigEndian)
                let count = Int(try reader.readByte())
                var fields: [(number: UInt8, size: Int, baseType: UInt8)] = []
                for _ in 0..<count {
                    let number = try reader.readByte()
                    let size = Int(try reader.readByte())
                    fields.append((number, size, try reader.readByte() & 0x1F))
                }
                var developerDataSize = 0
                if header & 0x20 != 0 {
                    for _ in 0..<Int(try reader.readByte()) {
                        _ = try reader.readByte()
                        developerDataSize += Int(try reader.readByte())
                        _ = try reader.readByte()
                    }
                }
                definitions[localType] = Definition(bigEndian: bigEndian, globalNumber: globalNumber,
                                                    fields: fields, developerDataSize: developerDataSize)
                continue
            }

            guard let definition = definitions[localType] else {
                throw .undefinedLocalMessage(localType: localType, offset: recordStart)
            }
            var fields: [Field] = []
            for f in definition.fields {
                fields.append(Field(number: f.number, offset: reader.offset, size: f.size,
                                    baseType: f.baseType, bigEndian: definition.bigEndian))
                try reader.skip(f.size)
            }
            let developerStart = reader.offset
            try reader.skip(definition.developerDataSize)
            messages.append(Message(globalNumber: definition.globalNumber, fields: fields,
                                    developerData: developerStart..<reader.offset))
        }
        return messages
    }
}
