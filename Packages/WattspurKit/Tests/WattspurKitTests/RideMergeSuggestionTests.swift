import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore

@Suite("Suggesting rides to merge")
struct RideMergeSuggestionTests {
    private let zone = TimeZone(identifier: "Europe/Berlin")!
    /// 19 Oct 2026, 10:00 in Berlin.
    private let morning = Date(timeIntervalSince1970: 1_792_396_800)
    private let here: RideMergeSuggestion.Coordinate = (51.80, 10.50)

    private func entry(_ start: TimeInterval, length: TimeInterval = 1800,
                       from: RideMergeSuggestion.Coordinate? = nil, to: RideMergeSuggestion.Coordinate? = nil,
                       id: UUID = UUID()) -> RideMergeSuggestion.Entry {
        let begin = morning.addingTimeInterval(start)
        return .init(id: id, start: begin, end: begin.addingTimeInterval(length), timeZone: zone,
                     startCoordinate: { from }, endCoordinate: { to })
    }

    @Test("Two rides on one day with a short gap belong together")
    func shortGap() {
        let a = entry(0), b = entry(1800 + 900)
        let groups = RideMergeSuggestion.groups(in: [b, a])
        #expect(groups.map(\.rideIDs) == [[a.id, b.id]])
        #expect(groups.first?.start == a.start)
    }

    @Test("A gap over the limit is not suggested; the limit is adjustable")
    func gapLimit() {
        let a = entry(0), b = entry(1800 + 7200)
        #expect(RideMergeSuggestion.groups(in: [a, b]).isEmpty)
        #expect(RideMergeSuggestion.groups(in: [a, b], maxGap: 3 * 3600).count == 1)
        #expect(RideMergeSuggestion.groups(in: [a, entry(1800)], maxGap: 0).isEmpty)
    }

    @Test("Overlapping rides are never suggested")
    func overlap() {
        #expect(RideMergeSuggestion.groups(in: [entry(0), entry(600)]).isEmpty)
    }

    @Test("Rides on different days are not suggested, even a few minutes apart")
    func acrossMidnight() {
        // 23:50 and 00:10 in Berlin; `morning` is 10:00.
        let a = entry(13 * 3600 + 50 * 60, length: 300)
        let b = entry(14 * 3600 + 10 * 60, length: 300)
        #expect(RideMergeSuggestion.groups(in: [a, b], maxGap: 3600).isEmpty)
    }

    @Test("The end must be near the start of the next ride")
    func distance() {
        let near: RideMergeSuggestion.Coordinate = (51.804, 10.50)   // about 450 m
        let far: RideMergeSuggestion.Coordinate = (51.83, 10.50)     // about 3.3 km
        #expect(RideMergeSuggestion.groups(in: [entry(0, to: here), entry(2400, from: near)]).count == 1)
        #expect(RideMergeSuggestion.groups(in: [entry(0, to: here), entry(2400, from: far)]).isEmpty)
    }

    @Test("Without positions the times alone decide")
    func noPositions() {
        #expect(RideMergeSuggestion.groups(in: [entry(0, to: here), entry(2400)]).count == 1)
    }

    @Test("Three rides in a row form one group; a separate pair another")
    func chains() {
        let a = entry(0), b = entry(2400), c = entry(4800)
        let d = entry(6 * 3600), e = entry(6 * 3600 + 2400)
        let groups = RideMergeSuggestion.groups(in: [e, c, a, d, b])
        #expect(groups.map(\.rideIDs) == [[a.id, b.id, c.id], [d.id, e.id]])
    }

    @Test("A single ride gives no group")
    func single() {
        #expect(RideMergeSuggestion.groups(in: [entry(0)]).isEmpty)
        #expect(RideMergeSuggestion.groups(in: []).isEmpty)
    }

    @Test("Distance between positions in metres")
    func haversine() {
        let metres = RideMergeSuggestion.distance((51.80, 10.50), (51.81, 10.50))
        #expect(abs(metres - 1112) < 5)
    }
}

@MainActor
@Suite("Merge suggestions in the library")
struct RideMergeSuggestionLibraryTests {
    private let morning = Date(timeIntervalSince1970: 1_792_396_800)

    let container: ModelContainer
    let library: RideLibrary

    init() throws {
        container = try ModelContainer(for: Schema(WattspurSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
    }

    @discardableResult
    private func add(_ name: String, start: TimeInterval, elapsed: TimeInterval = 1800,
                     at latitude: Double = 51.8) -> Ride {
        let ride = Ride(name: name, startDate: morning.addingTimeInterval(start))
        ride.timeZoneIdentifier = "Europe/Berlin"
        ride.elapsedTime = elapsed
        ride.timerTime = elapsed
        let encoder = PropertyListEncoder()
        ride.samplesData = try? encoder.encode([
            RideSample(time: 0, latitude: latitude, longitude: 10.5),
            RideSample(time: elapsed, latitude: latitude, longitude: 10.5)])
        library.context.insert(ride)
        return ride
    }

    @Test("A new ride next to an existing one is suggested, others are left out")
    func withExisting() throws {
        let a = add("A", start: 0)
        let b = add("B", start: 2400)
        add("Other day", start: 3 * 86_400)
        let groups = library.mergeSuggestions(involving: [b.id])
        #expect(groups.map(\.rideIDs) == [[a.id, b.id]])
        #expect(library.mergeSuggestions(involving: [UUID()]).isEmpty)
    }

    @Test("Groups that do not involve the given rides are not returned")
    func unrelated() throws {
        add("A", start: 0)
        add("B", start: 2400)
        let c = add("C", start: 8 * 3600)
        #expect(library.mergeSuggestions(involving: [c.id]).isEmpty)
    }

    @Test("Trash, the sample ride and parts of a merged ride are ignored")
    func hidden() throws {
        let a = add("A", start: 0)
        let trashed = add("B", start: 2400)
        trashed.deletedAt = .now
        #expect(library.mergeSuggestions(involving: [a.id]).isEmpty)
        trashed.deletedAt = nil
        trashed.isSample = true
        #expect(library.mergeSuggestions(involving: [a.id]).isEmpty)
    }

    @Test("Far apart positions are not suggested; a merged ride counts as one")
    func positionsAndMerged() throws {
        let a = add("A", start: 0)
        let far = add("Far", start: 2400, at: 51.9)
        #expect(library.mergeSuggestions(involving: [a.id]).isEmpty)
        far.deletedAt = .now
        let b = add("B", start: 2400)
        let merged = try library.merge([a, b], name: "AB")
        let c = add("C", start: 4800)
        let groups = library.mergeSuggestions(involving: [c.id])
        #expect(groups.map(\.rideIDs) == [[merged.id, c.id]])
    }
}
