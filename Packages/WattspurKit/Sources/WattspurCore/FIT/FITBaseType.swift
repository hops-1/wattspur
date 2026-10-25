import Foundation

/// Decoding of the FIT base types (the low 5 bits of the base type byte).
enum FITBaseType {
    /// Size in bytes of one element of the base type.
    static func elementSize(_ baseType: UInt8) -> Int {
        switch baseType {
        case 0, 1, 2, 7, 10, 13: 1
        case 3, 4, 11: 2
        case 5, 6, 8, 12: 4
        case 9, 14, 15, 16: 8
        default: 1
        }
    }

    /// Decodes a field. Returns `nil` when every element holds the invalid marker.
    static func decode(_ raw: ArraySlice<UInt8>, baseType: UInt8, bigEndian: Bool) -> FITValue? {
        switch baseType {
        case 7:
            let text = raw.prefix { $0 != 0 }
            guard !text.isEmpty else { return nil }
            return .string(String(decoding: text, as: UTF8.self))
        case 13:
            return raw.allSatisfy({ $0 == 0xFF }) ? nil : .bytes(Array(raw))
        default:
            break
        }

        let size = elementSize(baseType)
        guard size > 0, raw.count >= size else { return nil }
        let count = raw.count / size
        var values: [FITValue] = []
        values.reserveCapacity(count)
        var anyValid = false
        for i in 0..<count {
            let start = raw.startIndex + i * size
            let element = raw[start..<start + size]
            let bits = unsignedBits(element, bigEndian: bigEndian)
            if let value = value(bits: bits, baseType: baseType) {
                values.append(value)
                anyValid = true
            } else {
                values.append(.unsigned(bits)) // placeholder keeps array positions
            }
        }
        guard anyValid else { return nil }
        if count == 1 { return values[0] }
        return .array(values)
    }

    private static func unsignedBits(_ bytes: ArraySlice<UInt8>, bigEndian: Bool) -> UInt64 {
        var result: UInt64 = 0
        if bigEndian {
            for b in bytes { result = result << 8 | UInt64(b) }
        } else {
            for b in bytes.reversed() { result = result << 8 | UInt64(b) }
        }
        return result
    }

    private static func value(bits: UInt64, baseType: UInt8) -> FITValue? {
        switch baseType {
        case 0, 2: bits == 0xFF ? nil : .unsigned(bits)
        case 10, 11, 12, 16: bits == 0 ? nil : .unsigned(bits)
        case 4: bits == 0xFFFF ? nil : .unsigned(bits)
        case 6: bits == 0xFFFF_FFFF ? nil : .unsigned(bits)
        case 15: bits == UInt64.max ? nil : .unsigned(bits)
        case 1: bits == 0x7F ? nil : .signed(Int64(Int8(truncatingIfNeeded: bits)))
        case 3: bits == 0x7FFF ? nil : .signed(Int64(Int16(truncatingIfNeeded: bits)))
        case 5: bits == 0x7FFF_FFFF ? nil : .signed(Int64(Int32(truncatingIfNeeded: bits)))
        case 14: bits == 0x7FFF_FFFF_FFFF_FFFF ? nil : .signed(Int64(bitPattern: bits))
        case 8: bits == 0xFFFF_FFFF ? nil : .float(Double(Float(bitPattern: UInt32(truncatingIfNeeded: bits))))
        case 9: bits == UInt64.max ? nil : .float(Double(bitPattern: bits))
        default: .unsigned(bits)
        }
    }
}

/// CRC-16 as specified for FIT files.
enum FITCRC {
    private static let table: [UInt16] = [
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    ]

    static func compute<S: Sequence>(_ bytes: S) -> UInt16 where S.Element == UInt8 {
        var crc: UInt16 = 0
        for byte in bytes {
            var tmp = table[Int(crc & 0xF)]
            crc = (crc >> 4) & 0x0FFF
            crc = crc ^ tmp ^ table[Int(byte & 0xF)]
            tmp = table[Int(crc & 0xF)]
            crc = (crc >> 4) & 0x0FFF
            crc = crc ^ tmp ^ table[Int((byte >> 4) & 0xF)]
        }
        return crc
    }
}
