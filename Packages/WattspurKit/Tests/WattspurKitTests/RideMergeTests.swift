import Foundation
import SwiftData
import Testing
@testable import WattspurKit
@testable import WattspurCore
import TestFixtures

@Suite("Merging rides")
struct RideMergeTests {
    private let zone = TimeZone(identifier: "Europe/Berlin")!
    /// 19 Oct 2026, 10:00 in Berlin.
    private let morning = Date(timeIntervalSince1970: 1_792_396_800)

    private func part(start: TimeInterval, timer: TimeInterval, elapsed: TimeInterval, distance: Double,
                      power: Int?, maxPower: Int?, ascent: Int?) -> RideMerge.Part {
        RideMerge.Part(
            startDate: morning.addingTimeInterval(start),
            summary: RideSummary(timerTime: timer, elapsedTime: elapsed, distance: distance,
                                 averageSpeed: distance / timer, maxSpeed: 10,
                                 averagePower: power, maxPower: maxPower, totalAscent: ascent),
            samples: [RideSample(time: 0, distance: 0, power: power),
                      RideSample(time: elapsed, distance: distance, power: power)],
            workKilojoules: Double(power ?? 0) * timer / 1000,
            minAltitude: 100, maxAltitude: 200
        )
    }

    @Test("Sums add up, maximums carry over, averages are weighted by moving time")
    func totals() throws {
        let a = part(start: 0, timer: 3000, elapsed: 3600, distance: 20_000, power: 100, maxPower: 400, ascent: 150)
        let b = part(start: 5400, timer: 1000, elapsed: 1200, distance: 10_000, power: 200, maxPower: 500, ascent: nil)
        let result = try RideMerge.merge([b, a], timeZone: zone)
        #expect(result.startDate == a.startDate)
        #expect(result.summary.timerTime == 4000)
        #expect(result.summary.distance == 30_000)
        #expect(result.summary.averageSpeed == 7.5)
        #expect(result.summary.averagePower == 125)
        #expect(result.summary.maxPower == 500)
        #expect(result.summary.totalAscent == 150)
        #expect(result.summary.totalDescent == nil)
        #expect(result.workKilojoules == 500)
    }

    @Test("A gap on the same day is a pause; the time series runs on in real time")
    func sameDayPause() throws {
        let a = part(start: 0, timer: 3000, elapsed: 3600, distance: 20_000, power: 100, maxPower: 400, ascent: 150)
        let b = part(start: 5400, timer: 1000, elapsed: 1200, distance: 10_000, power: 200, maxPower: 500, ascent: 50)
        let result = try RideMerge.merge([a, b], timeZone: zone)
        #expect(result.summary.elapsedTime == 6600)
        #expect(result.samples.map(\.time) == [0, 3600, 5400, 6600])
        #expect(result.samples.map(\.distance) == [0, 20_000, 20_000, 30_000])
    }

    @Test("Across days only the rides' own times count")
    func acrossDays() throws {
        let a = part(start: 0, timer: 3000, elapsed: 3600, distance: 20_000, power: 100, maxPower: 400, ascent: 150)
        let b = part(start: 86_400, timer: 1000, elapsed: 1200, distance: 10_000, power: 200, maxPower: 500, ascent: 50)
        let result = try RideMerge.merge([a, b], timeZone: zone)
        #expect(result.summary.elapsedTime == 4800)
        #expect(result.samples.map(\.time) == [0, 3600, 3600, 4800])
    }

    @Test("Overlapping rides and single rides are refused")
    func refused() {
        let a = part(start: 0, timer: 3000, elapsed: 3600, distance: 20_000, power: 100, maxPower: 400, ascent: 150)
        let b = part(start: 3000, timer: 1000, elapsed: 1200, distance: 10_000, power: 200, maxPower: 500, ascent: 50)
        let touching = part(start: 3600, timer: 1000, elapsed: 1200, distance: 10_000, power: 200, maxPower: 500, ascent: 50)
        #expect(throws: RideMerge.MergeError.overlapping) { try RideMerge.merge([a, b]) }
        #expect(throws: RideMerge.MergeError.tooFewRides) { try RideMerge.merge([a]) }
        #expect(!RideMerge.overlaps([a, touching]))
    }
}

@MainActor
@Suite("Ride library – merging")
struct RideLibraryMergeTests {
    let container: ModelContainer
    let library: RideLibrary
    let first: Data
    let second: Data
    let firstName = "Reinheim Rundfahrt-5e1f0c2a-7b3d-4c8e-9a61-2f4d8b0c3e57.fit"

    init() throws {
        let schema = Schema(WattspurSchema.models)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        library = RideLibrary(context: container.mainContext)
        first = try Fixture.data("reinheim-rundfahrt")
        second = try FITAnonymizer(latitudeOffset: 0, longitudeOffset: 0, weeks: 1).anonymize(first)
    }

    private func importBoth() throws -> (Ride, Ride) {
        library.importFile(data: first, fileName: firstName)
        library.importFile(data: second, fileName: "Heimweg.fit")
        let rides = try container.mainContext.fetch(FetchDescriptor<Ride>(sortBy: [SortDescriptor(\.startDate)]))
        try #require(rides.count == 2)
        return (rides[0], rides[1])
    }

