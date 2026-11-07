import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// The iPhone's own library (B-216, B-217): a recording becomes a ride, the views get it in the
/// exchange format, and the trash works like on the Mac.
@MainActor
@Suite("iPhone database")
struct PhoneDatabaseTests {
    let container: ModelContainer
    let database: PhoneDatabase

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
    }

    private func save(start: TimeInterval = 1_800_000_000, bikeID: UUID? = nil) -> UUID? {
        var recording = RideRecording(startDate: Date(timeIntervalSince1970: start))
        for second in 0...120 {
            recording.add(RideRecording.Fix(date: Date(timeIntervalSince1970: start + Double(second)),
                                            latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8,
                                            altitude: 150, horizontalAccuracy: 5, speed: 6))
        }
        let gpx = GPXWriter.document(name: "Zur Arbeit", segments: recording.gpxSegments, description: nil,
                                     creator: GPXWriter.iPhoneCreator, bikeID: bikeID)
        if case .imported(let id) = database.saveRecording(gpx: gpx, fileName: "Zur Arbeit.gpx").outcome { return id }
        return nil
    }

    @Test("The mode comes from the Info.plist; anything unknown keeps the folder of iOS 0.2")
    func mode() {
        #expect(PhoneDatabase.Mode(infoValue: nil) == .folder)
        #expect(PhoneDatabase.Mode(infoValue: "") == .folder)
        #expect(PhoneDatabase.Mode(infoValue: "$(WATTSPUR_IOS_DATABASE)") == .folder)
        #expect(PhoneDatabase.Mode(infoValue: "local") == .local)
        #expect(PhoneDatabase.Mode(infoValue: "iCloud") == .iCloud)
        #expect(PhoneDatabase.Mode.folder.configuration == nil)
        #expect(PhoneDatabase.Mode.local.configuration?.cloudKitContainerIdentifier == nil)
        #expect(PhoneDatabase.Mode.iCloud.configuration?.cloudKitContainerIdentifier == LibrarySync.containerIdentifier)
    }

    @Test("A new database has the first bike, like the Mac")
    func firstBike() throws {
        let snapshot = try database.snapshot(generator: "Wattspur iOS")
        #expect(snapshot.bikes.map(\.name) == ["Mein eBike"])
        #expect(snapshot.rides.isEmpty)
    }

    @Test("A recording becomes a ride with its bike, calculated by the Kit")
    func recordingBecomesRide() throws {
        let cargo = database.library.makeBike(name: "Lastenrad", kind: .cargo)
        let id = try #require(save(bikeID: cargo.id))
        let snapshot = try database.snapshot(generator: "Wattspur iOS")
        let ride = try #require(snapshot.rides.first)
        #expect(ride.id == id)
        #expect(ride.name == "Zur Arbeit")
        #expect(ride.bikeID == cargo.id)
        #expect(ride.source == "gpx")
        #expect(abs(ride.distance - 720) < 20)
        #expect(ride.routeFile == id.uuidString)
        #expect(snapshot.lastRide?.id == id)
    }

    @Test("A ride is shared as GPX with its time series and bike, and the Mac reads it back")
    func shareGPX() throws {
        let cargo = database.library.makeBike(name: "Lastenrad", kind: .cargo)
        let id = try #require(save(bikeID: cargo.id))
        let file = try #require(database.gpx(forRideID: id) { "Bike: \($0)" })
        #expect(file.fileName.hasSuffix(".gpx"))
        let text = try #require(String(data: file.data, encoding: .utf8))
        #expect(text.contains("Bike: Lastenrad"))
        #expect(text.contains(cargo.id.uuidString))
        #expect(text.components(separatedBy: "<trkpt").count > 20)
        #expect(database.gpx(forRideID: UUID()) { $0 } == nil)
    }

    @Test("The route of a ride comes from the store")
    func route() throws {
        let id = try #require(save())
        let route = try #require(database.route(forRideID: id))
        #expect(route.rideID == id)
        #expect(route.pointCount > 2)
        #expect(database.route(forRideID: UUID()) == nil)
    }

    @Test("The same recording twice is a duplicate, like on the Mac")
    func duplicate() throws {
        _ = try #require(save())
        let gpxAgain: ImportResult.Outcome? = {
            var recording = RideRecording(startDate: Date(timeIntervalSince1970: 1_800_000_000))
            for second in 0...120 {
                recording.add(RideRecording.Fix(date: Date(timeIntervalSince1970: 1_800_000_000 + Double(second)),
                                                latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8,
                                                altitude: 150, horizontalAccuracy: 5, speed: 6))
            }
            let gpx = GPXWriter.document(name: "Zur Arbeit", segments: recording.gpxSegments, description: nil,
                                         creator: GPXWriter.iPhoneCreator, bikeID: nil)
            return database.saveRecording(gpx: gpx, fileName: "Zur Arbeit.gpx").outcome
        }()
        if case .imported = gpxAgain { Issue.record("imported twice") }
        #expect(try database.snapshot(generator: "Wattspur iOS").rides.count == 1)
    }

    @Test("A recording of a ride already there as GPX updates it instead of being dropped (R-53)")
    func duplicateUpdates() throws {
        let start = 1_800_000_000.0
        let id = try #require(save(start: start))
        try #require(database.edit(rideID: id, name: "Mein Name", bikeID: nil))
        // The same tour recorded again, a few seconds later and now with the lean angle.
        var recording = RideRecording(startDate: Date(timeIntervalSince1970: start + 5))
        for second in 0...120 {
            var fix = RideRecording.Fix(date: Date(timeIntervalSince1970: start + 5 + Double(second)),
                                        latitude: 49.8 + Double(second) * 6 / 111_195, longitude: 8.8,
                                        altitude: 150, horizontalAccuracy: 5, speed: 6)
            fix.motion = MotionValues(lean: 12, acceleration: 0.1, roughness: 0.3)
            recording.add(fix)
        }
        let gpx = GPXWriter.document(name: "Zur Arbeit", segments: recording.gpxSegments, description: nil,
                                     creator: GPXWriter.iPhoneCreator, bikeID: nil)
        let result = database.saveRecording(gpx: gpx, fileName: "Zur Arbeit.gpx")
        guard case .duplicate(let existing) = result.outcome else {
            Issue.record("Expected the ride already there, got \(result.outcome)")
            return
        }
        #expect(existing == id)
        let rides = try database.snapshot(generator: "Wattspur iOS").rides
        #expect(rides.count == 1)
        #expect(rides.first?.name == "Mein Name")
        #expect(database.motion(forRideID: id)?.figures.maxLeanLeft == 12)
    }

    @Test("Trash, restore and delete for good (B-217)")
    func trash() throws {
        let id = try #require(save())
        let trashedAt = Date(timeIntervalSince1970: 1_800_100_000)
        database.moveToTrash(rideID: id, at: trashedAt)
        #expect(try database.snapshot(generator: "").rides.isEmpty)
        let trashed = try #require(database.trash().first)
        #expect(trashed.id == id)
        #expect(trashed.deletedAt == trashedAt)
        #expect(trashed.daysLeft(now: trashedAt) == 30)
        #expect(trashed.daysLeft(now: trashedAt.addingTimeInterval(60)) == 30)
        #expect(trashed.daysLeft(now: trashedAt.addingTimeInterval(86_400)) == 29)
        #expect(trashed.daysLeft(now: trashedAt.addingTimeInterval(40 * 86_400)) == 0)

        database.restore(rideID: id)
        #expect(database.trash().isEmpty)
        #expect(try database.snapshot(generator: "").rides.map(\.id) == [id])

        // Only from the trash.
        database.deletePermanently(rideID: id)
        #expect(database.library.ride(withID: id) != nil)
        database.moveToTrash(rideID: id)
        database.deletePermanently(rideID: id)
        #expect(database.library.ride(withID: id) == nil)
    }

    @Test("A ride is renamed and moved to another bike (B-240)")
    func edit() throws {
        let id = try #require(save())
        let cargo = database.library.makeBike(name: "Lastenrad", kind: .cargo)
        #expect(database.edit(rideID: id, name: "  Zum Bäcker ", bikeID: cargo.id))
        var ride = try #require(try database.snapshot(generator: "").rides.first)
        #expect(ride.name == "Zum Bäcker")
        #expect(ride.bikeID == cargo.id)

        // A blank name and an unknown bike keep what the ride has; nothing changed.
        #expect(!database.edit(rideID: id, name: "   ", bikeID: UUID()))
        #expect(!database.edit(rideID: id, name: "Zum Bäcker", bikeID: cargo.id))
        ride = try #require(try database.snapshot(generator: "").rides.first)
        #expect(ride.name == "Zum Bäcker")
        #expect(ride.bikeID == cargo.id)

        // Only the name.
        #expect(database.edit(rideID: id, name: "Heim", bikeID: nil))
        ride = try #require(try database.snapshot(generator: "").rides.first)
        #expect(ride.name == "Heim")
        #expect(ride.bikeID == cargo.id)

        #expect(!database.edit(rideID: UUID(), name: "Nichts", bikeID: nil))
    }

    @Test("The detail gets the measurements of a ride from its time series (B-241)")
    func chartPoints() throws {
        let id = try #require(save())
        let byDistance = database.chartPoints(forRideID: id, bins: 20)
        #expect(byDistance.count == 20)
        #expect(byDistance.allSatisfy { $0.speedKmh != nil && $0.altitude == 150 })
        // A GPS recording has no power or cadence.
        #expect(byDistance.allSatisfy { $0.power == nil && $0.cadence == nil })
        let byTime = database.chartPoints(forRideID: id, axis: .time, bins: 20)
        #expect(!byTime.isEmpty)
        #expect(byTime.map(\.seconds) == byTime.map(\.seconds).sorted())
        #expect(database.chartPoints(forRideID: UUID()).isEmpty)
    }

    @Test("A spot on the chart is found on the track with its position (B-221)")
    func track() throws {
        let id = try #require(save())
        let track = database.track(forRideID: id)
        let fix = try #require(track.fix(atDistanceKm: 0.3))
        #expect(abs(fix.distanceKm - 0.3) < 0.01)
        #expect(fix.latitude != nil && fix.longitude != nil)
        #expect(database.track(forRideID: UUID()).isEmpty)
    }

    @Test("After 30 days the trash empties itself")
    func purge() throws {
        let old = try #require(save(start: 1_800_000_000))
        let recent = try #require(save(start: 1_800_500_000))
        let now = Date(timeIntervalSince1970: 1_810_000_000)
        database.moveToTrash(rideID: old, at: now.addingTimeInterval(-31 * 86_400))
        database.moveToTrash(rideID: recent, at: now.addingTimeInterval(-2 * 86_400))
        database.purgeTrash(now: now)
        #expect(database.trash().map(\.id) == [recent])
    }
}

