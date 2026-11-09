import Testing
@testable import WattspurCore

@Suite("Map heading while recording")
struct MapHeadingTests {
    @Test("Riding, the map turns to the course, also when its accuracy is unknown")
    func riding() {
        #expect(MapHeading.next(current: 45, course: 200, courseAccuracy: -1, speed: 6) == 200)
        #expect(MapHeading.next(current: nil, course: 90, courseAccuracy: 10, speed: 5) == 90)
        #expect(MapHeading.next(current: 90, course: 270, courseAccuracy: 10, speed: 5) == 270)
    }

    @Test("Standing or creeping, the map keeps its direction")
    func standing() {
        #expect(MapHeading.next(current: 90, course: 180, courseAccuracy: 10, speed: 0) == 90)
        #expect(MapHeading.next(current: 90, course: 180, courseAccuracy: 10, speed: 1.5) == 90)
        #expect(MapHeading.next(current: nil, course: 180, courseAccuracy: 10, speed: 0.5) == nil)
    }

    @Test("An unknown or uncertain course changes nothing")
    func unknownCourse() {
        #expect(MapHeading.next(current: 45, course: -1, courseAccuracy: 10, speed: 6) == 45)
        #expect(MapHeading.next(current: 45, course: 200, courseAccuracy: 90, speed: 6) == 45)
    }
}
