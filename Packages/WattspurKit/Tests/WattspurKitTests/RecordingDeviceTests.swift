import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

/// The device a recording is made with (B-286): chosen at the start, kept in the log, written into
/// the GPX and taken by the import, also a car without a device. All rides here are made up.
@MainActor
@Suite("Device of a recording")
struct RecordingDeviceTests {
    static let cube = RideExchange.Bike(id: UUID(), name: "Cube", kind: "bike", color: "blue", isEbike: true, isArchived: false)
    static let nugget = RideExchange.Bike(id: UUID(), name: "Nugget", kind: "car", color: "orange", isEbike: false, isArchived: false)
    static let old = RideExchange.Bike(id: UUID(), name: "Altrad", kind: "road", color: "teal", isEbike: false, isArchived: true)

    @Test("The next device: the last one if it is still there, else the active bike, else the first")
    func next() {
        let devices = [Self.cube, Self.nugget, Self.old]
        let car = RecordingDevice(bikeID: Self.nugget.id, kind: .car)
        #expect(RecordingDevice.next(last: car, devices: devices, activeID: Self.cube.id) == car)
        // A car without a device stays as it was chosen.
        #expect(RecordingDevice.next(last: .without(.car), devices: devices, activeID: Self.cube.id) == .without(.car))
        // An archived or deleted device gives way to the active bike.
        let archived = RecordingDevice(bikeID: Self.old.id, kind: .road)
        #expect(RecordingDevice.next(last: archived, devices: devices, activeID: Self.cube.id).bikeID == Self.cube.id)
        #expect(RecordingDevice.next(last: RecordingDevice(bikeID: UUID(), kind: .bike), devices: devices,
                                     activeID: Self.nugget.id) == car)
        // Nothing chosen yet: the active bike, else the first open device, else a bicycle without one.
        #expect(RecordingDevice.next(last: nil, devices: devices, activeID: nil).bikeID == Self.cube.id)
        #expect(RecordingDevice.next(last: nil, devices: [], activeID: nil) == .without(.bike))
    }

    @Test("The capsule decides the sport of the next device (B-324)")
    func nextInSport() {
        let gravel = RideExchange.Bike(id: UUID(), name: "Lukas", kind: "gravel", color: "red", isEbike: false, isArchived: false)
        let devices = [Self.cube, gravel, Self.nugget, Self.old]
        let car = RecordingDevice(bikeID: Self.nugget.id, kind: .car)
        let lukas = RecordingDevice(bikeID: gravel.id, kind: .gravel)
        func next(_ sport: Sport, last: RecordingDevice?, lastOfSport: RecordingDevice? = nil,
                  lastRide: UUID? = nil, active: UUID? = Self.cube.id, in list: [RideExchange.Bike] = devices) -> RecordingDevice {
            RecordingDevice.next(for: sport, last: last, lastOfSport: lastOfSport, lastRideDeviceID: lastRide,
                                 devices: list, activeID: active)
        }
        // The last device while it is of the sport shown.
        #expect(next(.vehicle, last: car) == car)
        // Last the car, Cycling shown: the bike chosen last, else of the last ride, else the active bike.
        #expect(next(.cycling, last: car, lastOfSport: lukas) == lukas)
        #expect(next(.cycling, last: car, lastRide: gravel.id) == lukas)
        #expect(next(.cycling, last: car).bikeID == Self.cube.id)
        // A car in the list of the last bike, or an archived one, does not count.
        #expect(next(.cycling, last: car, lastOfSport: car, lastRide: Self.nugget.id).bikeID == Self.cube.id)
        #expect(next(.cycling, last: car, lastOfSport: RecordingDevice(bikeID: Self.old.id, kind: .road), active: nil)
                    .bikeID == Self.cube.id)
        // Last a bike, Vehicles shown: the vehicle chosen last, also one without a device.
        #expect(next(.vehicle, last: lukas) == car)
        #expect(next(.vehicle, last: lukas, lastOfSport: .without(.motorcycle)) == .without(.motorcycle))
        // No device of the sport: a bicycle or car without one.
        #expect(next(.vehicle, last: nil, in: [Self.cube]) == .without(.car))
        #expect(next(.cycling, last: car, active: nil, in: [Self.nugget]) == .without(.bike))
    }

    @Test("The old setting in More gives the first default: a motorcycle or car without a device")
    func oldSetting() {
        let devices = [Self.cube]
        #expect(RecordingDevice.next(last: nil, devices: devices, activeID: nil, oldVehicle: .motorcycle) == .without(.motorcycle))
        #expect(RecordingDevice.next(last: nil, devices: devices, activeID: nil, oldVehicle: .car) == .without(.car))
        #expect(RecordingDevice.next(last: nil, devices: devices, activeID: nil, oldVehicle: .eBike).bikeID == Self.cube.id)
        // A choice made since wins over the old setting.
        let cube = RecordingDevice(bikeID: Self.cube.id, kind: .bike)
        #expect(RecordingDevice.next(last: cube, devices: devices, activeID: nil, oldVehicle: .motorcycle) == cube)
    }

    @Test("The device sets the speed limit and survives the log of an unfinished recording")
    func recording() throws {
        let car = RecordingDevice(bikeID: Self.nugget.id, kind: .car)
        #expect(car.vehicle == .car && RecordingDevice.without(.motorcycle).vehicle == .motorcycle)
        #expect(RecordingDevice(bikeID: nil, kind: .gravel).vehicle == .eBike)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let recording = RideRecording(startDate: start, device: car)
        #expect(recording.vehicle == .car && recording.device == car)

        var log = RecordingLog.line(.start(start))
        log.append(RecordingLog.line(.vehicle(.car)))
        log.append(RecordingLog.line(.device(car)))
        let replayed = try #require(RecordingLog.replay(log))
        #expect(replayed.device == car && replayed.vehicle == .car)
        // A log from before B-286 has no device.
        var older = RecordingLog.line(.start(start))
        older.append(RecordingLog.line(.vehicle(.motorcycle)))
        let before = try #require(RecordingLog.replay(older))
        #expect(before.device == nil && before.vehicle == .motorcycle)
    }

    /// A recording of two minutes as the iPhone writes it, with a bike or a kind without one.
    private func gpx(bikeID: UUID? = nil, kind: BikeKind? = nil) -> Data {
        let start: TimeInterval = 1_800_000_000
        var recording = RideRecording(startDate: Date(timeIntervalSince1970: start), vehicle: .car)
        for second in 0...120 {
            recording.add(RideRecording.Fix(date: Date(timeIntervalSince1970: start + Double(second)),
                                            latitude: 49.8 + Double(second) * 20 / 111_195, longitude: 8.8,
                                            altitude: 150, horizontalAccuracy: 5, speed: 20))
        }
        return GPXWriter.document(name: "Zum Campingplatz", segments: recording.gpxSegments,
                                  creator: GPXWriter.iPhoneCreator, bikeID: bikeID, kind: kind)
    }

    @Test("The GPX names the kind only without a bike, and the reader finds it")
    func gpxKind() throws {
        let car = String(decoding: gpx(kind: .car), as: UTF8.self)
        #expect(car.contains("<wattspur:kind>car</wattspur:kind>") && !car.contains("wattspur:bike"))
        let withBike = String(decoding: gpx(bikeID: Self.cube.id, kind: .car), as: UTF8.self)
        #expect(withBike.contains("<wattspur:bike>") && !withBike.contains("wattspur:kind"))
        let parsed = try GPXRideImporter().parse(gpx(kind: .car))
        #expect(parsed.suggestedKind == .car && parsed.suggestedBikeID == nil)
        #expect(try GPXRideImporter().parse(gpx()).suggestedKind == nil)
    }

    @Test("A car recording without a device is saved without one and stays out of the cycling totals")
    func saveWithoutDevice() throws {
        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
        guard case .imported(let id) = database.saveRecording(gpx: gpx(kind: .car), fileName: "Camping.gpx").outcome else {
            Issue.record("not imported")
            return
        }
        let ride = try #require(database.library.ride(withID: id))
        #expect(ride.bike == nil && ride.sportRawValue == "car")
        #expect(ride.deviceKind == .car && !ride.countsInTotals)
        let state = try database.snapshot(generator: "test")
        #expect(state.rides.first?.kind == "car" && state.countedRides.isEmpty)

        // With a device the ride gets it, as before.
        let nugget = database.library.makeBike(name: "Nugget", kind: .car)
        let later = gpx(bikeID: nugget.id)
        var shifted = String(decoding: later, as: UTF8.self)
        shifted = shifted.replacingOccurrences(of: "2027-01-15", with: "2027-01-16")
        guard case .imported(let second) = database.saveRecording(gpx: Data(shifted.utf8), fileName: "Zurück.gpx").outcome else {
            Issue.record("not imported")
            return
        }
        let onCar = try #require(database.library.ride(withID: second))
        #expect(onCar.bike?.id == nugget.id && onCar.sportRawValue == nil)
    }

    @Test("A hired bicycle without a device counts in the cycling totals, towards no bike (B-321)")
    func bicycleWithoutDevice() throws {
        #expect(RecordingDevice.vehicleTypes == [.bike, .car, .motorcycle])
        let text = String(decoding: gpx(kind: .bike), as: UTF8.self)
        #expect(text.contains("<wattspur:kind>bike</wattspur:kind>"))
        #expect(try GPXRideImporter().parse(gpx(kind: .bike)).suggestedKind == .bike)

        let container = try ModelContainer(for: Schema(WattspurSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let database = PhoneDatabase(container: container, defaultBikeName: "Mein eBike")
        guard case .imported(let id) = database.saveRecording(gpx: gpx(kind: .bike), fileName: "Leihrad.gpx").outcome else {
            Issue.record("not imported")
            return
        }
        let ride = try #require(database.library.ride(withID: id))
        #expect(ride.bike == nil && ride.sportRawValue == "bike")
        #expect(ride.sport == .cycling && ride.countsInTotals)
        let state = try database.snapshot(generator: "test")
        #expect(state.countedRides.map(\.id) == [id])
        // It counts towards no bike: the iPhone's own bike has no ride.
        let own = try #require(state.bikes.first)
        #expect(state.usage(of: own.id).rides == 0)
    }
}
