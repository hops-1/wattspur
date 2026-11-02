import Foundation
import Testing
@testable import WattspurCore

@Suite("Exchange format for the iPhone")
struct RideExchangeTests {
    /// Points along a meridian, `metres` apart (one degree of latitude is about 111 km).
    static func samples(count: Int, metres: Double, altitude: Double? = 100) -> [RideSample] {
        (0..<count).map { i in
            RideSample(time: Double(i), latitude: 49.8 + Double(i) * metres / 111_195, longitude: 8.8, altitude: altitude)
        }
    }

    @Test("The route keeps about one point every 20 m, with the first and last point")
    func thinsRoute() {
        let route = RideExchange.Route(rideID: UUID(), recordings: [Self.samples(count: 201, metres: 5)])
        // 1000 m at 5 m steps: a point every 20 m is 51 points, the last one included.
        #expect(route.pointCount == 51)
        let segment = route.segments[0]
        #expect(segment.distance.first == 0)
        #expect(abs(segment.distance.last! - 1000) < 1)
        #expect(segment.latitude.first == 49.8)
        #expect(zip(segment.distance, segment.distance.dropFirst()).allSatisfy { $1 - $0 >= 19.9 })
    }

    @Test("A merged ride keeps one segment per part, the distance counting on")
    func segmentsPerPart() {
        let first = Self.samples(count: 11, metres: 10)
        let second = Self.samples(count: 11, metres: 10).map {
            var s = $0; s.latitude! += 0.01; return s
        }
        let route = RideExchange.Route(rideID: UUID(), recordings: [first, second, []])
        #expect(route.segments.count == 2)
        // Like the ride's distance: the gap between the parts does not count.
        #expect(route.segments[1].distance.first! == route.segments[0].distance.last!)
    }

    @Test("The file's own distance is used where there is one")
    func usesFileDistance() {
        let samples = Self.samples(count: 11, metres: 10).map { s -> RideSample in
            var s = s; s.distance = s.time * 11; return s
        }
        let route = RideExchange.Route(rideID: UUID(), recordings: [samples, samples])
        #expect(route.segments[0].distance.last == 110)
        #expect(route.segments[1].distance.last == 220)
    }

    @Test("Points without a position are skipped, a ride without GPS has no route")
    func withoutGPS() {
        let none = (0..<10).map { RideSample(time: Double($0), altitude: 100) }
        #expect(RideExchange.Route(rideID: UUID(), recordings: [none]).pointCount == 0)
        #expect(RideExchange.Route(rideID: UUID(), recordings: [Self.samples(count: 3, metres: 5, altitude: nil)])
            .segments[0].altitude == [nil, nil])
    }

    @Test("Library and route survive a round trip through JSON")
    func roundTrip() throws {
        let bike = RideExchange.Bike(id: UUID(), name: "Cube", kind: "bike", color: "blue", isEbike: true, isArchived: false)
        let older = RideExchange.Ride(id: UUID(), name: "Alt", startDate: Date(timeIntervalSince1970: 1_700_000_000),
                                      source: "fit", timerTime: 60, elapsedTime: 70, distance: 500)
        let newer = RideExchange.Ride(id: UUID(), name: "Neu", startDate: Date(timeIntervalSince1970: 1_800_000_000),
                                      timeZone: "Europe/Berlin", bikeID: bike.id, source: "gpx", estimated: true,
                                      timerTime: 3600, elapsedTime: 4000, distance: 20_000, averageSpeed: 5.5,
                                      totalAscent: 166, routeFile: "x.json")
        let library = RideExchange.Library(generatedAt: Date(timeIntervalSince1970: 1_800_000_100),
                                           generator: "Wattspur test", bikes: [bike], rides: [older, newer])
        #expect(library.rides.map(\.name) == ["Neu", "Alt"])

        let data = try RideExchange.encoder().encode(library)
        #expect(try RideExchange.library(from: data) == library)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"schemaVersion\":1"))
        #expect(text.contains("\"startDate\":\"2027-01-15T08:00:00Z\""))

        let route = RideExchange.Route(rideID: newer.id, recordings: [Self.samples(count: 30, metres: 7)])
        #expect(try RideExchange.route(from: RideExchange.encoder().encode(route)) == route)
    }

    @Test("A library from a newer app is refused")
    func newerSchema() {
        let data = Data(#"{"schemaVersion": 2, "generatedAt": "2026-11-02T10:00:00Z", "generator": "x", "bikes": [], "rides": []}"#.utf8)
        #expect(throws: RideExchange.ReadError.newerSchema(2)) { try RideExchange.library(from: data) }
    }

    @Test("Unknown fields from a later version are ignored")
    func toleratesNewFields() throws {
        let data = Data(#"{"schemaVersion": 1, "generatedAt": "2026-11-02T10:00:00Z", "generator": "x", "bikes": [], "rides": [], "goals": []}"#.utf8)
        #expect(try RideExchange.library(from: data).rides.isEmpty)
    }

    @Test("The fingerprint is stable")
    func fingerprint() {
        #expect(RideExchange.fingerprint("") == 0xcbf2_9ce4_8422_2325)
        #expect(RideExchange.fingerprint("a") == 0xaf63_dc4c_8601_ec8c)
        #expect(RideExchange.routeFileName(rideID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, fingerprint: 255)
            == "00000000-0000-0000-0000-000000000001-ff.json")
    }
}

@Suite("Rides from the Mac on the iPhone")
struct RideExchangeListTests {
    static var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 2
        return calendar
    }

    static func ride(_ iso: String, km: Double, name: String = "") -> RideExchange.Ride {
        RideExchange.Ride(id: UUID(), name: name, startDate: try! Date(iso, strategy: .iso8601),
                          source: "fit", timerTime: 0, elapsedTime: 0, distance: km * 1000)
    }

    @Test("Rides are grouped by month in the device's time zone, newest first")
    func months() {
        let library = RideExchange.Library(generatedAt: .now, generator: "t", bikes: [], rides: [
            Self.ride("2026-10-31T23:30:00Z", km: 1, name: "Nov 1, 0:30 in Berlin"),
            Self.ride("2026-10-31T10:00:00Z", km: 2, name: "Oct"),
            Self.ride("2026-11-02T08:00:00Z", km: 3, name: "Nov 2"),
        ])
        let months = library.months(calendar: Self.berlin)
        #expect(months.map { $0.rides.map(\.name) } == [["Nov 2", "Nov 1, 0:30 in Berlin"], ["Oct"]])
        #expect(library.lastRide?.name == "Nov 2")
    }

    @Test("Week and month totals start on Monday")
    func totals() throws {
        let library = RideExchange.Library(generatedAt: .now, generator: "t", bikes: [], rides: [
            Self.ride("2026-11-01T10:00:00Z", km: 5),   // Sunday: last week, this month
            Self.ride("2026-11-02T06:00:00Z", km: 10),  // Monday
            Self.ride("2026-10-30T10:00:00Z", km: 7),   // last month
        ])
        let totals = library.totals(now: try Date("2026-11-04T12:00:00Z", strategy: .iso8601), calendar: Self.berlin)
        #expect(totals.weekDistance == 10_000)
        #expect(totals.monthRides == 2)
    }

    @Test("Bikes are found by ID")
    func bike() {
        let bike = RideExchange.Bike(id: UUID(), name: "Cube", kind: "bike", color: "blue", isEbike: true, isArchived: false)
        let library = RideExchange.Library(generatedAt: .now, generator: "t", bikes: [bike], rides: [])
        #expect(library.bike(withID: bike.id)?.name == "Cube")
        #expect(library.bike(withID: nil) == nil)
    }
}
