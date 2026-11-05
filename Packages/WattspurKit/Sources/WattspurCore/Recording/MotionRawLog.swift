import Foundation

/// The raw motion log of spike V-16: while a test switch is on, the recording writes every
/// device-motion reading (50 Hz) and every GPS update into one CSV file, so a test ride can be
/// checked on the Mac (lean angle from v · ω / g, braking, road roughness). Not part of a ride and
/// never synced; the file stays on the iPhone until the rider shares it.
///
/// One row per line, the first column says what it is:
/// - `m`: device motion: attitude as a quaternion, gravity and user acceleration in g,
///   rotation rate in rad/s, all in the device frame.
/// - `g`: a GPS update: position, altitude, accuracies, speed in m/s, course in degrees.
/// - `b`: the battery level (0…1), now and then, to see what the sensors cost.
/// - `e`: an event of the recording: `start`, `pause`, `resume`, `stop`, or the vehicle.
///
/// The time is seconds since 1970 with milliseconds, for every kind of row.
public enum MotionRawLog {
    public static let header = "kind,time,qx,qy,qz,qw,gx,gy,gz,ax,ay,az,rx,ry,rz,lat,lon,alt,hacc,vacc,speed,course,value"

    /// The readings per second (decision Nils 5.11.2026).
    public static let rate: Double = 50

    /// The folder in the app's documents, shown in the Files app as “Wattspur › Bewegung”.
    public static let folderName = "Bewegung"

    /// One device-motion reading.
    public struct Motion: Sendable, Equatable {
        public var date: Date
        /// Attitude quaternion x, y, z, w.
        public var quaternion: (x: Double, y: Double, z: Double, w: Double)
        /// Gravity in g, device frame.
        public var gravity: (x: Double, y: Double, z: Double)
        /// Acceleration without gravity in g, device frame.
        public var acceleration: (x: Double, y: Double, z: Double)
        /// Rotation rate in rad/s, device frame.
        public var rotation: (x: Double, y: Double, z: Double)

        public init(date: Date, quaternion: (x: Double, y: Double, z: Double, w: Double),
                    gravity: (x: Double, y: Double, z: Double),
                    acceleration: (x: Double, y: Double, z: Double),
                    rotation: (x: Double, y: Double, z: Double)) {
            self.date = date
            self.quaternion = quaternion
            self.gravity = gravity
            self.acceleration = acceleration
            self.rotation = rotation
        }

        public static func == (a: Motion, b: Motion) -> Bool {
            a.date == b.date && a.quaternion == b.quaternion && a.gravity == b.gravity
                && a.acceleration == b.acceleration && a.rotation == b.rotation
        }
    }

    /// One GPS update as the location service delivers it; negative values mean “invalid”, as in
    /// Core Location.
    public struct Location: Sendable, Equatable {
        public var date: Date
        public var latitude: Double
        public var longitude: Double
        public var altitude: Double
        public var horizontalAccuracy: Double
        public var verticalAccuracy: Double
        public var speed: Double
        public var course: Double

        public init(date: Date, latitude: Double, longitude: Double, altitude: Double,
                    horizontalAccuracy: Double, verticalAccuracy: Double, speed: Double, course: Double) {
            self.date = date
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            self.horizontalAccuracy = horizontalAccuracy
            self.verticalAccuracy = verticalAccuracy
            self.speed = speed
            self.course = course
        }
    }

    public static func line(_ m: Motion) -> String {
        let values = [m.quaternion.x, m.quaternion.y, m.quaternion.z, m.quaternion.w,
                      m.gravity.x, m.gravity.y, m.gravity.z,
                      m.acceleration.x, m.acceleration.y, m.acceleration.z,
                      m.rotation.x, m.rotation.y, m.rotation.z].map { number($0, digits: 5) }
        return (["m", time(m.date)] + values + Array(repeating: "", count: 8)).joined(separator: ",") + "\n"
    }

    public static func line(_ l: Location) -> String {
        let values = [number(l.latitude, digits: 7), number(l.longitude, digits: 7), number(l.altitude, digits: 1),
                      number(l.horizontalAccuracy, digits: 1), number(l.verticalAccuracy, digits: 1),
                      number(l.speed, digits: 2), number(l.course, digits: 1)]
        return (["g", time(l.date)] + Array(repeating: "", count: 13) + values + [""]).joined(separator: ",") + "\n"
    }

    public static func battery(_ level: Double, at date: Date) -> String {
        row("b", date, value: number(level, digits: 2))
    }

    public static func event(_ name: String, at date: Date) -> String {
        row("e", date, value: name)
    }

    /// E.g. `Bewegung 2026-11-05 14-30-00.csv`, in the iPhone's time zone.
    public static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let text = String(format: "%04d-%02d-%02d %02d-%02d-%02d",
                          c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        return "\(folderName) \(text).csv"
    }

    private static func row(_ kind: String, _ date: Date, value: String) -> String {
        ([kind, time(date)] + Array(repeating: "", count: 20) + [value]).joined(separator: ",") + "\n"
    }

    static func time(_ date: Date) -> String {
        number(date.timeIntervalSince1970, digits: 3)
    }

    /// A plain decimal with a point, whatever the region of the iPhone.
    static func number(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "" }
        return String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
