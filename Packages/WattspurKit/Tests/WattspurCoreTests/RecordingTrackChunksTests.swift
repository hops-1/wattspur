import Foundation
import Testing
@testable import WattspurCore

@Suite("Recording map in pieces")
struct RecordingTrackChunksTests {
    @Test("Pieces overlap by one point, so the line has no gap")
    func overlap() {
        #expect(RecordingTrackChunks.ranges(count: 0, size: 3).isEmpty)
        #expect(RecordingTrackChunks.ranges(count: 1, size: 3) == [0..<1])
        #expect(RecordingTrackChunks.ranges(count: 3, size: 3) == [0..<3])
        #expect(RecordingTrackChunks.ranges(count: 5, size: 3) == [0..<3, 2..<5])
        #expect(RecordingTrackChunks.ranges(count: 6, size: 3) == [0..<3, 2..<5, 4..<6])
    }

    @Test("A new point changes only the last piece")
    func growing() {
        let before = RecordingTrackChunks.ranges(count: 1_000, size: 500)
        let after = RecordingTrackChunks.ranges(count: 1_001, size: 500)
        #expect(Array(before.dropLast()) == Array(after.prefix(before.count - 1)))
        #expect(before.last != after.last)
    }

    @Test("Hot or with heights, the map is drawn less often")
    func pace() {
        #expect(RecordingMapPace.interval(thermal: .nominal, plain: true) == 0)
        #expect(RecordingMapPace.interval(thermal: .fair, plain: false) == RecordingMapPace.colouredInterval)
        #expect(RecordingMapPace.interval(thermal: .serious, plain: true) == RecordingMapPace.hotInterval)
        #expect(RecordingMapPace.interval(thermal: .critical, plain: false) == RecordingMapPace.hotInterval)
    }
}