    private func visibleRides() throws -> [Ride] {
        try container.mainContext.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.mergedInto == nil }))
    }

    @Test("Merging creates one ride from the Bosch totals; the originals become hidden parts")
    func merges() throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([b, a], name: "  Zwei Wochen  ")
        #expect(merged.name == "Zwei Wochen")
        #expect(merged.startDate == a.startDate)
        #expect(merged.timerTime == a.timerTime + b.timerTime)
        #expect(merged.distance == a.distance + b.distance)
        #expect(merged.workKilojoules == a.workKilojoules + b.workKilojoules)
        #expect(merged.averagePower == a.averagePower)
        #expect(merged.samples.count == a.samples.count + b.samples.count)
        #expect(merged.sortedParts.map(\.id) == [a.id, b.id])
        #expect(merged.sourceFile == nil)
        #expect(a.sourceFile != nil)
        #expect(try visibleRides().map(\.id) == [merged.id])
    }

    @Test("An empty name falls back to the first ride's name")
    func defaultName() throws {
        let (a, b) = try importBoth()
        #expect(try library.merge([a, b], name: " ").name == "Reinheim Rundfahrt")
    }

    @Test("Splitting brings the parts back and removes the merged ride")
    func splits() throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([a, b], name: "X")
        let parts = library.split(merged)
        #expect(parts.map(\.id) == [a.id, b.id])
        #expect(Set(try visibleRides().map(\.id)) == [a.id, b.id])
        #expect(a.mergedInto == nil)
    }

    @Test("Merging a merged ride again dissolves it into its parts")
    func mergesMerged() throws {
        let (a, b) = try importBoth()
        let third = Ride(name: "Später", startDate: b.startDate.addingTimeInterval(86_400))
        third.timerTime = 600
        third.elapsedTime = 600
        container.mainContext.insert(third)
        let merged = try library.merge([a, b], name: "X")
        let again = try library.merge([merged, third], name: "Y")
        #expect(again.sortedParts.map(\.id) == [a.id, b.id, third.id])
        #expect(try visibleRides().map(\.id) == [again.id])
    }

    @Test("Overlapping rides, a single ride and the sample ride cannot be merged")
    func problems() throws {
        let (a, b) = try importBoth()
        let overlapping = Ride(name: "Overlap", startDate: a.startDate.addingTimeInterval(60))
        overlapping.elapsedTime = 600
        container.mainContext.insert(overlapping)
        #expect(library.mergeProblem([a, overlapping]) == .overlapping)
        #expect(library.mergeProblem([a]) == .tooFewRides)
        #expect(library.mergeProblem([a, b]) == nil)
        b.isSample = true
        #expect(throws: RideMerge.MergeError.containsSample) { try library.merge([a, b], name: "X") }
    }

    @Test("Re-importing a part is recognized as a duplicate and updates the merged ride")
    func duplicateOfPart() throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([a, b], name: "X")
        let result = library.importFile(data: first, fileName: firstName)
        guard case .duplicate(let id) = result.outcome else {
            Issue.record("Expected duplicate, got \(result.outcome)")
            return
        }
        #expect(id == a.id)
        merged.distance = 0
        try library.update(a, with: first, fileName: firstName)
        #expect(merged.distance == a.distance + b.distance)
    }

    @Test("Re-parsing after a parser update rebuilds the merged ride from its parts (NFR-17)")
    func reparse() throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([a, b], name: "X")
        a.parserVersion = 0
        merged.timerTime = 0
        #expect(library.reparseOutdatedRides() == 1)
        #expect(merged.timerTime == a.timerTime + b.timerTime)
    }

    @Test("⌘Z steps back through merging, trash, restoring and splitting; redo goes forward again")
    func undoFlow() throws {
        let (a, b) = try importBoth()
        let undo = UndoManager()
        undo.groupsByEvent = false
        let library = RideLibrary(context: container.mainContext, undoManager: undo)
        // One group per user action, as the app's event loop makes them.
        func step(_ body: () throws -> Void) rethrows {
            undo.beginUndoGrouping()
            defer { undo.endUndoGrouping() }
            try body()
        }
        func visible() throws -> Set<String> {
            Set(try container.mainContext.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.mergedInto == nil && $0.deletedAt == nil })).map(\.name))
        }
        func trashed() throws -> Set<String> {
            Set(try container.mainContext.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.deletedAt != nil })).map(\.name))
        }
        var merged: Ride!
        try step { merged = try library.merge([a, b], name: "M") }
        step { library.moveToTrash([merged]) }
        step { library.restore([merged]) }
        step { library.rename(merged, to: "N") }
        #expect(try visible() == ["N"])

        undo.undo()
        #expect(try visible() == ["M"])
        undo.undo()
        #expect(try visible().isEmpty)
        #expect(try trashed() == ["M"])
        undo.undo()
        #expect(try visible() == ["M"])
        undo.undo()
        #expect(try visible() == ["Reinheim Rundfahrt", "Heimweg"])
        #expect(a.mergedInto == nil && b.mergedInto == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<Ride>()).count == 2)

        undo.redo()
        #expect(try visible() == ["M"])
        let again = try #require(try container.mainContext.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.mergedInto == nil })).first)
        #expect(again.sortedParts.map(\.id) == [a.id, b.id])

        step { library.split(again) }
        #expect(try visible() == ["Reinheim Rundfahrt", "Heimweg"])
        undo.undo()
        #expect(try visible() == ["M"])
    }

    @Test("Purging a trashed merged ride deletes its parts and their files")
    func purge() throws {
        let (a, b) = try importBoth()
        let merged = try library.merge([a, b], name: "X")
        library.moveToTrash(merged, at: .now.addingTimeInterval(-31 * 86_400))
        library.purgeTrash()
        #expect(try container.mainContext.fetch(FetchDescriptor<Ride>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<SourceFile>()).isEmpty)
    }
}
