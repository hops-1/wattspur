import Testing
@testable import WattspurCore

/// No reading of the whole library while a ride is recorded (B-380).
@Suite("Reload hold")
struct ReloadHoldTests {
    @Test("Without a hold every request runs at once and nothing waits")
    func free() {
        var hold = ReloadHold()
        let r1 = hold.request()
        #expect(r1)
        #expect(!hold.isPending)
        let r2 = hold.set(holding: false)
        #expect(!r2)
    }

    @Test("Requests while recording wait and run once when the recording ends")
    func heldUntilEnd() {
        var hold = ReloadHold()
        let r3 = hold.set(holding: true)
        #expect(!r3)
        let r4 = hold.request()
        #expect(!r4)
        let r5 = hold.request()
        #expect(!r5)
        #expect(hold.isPending)
        let r6 = hold.set(holding: false)
        #expect(r6)
        hold.didReload()
        #expect(!hold.isPending)
        let r7 = hold.set(holding: false)
        #expect(!r7)
    }

    @Test("A recording without requests needs no reading at its end")
    func nothingAsked() {
        var hold = ReloadHold()
        _ = hold.set(holding: true)
        let r8 = hold.set(holding: false)
        #expect(!r8)
    }

    @Test("A reading in between, such as saving the ride, clears what waited")
    func readingInBetween() {
        var hold = ReloadHold()
        _ = hold.set(holding: true)
        _ = hold.request()
        hold.didReload()
        let r9 = hold.set(holding: false)
        #expect(!r9)
    }
}
