import Foundation
import Testing
@testable import WattspurCore

@Suite("Raw motion log of spike V-16")
struct MotionRawLogTests {
    static let date = Date(timeIntervalSince1970: 1_800_000_000.1234)

    static func columns(_ line: String) -> [String] {
        #expect(line.hasSuffix("\n"))
        return line.dropLast().components(separatedBy: ",")
    }

    @Test("Every row has as many columns as the header")
    func columnCount() {
        let count = MotionRawLog.header.components(separatedBy: ",").count
        let motion = MotionRawLog.Motion(date: Self.date, quaternion: (0, 0, 0, 1), gravity: (0, -1, 0),
                                         acceleration: (0.1, 0.2, 0.3), rotation: (0.01, 0.02, 0.03))
        let location = MotionRawLog.Location(date: Self.date, latitude: 52.5, longitude: 13.4, altitude: 40,
                                             horizontalAccuracy: 4, verticalAccuracy: 3, speed: 12.3, course: 270)
        for line in [MotionRawLog.line(motion), MotionRawLog.line(location),
                     MotionRawLog.battery(0.8, at: Self.date), MotionRawLog.event("start", at: Self.date)] {
            #expect(Self.columns(line).count == count)
        }
    }

    @Test("Values land in the columns the header names")
    func values() {
        let header = MotionRawLog.header.components(separatedBy: ",")
        let motion = Self.columns(MotionRawLog.line(MotionRawLog.Motion(
            date: Self.date, quaternion: (0.1, 0.2, 0.3, 0.9), gravity: (0, -1, 0),
            acceleration: (0.5, 0, 0), rotation: (0, 0, 1.25))))
        #expect(motion[0] == "m")
        #expect(motion[1] == "1800000000.123")
        #expect(motion[header.firstIndex(of: "qw")!] == "0.90000")
        #expect(motion[header.firstIndex(of: "gy")!] == "-1.00000")
        #expect(motion[header.firstIndex(of: "ax")!] == "0.50000")
        #expect(motion[header.firstIndex(of: "rz")!] == "1.25000")
        #expect(motion[header.firstIndex(of: "lat")!] == "")

        let gps = Self.columns(MotionRawLog.line(MotionRawLog.Location(
            date: Self.date, latitude: 52.123456789, longitude: -1.5, altitude: 40.04,
            horizontalAccuracy: 4, verticalAccuracy: -1, speed: -1, course: 271.25)))
        #expect(gps[0] == "g")
        #expect(gps[header.firstIndex(of: "lat")!] == "52.1234568")
        #expect(gps[header.firstIndex(of: "lon")!] == "-1.5000000")
        #expect(gps[header.firstIndex(of: "vacc")!] == "-1.0")
        #expect(gps[header.firstIndex(of: "course")!] == "271.2")
        #expect(gps[header.firstIndex(of: "qx")!] == "")

        let event = Self.columns(MotionRawLog.event("pause", at: Self.date))
        #expect(event[0] == "e")
        #expect(event[header.firstIndex(of: "value")!] == "pause")
        let battery = Self.columns(MotionRawLog.battery(0.756, at: Self.date))
        #expect(battery[header.firstIndex(of: "value")!] == "0.76")
    }

    @Test("A value that is not a number leaves the cell empty")
    func notANumber() {
        let line = Self.columns(MotionRawLog.line(MotionRawLog.Motion(
            date: Self.date, quaternion: (.nan, 0, 0, 1), gravity: (0, 0, 0),
            acceleration: (.infinity, 0, 0), rotation: (0, 0, 0))))
        #expect(line[2] == "")
        #expect(line[9] == "")
    }

    @Test("The file is named after the start in the iPhone's time zone")
    func fileName() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        // 1_800_000_000 is 2027-01-15 08:00:00 UTC.
        #expect(MotionRawLog.fileName(for: Date(timeIntervalSince1970: 1_800_000_000), timeZone: berlin)
                == "Bewegung 2027-01-15 09-00-00.csv")
    }
}
