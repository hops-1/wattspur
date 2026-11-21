import Testing
@testable import WattspurCore

@Suite("Map zoom while recording")
struct RecordingMapZoomTests {
    @Test("The zoom the rider chose is kept")
    func ridersZoom() {
        #expect(RecordingMapZoom.distance(800) == 800)
        #expect(RecordingMapZoom.distance(40_000) == 40_000)
        #expect(!RecordingMapZoom.showsTooMuch(800))
    }

    @Test("A fresh map shows the whole world: back to the standard zoom around the position")
    func freshMap() {
        // MKMapView starts with a region of whole continents, about 20,000 km from the ground.
        #expect(RecordingMapZoom.showsTooMuch(20_000_000))
        #expect(RecordingMapZoom.distance(20_000_000) == RecordingMapZoom.standardDistance)
    }

    @Test("An unknown distance gives the standard zoom")
    func unknown() {
        #expect(RecordingMapZoom.distance(0) == RecordingMapZoom.standardDistance)
        #expect(RecordingMapZoom.distance(-1) == RecordingMapZoom.standardDistance)
        #expect(RecordingMapZoom.distance(.nan) == RecordingMapZoom.standardDistance)
        #expect(RecordingMapZoom.distance(.infinity) == RecordingMapZoom.standardDistance)
    }
}
