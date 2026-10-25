import Foundation
import Testing
@testable import WattspurKit

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "fit", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

@Suite("FIT decoder")
struct FITDecoderTests {
    @Test("Decodes header and all messages of the Bosch sample ride")
    func decodesSampleRide() throws {
        let file = try FITDecoder().decode(Fixture.data("reinheim-rundfahrt"))

        #expect(file.protocolVersion == 32)
        #expect(file.profileVersion == 2167)
        #expect(file.messages(FITProfile.Message.fileID).count == 1)
        #expect(file.messages(FITProfile.Message.record).count == 5801)
        #expect(file.messages(FITProfile.Message.lap).count == 1)
        #expect(file.messages(FITProfile.Message.session).count == 1)
        #expect(file.messages(FITProfile.Message.activity).count == 1)
    }

    @Test("Reads Bosch as manufacturer; the cleared serial number reads as missing")
    func readsFileID() throws {
        let file = try FITDecoder().decode(Fixture.data("reinheim-rundfahrt"))
        let fileID = try #require(file.messages(FITProfile.Message.fileID).first)
        #expect(fileID[FITProfile.FileID.manufacturer] == .unsigned(137))
        // The fixture is anonymized (V-05): the serial number field holds the invalid value.
        #expect(fileID[FITProfile.FileID.serialNumber] == nil)
    }

    @Test("Rejects a file with a wrong checksum")
    func rejectsBadChecksum() throws {
        var bytes = [UInt8](try Fixture.data("reinheim-rundfahrt"))
        bytes[100] ^= 0xFF
        #expect(throws: FITDecodingError.self) { try FITDecoder().decode(Data(bytes)) }
    }

    @Test("Rejects truncated files without crashing")
    func rejectsTruncated() throws {
        let data = try Fixture.data("reinheim-rundfahrt")
        for length in [0, 5, 12, 14, 200, data.count / 2, data.count - 1] {
            #expect(throws: FITDecodingError.self) { try FITDecoder().decode(data.prefix(length)) }
        }
    }

    @Test("Rejects data that is not a FIT file")
    func rejectsGarbage() {
        let garbage = Data((0..<500).map { UInt8(truncatingIfNeeded: $0 &* 37) })
        #expect(throws: FITDecodingError.self) { try FITDecoder().decode(garbage) }
    }

    @Test("Survives corrupted message bytes when checksum checking is off")
    func survivesCorruption() throws {
        var bytes = [UInt8](try Fixture.data("reinheim-rundfahrt"))
        for i in stride(from: 20, to: bytes.count - 2, by: 997) { bytes[i] = 0xC5 }
        // Either a clean error or a result, but never a crash.
        _ = try? FITDecoder(verifyChecksum: false).decode(Data(bytes))
    }

    @Test("CRC matches the reference algorithm")
    func crc() {
        #expect(FITCRC.compute([UInt8]("123456789".utf8)) == 0xBB3D)
    }
}
