import Foundation
import Testing
@testable import WattspurCore
import TestFixtures

/// Hand-built FIT files with values that used to trap (overflow, negative or NaN conversions).
/// None of them may crash; each either imports with the bad value ignored or fails cleanly.
@Suite("FIT hostile input")
struct FITHostileInputTests {
    private static func fit(_ body: [UInt8]) -> Data {
        let n = UInt32(body.count)
        // CRC 0 = "not computed".
        let header: [UInt8] = [12, 0x10, 0x00, 0x08, UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF),
                               UInt8(n >> 16 & 0xFF), UInt8(n >> 24), 0x2E, 0x46, 0x49, 0x54]
        return Data(header + body + [0, 0])
    }

    private static func definition(_ local: UInt8, _ global: UInt16, _ fields: [(UInt8, UInt8, UInt8)]) -> [UInt8] {
        var b: [UInt8] = [0x40 | local, 0, 0, UInt8(global & 0xFF), UInt8(global >> 8), UInt8(fields.count)]
        for f in fields { b += [f.0, f.1, f.2] }
        return b
    }

    private static func le32(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8(v >> (8 * UInt32($0)) & 0xFF) } }
    private static func le64(_ v: UInt64) -> [UInt8] { (0..<8).map { UInt8(v >> (8 * UInt64($0)) & 0xFF) } }

    @Test func compressedTimestampNearTheEndOfTheRangeWraps() throws {
        var b = Self.definition(0, 20, [(253, 4, 0x86)])
        b += [0x00] + Self.le32(0xFFFF_FFFE)   // normal record, last timestamp 0xFFFFFFFE
        b += [0x80] + Self.le32(1)             // compressed header, offset 0 → needs the wrap
        let file = try FITDecoder().decode(Self.fit(b))
        #expect(file.messages(20).count == 2)
    }

    @Test func negativeSerialNumberIsIgnored() throws {
        var b = Self.definition(0, 0, [(3, 4, 0x85)]) + [0x00] + Self.le32(0xFFFF_FFFF)   // sint32 -1
        b += Self.definition(1, 20, [(253, 4, 0x86)]) + [0x01] + Self.le32(1000)
        let ride = try FITRideImporter().parse(Self.fit(b))
        #expect(ride.deviceSerialNumber == nil)
    }

    @Test func hugePowerValuesAreIgnoredAndCannotOverflowTheSum() throws {
        var b = Self.definition(0, 20, [(253, 4, 0x86), (7, 8, 0x8F)])
        b += [0x00] + Self.le32(1000) + Self.le64(0x7FFF_FFFF_FFFF_FFFF)
        b += [0x00] + Self.le32(1001) + Self.le64(0x7FFF_FFFF_FFFF_FFFF)
        let ride = try FITRideImporter().parse(Self.fit(b))
        #expect(ride.samples.allSatisfy { $0.power == nil })
        #expect(ride.workKilojoules == nil)
    }

    @Test func extremeStartTimeDoesNotOverflowTheTimeAxis() throws {
        var b = Self.definition(0, 18, [(2, 8, 0x8E)]) + [0x00] + Self.le64(0x8000_0000_0000_0000)
        b += Self.definition(1, 20, [(253, 4, 0x86)]) + [0x01] + Self.le32(1000)
        _ = try? FITRideImporter().parse(Self.fit(b))
    }

    @Test func nanDistanceIsIgnoredAndTheChartsWork() throws {
        var b = Self.definition(0, 20, [(253, 4, 0x86), (5, 4, 0x88)])
        b += [0x00] + Self.le32(1000) + Self.le32(0x7FC0_0000)                    // NaN
        b += [0x00] + Self.le32(1001) + Self.le32(Float(500).bitPattern)
        let ride = try FITRideImporter().parse(Self.fit(b))
        #expect(ride.samples.allSatisfy { $0.distance?.isFinite ?? true })
        _ = RideSeries.chartPoints(from: ride.samples)
    }

    @Test func recordsBeforeTheSessionStartDoNotBreakTheCharts() throws {
        // The session claims a start after the records: their times become negative.
        var b = Self.definition(0, 18, [(2, 4, 0x86)]) + [0x00] + Self.le32(2000)
        b += Self.definition(1, 20, [(253, 4, 0x86), (5, 4, 0x85)])
        b += [0x01] + Self.le32(1000) + Self.le32(0)
        b += [0x01] + Self.le32(1010) + Self.le32(50_000)
        let ride = try FITRideImporter().parse(Self.fit(b))
        _ = RideSeries.chartPoints(from: ride.samples)
        _ = RideSeries.chartPoints(from: ride.samples, axis: .time)
    }
}