/// iCloud or the folder on the iPhone (B-218).
@Suite("iPhone: iCloud or folder")
struct PhoneSyncChoiceTests {
    @Test("Only a build with iCloud offers the choice; without iCloud it is the folder")
    func effective() {
        #expect(PhoneDatabase.Mode.iCloud.effective(syncOn: true, folderUser: false) == .iCloud)
        #expect(PhoneDatabase.Mode.iCloud.effective(syncOn: true, folderUser: true) == .iCloud)
        // Off keeps the iPhone's own rides (R-38); only users of the folder way keep the folder.
        #expect(PhoneDatabase.Mode.iCloud.effective(syncOn: false, folderUser: false) == .local)
        #expect(PhoneDatabase.Mode.iCloud.effective(syncOn: false, folderUser: true) == .folder)
        #expect(PhoneDatabase.Mode.folder.effective(syncOn: true, folderUser: false) == .folder)
        #expect(PhoneDatabase.Mode.local.effective(syncOn: false, folderUser: false) == .local)
    }

    @Test("New users start with iCloud, users of the folder way keep it")
    func firstStart() {
        #expect(PhoneDatabase.Mode.syncOnAtFirstStart(hadFolder: false, hadStore: false))
        #expect(!PhoneDatabase.Mode.syncOnAtFirstStart(hadFolder: true, hadStore: false))
        // Had both, e.g. a test build with the store after iOS 0.2: the store wins.
        #expect(PhoneDatabase.Mode.syncOnAtFirstStart(hadFolder: true, hadStore: true))
        #expect(PhoneDatabase.Mode.syncOnAtFirstStart(hadFolder: false, hadStore: true))
    }
}
