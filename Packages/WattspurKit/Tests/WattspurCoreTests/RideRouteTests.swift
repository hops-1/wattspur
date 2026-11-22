import Testing
@testable import WattspurCore

/// The places for the suggested ride name (B-368). The towns are made up for the test.
@Suite("Ride route")
struct RideRouteTests {
    @Test("Two towns: from one to the other")
    func oneWay() {
        #expect(RideRoute(start: "Darmstadt", end: "Frankfurt am Main") == .oneWay(from: "Darmstadt", to: "Frankfurt am Main"))
    }

    @Test("The same town at start and end: a round trip")
    func roundTrip() {
        #expect(RideRoute(start: "Reinheim", end: " Reinheim ") == .roundTrip("Reinheim"))
    }

    @Test("Without the end only the start, without the start nothing")
    func missing() {
        #expect(RideRoute(start: "Reinheim", end: nil) == .start("Reinheim"))
        #expect(RideRoute(start: "Reinheim", end: " ") == .start("Reinheim"))
        #expect(RideRoute(start: nil, end: "Reinheim") == nil)
        #expect(RideRoute(start: " ", end: "Reinheim") == nil)
    }
}
