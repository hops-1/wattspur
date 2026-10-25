import Foundation

/// A decoded, raw (unscaled) value of a FIT field.
///
/// Invalid values (the FIT "no data" marker of each base type) are never
/// stored; the field is simply absent from the message instead.
public enum FITValue: Sendable, Equatable {
    case unsigned(UInt64)
    case signed(Int64)
    case float(Double)
    case string(String)
    case bytes([UInt8])
    case array([FITValue])

    /// Numeric value as `Double`, if the value is a single number.
    public var doubleValue: Double? {
        switch self {
        case .unsigned(let v): Double(v)
        case .signed(let v): Double(v)
        case .float(let v): v
        default: nil
        }
    }

    /// Numeric value as `Int64`, if the value is a single integer.
    public var integerValue: Int64? {
        switch self {
        case .unsigned(let v): v <= UInt64(Int64.max) ? Int64(v) : nil
        case .signed(let v): v
        default: nil
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { s } else { nil }
    }
}

/// One FIT data message: its global message number and its fields by field number.
public struct FITMessage: Sendable, Equatable {
    public let globalNumber: UInt16
    public var fields: [UInt8: FITValue]

    public init(globalNumber: UInt16, fields: [UInt8: FITValue]) {
        self.globalNumber = globalNumber
        self.fields = fields
    }

    public subscript(field: UInt8) -> FITValue? { fields[field] }
}

/// Result of decoding a whole FIT file.
public struct FITFile: Sendable {
    public let protocolVersion: UInt8
    public let profileVersion: UInt16
    public let messages: [FITMessage]

    public func messages(_ number: UInt16) -> [FITMessage] {
        messages.filter { $0.globalNumber == number }
    }
}
